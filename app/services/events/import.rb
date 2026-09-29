module Events
  # Ingests public events from the Billetto API into the `events` table.
  #
  # Each page is validated in memory with the Event model's validations, then written
  # with a single upsert keyed on `external_id`, so re-running an import is idempotent
  # and updates events that changed upstream. Invalid records are skipped and logged;
  # API errors abort the run (pages already written stay written).
  class Import
    Result = Data.define(:fetched, :imported, :skipped)

    UPSERT_COLUMNS = %w[
      title description starts_at ends_at url image_url location_name city country_code raw_payload synced_at
    ].freeze

    def self.call(...) = new(...).call

    def initialize(client: Billetto::Client.from_env, max_pages: nil, logger: Rails.logger)
      @client = client
      @max_pages = max_pages
      @logger = logger
    end

    def call
      totals = { fetched: 0, imported: 0, skipped: 0 }

      client.each_events_page(max_pages: max_pages) do |page|
        rows = valid_rows(page)
        Event.upsert_all(rows, unique_by: :external_id, update_only: UPSERT_COLUMNS) if rows.any?

        totals[:fetched] += page.size
        totals[:imported] += rows.size
        totals[:skipped] += page.size - rows.size
      end

      Result.new(**totals).tap { |result| logger.info("[Events::Import] #{result.to_h}") }
    end

    private

    attr_reader :client, :max_pages, :logger

    def valid_rows(page)
      synced_at = Time.current

      events = page.filter_map do |raw|
        event = Event.new(Billetto::EventPayload.new(raw).to_event_attributes.merge(synced_at: synced_at))
        next event if event.valid?

        logger.warn("[Events::Import] Skipping event #{event.external_id.inspect}: #{event.errors.full_messages.to_sentence}")
        nil
      end

      # A single upsert statement cannot touch the same row twice; keep the last occurrence.
      events.index_by(&:external_id).values.map { |event| event.attributes.slice("external_id", *UPSERT_COLUMNS) }
    end
  end
end

module Billetto
  # Anti-corruption layer: maps one raw "public_event" from the Billetto API onto
  # Event attributes. It only translates and normalises; validation is the Event model's job.
  class EventPayload
    def initialize(raw)
      @raw = raw.is_a?(Hash) ? raw : {}
    end

    def external_id
      raw["id"].presence&.to_s
    end

    def to_event_attributes
      location = raw["location"].is_a?(Hash) ? raw["location"] : {}

      {
        external_id: external_id,
        title: clean(raw["title"]),
        description: clean(raw["description"]),
        starts_at: parse_time(raw["startdate"]),
        ends_at: parse_time(raw["enddate"]),
        url: clean(raw["url"]),
        image_url: clean(raw["image_link"]),
        location_name: clean(location["location_name"]),
        city: clean(location["city"]),
        country_code: clean(location["country_code"]),
        raw_payload: raw
      }
    end

    private

    attr_reader :raw

    def clean(value)
      value.is_a?(String) ? value.strip.presence : nil
    end

    def parse_time(value)
      Time.iso8601(value) if value.is_a?(String)
    rescue ArgumentError
      nil
    end
  end
end

module Billetto
  # Thin HTTP client for the Billetto public API.
  # https://api.billetto.com/reference/list-public-events
  #
  # Transient failures (timeouts, connection errors, 429 and 5xx) are retried with
  # exponential backoff. Anything that still fails is raised as a Billetto::Client::Error
  # subclass so callers can decide what to do with it.
  class Client
    class Error < StandardError; end
    class ConfigurationError < Error; end
    class AuthenticationError < Error; end
    class RateLimitedError < Error; end
    class ServerError < Error; end
    class ConnectionError < Error; end
    class InvalidResponseError < Error; end

    BASE_URL = "https://billetto.dk".freeze
    EVENTS_PATH = "/api/v3/public/events".freeze
    MAX_PAGE_SIZE = 100
    RETRY_STATUSES = [ 429, 500, 502, 503, 504 ].freeze

    def self.from_env
      keypair = ENV["BILLETTO_API_KEYPAIR"].presence
      raise ConfigurationError, "BILLETTO_API_KEYPAIR is not set" unless keypair

      new(keypair: keypair)
    end

    def initialize(keypair:, base_url: BASE_URL, open_timeout: 5, read_timeout: 15, max_retries: 3, retry_interval: 0.5)
      @base_uri = URI(base_url)
      @connection = build_connection(keypair, open_timeout, read_timeout, max_retries, retry_interval)
    end

    # Yields each page of public events (an Array of raw event Hashes), following the
    # API's cursor pagination until there are no more pages or `max_pages` is reached.
    def each_events_page(page_size: MAX_PAGE_SIZE, max_pages: nil, **filters)
      return enum_for(:each_events_page, page_size:, max_pages:, **filters) unless block_given?

      url = EVENTS_PATH
      params = { limit: page_size.clamp(1, MAX_PAGE_SIZE), **filters }
      pages = 0

      loop do
        body = get(url, params)
        yield body.fetch("data")
        pages += 1

        break unless body["has_more"] && body["next_url"].present?
        break if max_pages && pages >= max_pages

        url = same_host_url!(body["next_url"])
        params = {} # next_url already carries the cursor and limit
      end
    end

    private

    attr_reader :connection, :base_uri

    def build_connection(keypair, open_timeout, read_timeout, max_retries, retry_interval)
      Faraday.new(
        url: base_uri.to_s,
        headers: { "Api-Keypair" => keypair, "Accept" => "application/json" },
        request: { open_timeout: open_timeout, timeout: read_timeout }
      ) do |f|
        f.request :retry,
          max: max_retries,
          interval: retry_interval,
          backoff_factor: 2,
          interval_randomness: 0.5,
          methods: %i[get],
          retry_statuses: RETRY_STATUSES,
          exceptions: [ Faraday::TimeoutError, Faraday::ConnectionFailed, Faraday::RetriableResponse ]
      end
    end

    def get(url, params)
      handle_response(connection.get(url, params))
    rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
      raise ConnectionError, "Billetto API unreachable: #{e.message}"
    end

    def handle_response(response)
      case response.status
      when 200..299 then parse(response.body)
      when 401, 403 then raise AuthenticationError, "Billetto API rejected the keypair (HTTP #{response.status})"
      when 429 then raise RateLimitedError, "Billetto API rate limit exceeded"
      when 500..599 then raise ServerError, "Billetto API server error (HTTP #{response.status})"
      else raise Error, "Unexpected Billetto API response (HTTP #{response.status})"
      end
    end

    def parse(body)
      json = JSON.parse(body)
      unless json.is_a?(Hash) && json["data"].is_a?(Array)
        raise InvalidResponseError, "Billetto API response has no 'data' list"
      end

      json
    rescue JSON::ParserError => e
      raise InvalidResponseError, "Billetto API returned invalid JSON: #{e.message}"
    end

    # Never send the keypair to a host other than the configured API host.
    def same_host_url!(url)
      uri = URI(url)
      return uri.to_s if uri.host == base_uri.host && uri.scheme == base_uri.scheme

      raise InvalidResponseError, "Refusing to follow pagination to #{uri.host}"
    rescue URI::InvalidURIError
      raise InvalidResponseError, "Invalid pagination URL: #{url}"
    end
  end
end

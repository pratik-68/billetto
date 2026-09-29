class ImportEventsJob < ApplicationJob
  queue_as :default

  retry_on Billetto::Client::ConnectionError,
           Billetto::Client::ServerError,
           Billetto::Client::RateLimitedError,
           wait: :polynomially_longer, attempts: 5

  def perform(max_pages: nil)
    Events::Import.call(max_pages: max_pages)
  end
end

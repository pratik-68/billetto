require "ruby_event_store/rspec"

module EventStoreHelpers
  def event_store = Rails.configuration.event_store
  def command_bus = Rails.configuration.command_bus
end

RSpec.configure do |config|
  config.include RubyEventStore::RSpec::Matchers
  config.include EventStoreHelpers
end

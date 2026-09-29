# Rails Event Store: events are serialised as JSON into jsonb columns (see
# db/migrate/*_create_event_store_events.rb). Request metadata (request_id, remote_ip)
# is attached automatically by RailsEventStore::Middleware.
Rails.configuration.to_prepare do
  Rails.configuration.event_store = RailsEventStore::JSONClient.new
  Rails.configuration.command_bus = Arkency::CommandBus.new

  Voting::Configuration.new.call(Rails.configuration.event_store, Rails.configuration.command_bus)
end

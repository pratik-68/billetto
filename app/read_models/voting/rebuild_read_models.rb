module Voting
  # Rebuilds the voting read models from scratch by replaying every Voting event
  # in the order it was stored.
  class RebuildReadModels
    def initialize(event_store = Rails.configuration.event_store)
      @event_store = event_store
    end

    def call
      projections = Configuration.projections

      ActiveRecord::Base.transaction do
        VoteTally.delete_all
        EventVote.delete_all

        event_store.read.of_type(Configuration::EVENTS).each do |domain_event|
          projections.each { |projection| projection.call(domain_event) }
        end
      end
    end

    private

    attr_reader :event_store
  end
end

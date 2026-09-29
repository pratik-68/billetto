module Voting
  # Registers the Voting command handler and read-model projections.
  class Configuration
    EVENTS = [ EventUpvoted, EventDownvoted, VoteWithdrawn ].freeze
    COMMANDS = [ UpvoteEvent, DownvoteEvent, WithdrawVote ].freeze

    def self.projections
      [ TallyProjection.new, EventVoteProjection.new ]
    end

    def call(event_store, command_bus)
      handler = BallotCommandHandler.new(event_store)
      COMMANDS.each { |command| command_bus.register(command, handler) }
      self.class.projections.each { |projection| event_store.subscribe(projection, to: EVENTS) }
    end
  end
end

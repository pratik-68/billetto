module Voting
  # Handles UpvoteEvent, DownvoteEvent and WithdrawVote.
  #
  # Events and the synchronous read-model projections are written in one transaction.
  # A concurrent write to the same ballot (e.g. a double click) surfaces as
  # WrongExpectedEventVersion; the command is then retried once against fresh state.
  class BallotCommandHandler
    MAX_ATTEMPTS = 2

    def initialize(event_store)
      @event_store = event_store
      @repository = AggregateRoot::Repository.new(event_store)
    end

    def call(command)
      raise ArgumentError, "user_id is required" if command.user_id.blank?
      raise UnknownEvent, "Event #{command.event_id} does not exist" unless Event.exists?(command.event_id)

      with_conflict_retry do
        event_store.with_metadata(user_id: command.user_id) do
          repository.with_aggregate(Ballot.new(command.event_id, command.user_id),
                                    Ballot.stream_name(command.event_id, command.user_id)) do |ballot|
            apply(command, ballot)
          end
        end
      end
    end

    private

    attr_reader :event_store, :repository

    def apply(command, ballot)
      case command
      when UpvoteEvent then ballot.upvote
      when DownvoteEvent then ballot.downvote
      when WithdrawVote then ballot.withdraw
      else raise ArgumentError, "Unsupported command #{command.class}"
      end
    end

    def with_conflict_retry
      attempts = 0
      begin
        attempts += 1
        ActiveRecord::Base.transaction(requires_new: true) { yield }
      rescue RubyEventStore::WrongExpectedEventVersion
        retry if attempts < MAX_ATTEMPTS
        raise
      end
    end
  end
end

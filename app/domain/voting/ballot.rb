module Voting
  # One user's vote on one event: the consistency boundary for "one vote per user per event".
  #
  # Keeping the aggregate this small means loading it only replays that user's votes on
  # that event, and different users voting on the same event never conflict.
  # Repeating the current vote, or withdrawing when there is no vote, is a no-op.
  class Ballot
    include AggregateRoot

    UP = "up".freeze
    DOWN = "down".freeze

    def self.stream_name(event_id, user_id)
      "Voting::Ballot$#{event_id}$#{user_id}"
    end

    attr_reader :vote

    def initialize(event_id, user_id)
      @event_id = event_id
      @user_id = user_id
      @vote = nil
    end

    def upvote
      cast(UP, EventUpvoted)
    end

    def downvote
      cast(DOWN, EventDownvoted)
    end

    def withdraw
      return if vote.nil?

      apply VoteWithdrawn.new(data: { event_id: event_id, user_id: user_id, withdrawn_vote: vote })
    end

    on(EventUpvoted) { |_event| @vote = UP }
    on(EventDownvoted) { |_event| @vote = DOWN }
    on(VoteWithdrawn) { |_event| @vote = nil }

    private

    attr_reader :event_id, :user_id

    def cast(direction, event_class)
      return if vote == direction

      apply event_class.new(data: { event_id: event_id, user_id: user_id, previous_vote: vote })
    end
  end
end

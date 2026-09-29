module Voting
  # Vote counts for an event plus the given user's current vote, read from the
  # VoteTally and EventVote read models.
  VoteSummary = Data.define(:event_id, :upvotes, :downvotes, :current_vote) do
    # Returns { event_id => VoteSummary } for the given events in two queries.
    def self.for_events(events, user_id: nil)
      event_ids = events.map(&:id)
      tallies = VoteTally.where(event_id: event_ids).index_by(&:event_id)
      user_votes = user_id ? EventVote.where(event_id: event_ids, user_id: user_id).pluck(:event_id, :vote).to_h : {}

      event_ids.index_with do |event_id|
        tally = tallies[event_id]
        new(event_id: event_id, upvotes: tally&.upvotes.to_i, downvotes: tally&.downvotes.to_i, current_vote: user_votes[event_id])
      end
    end

    def self.for_event(event, user_id: nil)
      for_events([ event ], user_id: user_id).fetch(event.id)
    end

    def score
      upvotes - downvotes
    end
  end
end

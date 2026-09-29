module Voting
  # Maintains EventVote: which way each user currently votes on each event.
  class EventVoteProjection
    def call(domain_event)
      key = domain_event.data.slice(:event_id, :user_id)

      case domain_event
      when EventUpvoted then upsert(key, Ballot::UP)
      when EventDownvoted then upsert(key, Ballot::DOWN)
      when VoteWithdrawn then EventVote.where(key).delete_all
      end
    end

    private

    def upsert(key, vote)
      EventVote.upsert(key.merge(vote: vote), unique_by: %i[event_id user_id])
    end
  end
end

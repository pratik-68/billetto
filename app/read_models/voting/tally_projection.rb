module Voting
  # Maintains VoteTally counts with atomic increments. `previous_vote` on the domain
  # event tells us which count a switched vote has to be taken away from.
  class TallyProjection
    def call(domain_event)
      upvotes, downvotes = deltas(domain_event)
      event_id = domain_event.data.fetch(:event_id)

      VoteTally.insert_all([ { event_id: event_id } ], unique_by: :event_id)
      VoteTally.where(event_id: event_id).update_all(
        [ "upvotes = upvotes + ?, downvotes = downvotes + ?, updated_at = ?", upvotes, downvotes, Time.current ]
      )
    end

    private

    def deltas(domain_event)
      data = domain_event.data

      case domain_event
      when EventUpvoted then [ 1, data[:previous_vote] == Ballot::DOWN ? -1 : 0 ]
      when EventDownvoted then [ data[:previous_vote] == Ballot::UP ? -1 : 0, 1 ]
      when VoteWithdrawn then data.fetch(:withdrawn_vote) == Ballot::UP ? [ -1, 0 ] : [ 0, -1 ]
      end
    end
  end
end

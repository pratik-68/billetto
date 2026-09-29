module Voting
  # data: { event_id:, user_id:, previous_vote: "down" | nil }
  class EventUpvoted < RubyEventStore::Event; end
end

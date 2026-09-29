module Voting
  # data: { event_id:, user_id:, previous_vote: "up" | nil }
  class EventDownvoted < RubyEventStore::Event; end
end

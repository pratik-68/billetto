module Voting
  # data: { event_id:, user_id:, withdrawn_vote: "up" | "down" }
  class VoteWithdrawn < RubyEventStore::Event; end
end

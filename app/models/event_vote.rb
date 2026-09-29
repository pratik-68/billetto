# Read model: the current vote of each user on each event, projected from Voting events.
class EventVote < ApplicationRecord
  belongs_to :event
end

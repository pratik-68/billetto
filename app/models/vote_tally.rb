# Read model: up/down vote counts per event, projected from Voting events.
class VoteTally < ApplicationRecord
  belongs_to :event
end

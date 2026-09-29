require "rails_helper"

RSpec.describe Voting::Ballot do
  subject(:ballot) { described_class.new(42, "user_1") }

  it "records an upvote" do
    ballot.upvote

    expect(ballot).to have_applied(
      an_event(Voting::EventUpvoted).with_data(event_id: 42, user_id: "user_1", previous_vote: nil)
    ).exactly(1).times
    expect(ballot.vote).to eq("up")
  end

  it "records a downvote" do
    ballot.downvote

    expect(ballot).to have_applied(an_event(Voting::EventDownvoted).with_data(previous_vote: nil))
    expect(ballot.vote).to eq("down")
  end

  it "switches a vote, remembering the vote it replaces" do
    ballot.upvote
    ballot.downvote

    expect(ballot).to have_applied(an_event(Voting::EventDownvoted).with_data(previous_vote: "up"))
    expect(ballot.vote).to eq("down")
  end

  it "ignores a repeated vote" do
    ballot.upvote
    ballot.upvote

    expect(ballot.unpublished_events.to_a.size).to eq(1)
  end

  it "withdraws a vote" do
    ballot.downvote
    ballot.withdraw

    expect(ballot).to have_applied(an_event(Voting::VoteWithdrawn).with_data(withdrawn_vote: "down"))
    expect(ballot.vote).to be_nil
  end

  it "ignores withdrawing when there is no vote" do
    ballot.withdraw

    expect(ballot.unpublished_events.to_a).to be_empty
  end
end

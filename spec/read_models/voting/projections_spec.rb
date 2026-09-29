require "rails_helper"

RSpec.describe "Voting read models" do
  let(:event) { create(:event) }
  let(:other_event) { create(:event) }

  def vote(command_class, user_id, on: event)
    command_bus.call(command_class.new(event_id: on.id, user_id: user_id))
  end

  def tally(on = event)
    on.reload.vote_tally&.slice(:upvotes, :downvotes)&.symbolize_keys
  end

  it "counts upvotes and downvotes per event" do
    vote(Voting::UpvoteEvent, "user_1")
    vote(Voting::UpvoteEvent, "user_2")
    vote(Voting::DownvoteEvent, "user_3")
    vote(Voting::DownvoteEvent, "user_1", on: other_event)

    expect(tally).to eq(upvotes: 2, downvotes: 1)
    expect(tally(other_event)).to eq(upvotes: 0, downvotes: 1)
  end

  it "moves a switched vote from one count to the other" do
    vote(Voting::UpvoteEvent, "user_1")
    vote(Voting::DownvoteEvent, "user_1")

    expect(tally).to eq(upvotes: 0, downvotes: 1)
    expect(EventVote.find_by!(event: event, user_id: "user_1").vote).to eq("down")
  end

  it "removes a withdrawn vote" do
    vote(Voting::UpvoteEvent, "user_1")
    vote(Voting::WithdrawVote, "user_1")

    expect(tally).to eq(upvotes: 0, downvotes: 0)
    expect(EventVote.where(event: event)).to be_empty
  end

  it "does not double count a repeated vote" do
    2.times { vote(Voting::UpvoteEvent, "user_1") }

    expect(tally).to eq(upvotes: 1, downvotes: 0)
  end

  it "rebuilds identical read models by replaying the event store" do
    vote(Voting::UpvoteEvent, "user_1")
    vote(Voting::DownvoteEvent, "user_2")
    vote(Voting::DownvoteEvent, "user_1")
    vote(Voting::UpvoteEvent, "user_3")
    vote(Voting::WithdrawVote, "user_3")
    vote(Voting::UpvoteEvent, "user_1", on: other_event)
    snapshot = -> { [ VoteTally.order(:event_id).pluck(:event_id, :upvotes, :downvotes), EventVote.order(:event_id, :user_id).pluck(:event_id, :user_id, :vote) ] }
    before = snapshot.call

    VoteTally.update_all(upvotes: 99)
    Voting::RebuildReadModels.new.call

    expect(snapshot.call).to eq(before)
    expect(tally).to eq(upvotes: 0, downvotes: 2)
  end
end

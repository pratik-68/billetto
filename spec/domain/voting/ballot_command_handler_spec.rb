require "rails_helper"

RSpec.describe Voting::BallotCommandHandler do
  let(:event) { create(:event) }
  let(:stream) { Voting::Ballot.stream_name(event.id, "user_1") }

  it "stores an upvote in the ballot stream with the user in data and metadata" do
    command_bus.call(Voting::UpvoteEvent.new(event_id: event.id, user_id: "user_1"))

    expect(event_store).to have_published(
      an_event(Voting::EventUpvoted)
        .with_data(event_id: event.id, user_id: "user_1", previous_vote: nil)
        .with_metadata(user_id: "user_1")
    ).in_stream(stream).exactly(1).times
  end

  it "stores a switch and a withdrawal against the current ballot state" do
    command_bus.call(Voting::UpvoteEvent.new(event_id: event.id, user_id: "user_1"))
    command_bus.call(Voting::DownvoteEvent.new(event_id: event.id, user_id: "user_1"))
    command_bus.call(Voting::WithdrawVote.new(event_id: event.id, user_id: "user_1"))

    expect(event_store).to have_published(
      an_event(Voting::EventUpvoted),
      an_event(Voting::EventDownvoted).with_data(previous_vote: "up"),
      an_event(Voting::VoteWithdrawn).with_data(withdrawn_vote: "down")
    ).in_stream(stream).strict
  end

  it "does not store anything for a repeated vote" do
    2.times { command_bus.call(Voting::UpvoteEvent.new(event_id: event.id, user_id: "user_1")) }

    expect(event_store.read.stream(stream).count).to eq(1)
  end

  it "keeps separate ballots per user" do
    command_bus.call(Voting::UpvoteEvent.new(event_id: event.id, user_id: "user_1"))
    command_bus.call(Voting::UpvoteEvent.new(event_id: event.id, user_id: "user_2"))

    expect(event_store).to have_published(an_event(Voting::EventUpvoted))
      .in_stream(Voting::Ballot.stream_name(event.id, "user_2"))
  end

  it "rejects votes on unknown events" do
    expect { command_bus.call(Voting::UpvoteEvent.new(event_id: 0, user_id: "user_1")) }
      .to raise_error(Voting::UnknownEvent)
    expect(event_store).not_to have_published(an_event(Voting::EventUpvoted))
  end

  it "rejects commands without a user" do
    expect { command_bus.call(Voting::UpvoteEvent.new(event_id: event.id, user_id: nil)) }
      .to raise_error(ArgumentError, /user_id/)
  end

  it "retries once when another write to the same ballot wins the race" do
    handler = described_class.new(event_store)
    repository = handler.send(:repository)
    calls = 0
    allow(repository).to receive(:with_aggregate).and_wrap_original do |original, *args, &block|
      calls += 1
      raise RubyEventStore::WrongExpectedEventVersion if calls == 1

      original.call(*args, &block)
    end

    handler.call(Voting::UpvoteEvent.new(event_id: event.id, user_id: "user_1"))

    expect(calls).to eq(2)
    expect(event_store.read.stream(stream).count).to eq(1)
  end
end

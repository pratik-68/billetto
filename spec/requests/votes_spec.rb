require "rails_helper"

RSpec.describe "Votes" do
  let(:event) { create(:event) }
  let(:json) { { "Accept" => "application/json" } }

  describe "as a guest" do
    it "redirects HTML requests to sign in without recording a vote" do
      put event_vote_path(event), params: { vote: "up" }

      expect(response).to redirect_to(sign_in_path)
      expect(response).to have_http_status(:see_other)
      expect(event_store).not_to have_published(an_event(Voting::EventUpvoted))
    end

    it "rejects JSON requests with 401" do
      put event_vote_path(event), params: { vote: "down" }, headers: json

      expect(response).to have_http_status(:unauthorized)
      expect(event_store).not_to have_published(an_event(Voting::EventDownvoted))
    end

    it "cannot withdraw a vote" do
      delete event_vote_path(event), headers: json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "as a signed-in user" do
    before { sign_in_as("user_123") }

    it "records an upvote with the Clerk user id and request metadata" do
      put event_vote_path(event), params: { vote: "up" }, headers: json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("upvotes" => 1, "downvotes" => 0, "current_vote" => "up")
      expect(event_store).to have_published(
        an_event(Voting::EventUpvoted)
          .with_data(event_id: event.id, user_id: "user_123")
          .with_metadata(user_id: "user_123", request_id: kind_of(String), remote_ip: kind_of(String))
      ).in_stream(Voting::Ballot.stream_name(event.id, "user_123"))
    end

    it "switches and withdraws the vote" do
      put event_vote_path(event), params: { vote: "up" }, headers: json
      put event_vote_path(event), params: { vote: "down" }, headers: json

      expect(response.parsed_body).to include("upvotes" => 0, "downvotes" => 1, "current_vote" => "down")

      delete event_vote_path(event), headers: json

      expect(response.parsed_body).to include("upvotes" => 0, "downvotes" => 0, "current_vote" => nil)
      expect(event_store).to have_published(an_event(Voting::VoteWithdrawn).with_data(withdrawn_vote: "down"))
    end

    it "redirects back for HTML requests" do
      put event_vote_path(event), params: { vote: "up" }, headers: { "Referer" => "http://www.example.com/?page=2" }

      expect(response).to redirect_to("http://www.example.com/?page=2")
    end

    it "rejects an unknown vote direction" do
      put event_vote_path(event), params: { vote: "sideways" }, headers: json

      expect(response).to have_http_status(:unprocessable_content)
      expect(event_store.read.count).to eq(0)
    end

    it "returns 404 for an unknown event" do
      put event_vote_path(event_id: 0), params: { vote: "up" }, headers: json

      expect(response).to have_http_status(:not_found)
    end
  end
end

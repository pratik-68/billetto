require "rails_helper"

# Browser flow with a fake Clerk session (see spec/support/clerk.rb).
# The real Clerk sign-up / sign-in / sign-out flow lives in clerk_authentication_spec.rb.
RSpec.describe "Voting on events" do
  let!(:event) { create(:event, title: "Jazz in the park", image_url: nil) }

  def within_event(&block)
    within("##{ActionView::RecordIdentifier.dom_id(event)}", &block)
  end

  it "asks guests to sign in instead of offering vote buttons" do
    visit root_path

    within_event do
      expect(page).to have_link("Sign in to vote", href: sign_in_path)
      expect(page).to have_no_button("Upvote")
    end
  end

  it "lets a signed-in user upvote, switch to a downvote and withdraw" do
    visit root_path
    browser_sign_in_as("user_browser")
    visit root_path

    within_event { click_button "Upvote" }
    within_event do
      expect(find("[data-upvotes]")).to have_text("1")
      expect(page).to have_button("Upvote", disabled: true)
    end

    within_event { click_button "Downvote" }
    within_event do
      expect(find("[data-upvotes]")).to have_text("0")
      expect(find("[data-downvotes]")).to have_text("1")
    end

    within_event { click_button "Withdraw vote" }
    within_event do
      expect(find("[data-downvotes]")).to have_text("0")
      expect(page).to have_no_button("Withdraw vote")
    end

    expect(event_store).to have_published(
      an_event(Voting::EventUpvoted).with_data(user_id: "user_browser"),
      an_event(Voting::EventDownvoted).with_data(user_id: "user_browser", previous_vote: "up"),
      an_event(Voting::VoteWithdrawn).with_data(user_id: "user_browser", withdrawn_vote: "down")
    ).in_stream(Voting::Ballot.stream_name(event.id, "user_browser")).strict
  end

  it "shows vote totals from all users" do
    %w[user_a user_b].each { |user_id| command_bus.call(Voting::UpvoteEvent.new(event_id: event.id, user_id: user_id)) }
    command_bus.call(Voting::DownvoteEvent.new(event_id: event.id, user_id: "user_c"))

    visit root_path

    within_event do
      expect(find("[data-upvotes]")).to have_text("2")
      expect(find("[data-downvotes]")).to have_text("1")
    end
  end
end

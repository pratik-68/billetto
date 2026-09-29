# The signed-in user's vote on an event:
#   PUT    /events/:event_id/vote  (vote=up|down)  casts or switches the vote
#   DELETE /events/:event_id/vote                  withdraws it
# Both are idempotent, mirroring the Voting::Ballot aggregate.
class VotesController < ApplicationController
  COMMANDS = { "up" => Voting::UpvoteEvent, "down" => Voting::DownvoteEvent }.freeze

  before_action :require_authentication!
  before_action :set_event

  rescue_from Voting::UnknownEvent, with: -> { head :not_found }

  def update
    command_class = COMMANDS[params.require(:vote)]
    return render_invalid_vote unless command_class

    execute(command_class)
  end

  def destroy
    execute(Voting::WithdrawVote)
  end

  private

  def set_event
    @event = Event.find(params[:event_id])
  end

  def execute(command_class)
    command_bus.call(command_class.new(event_id: @event.id, user_id: current_user_id))

    respond_to do |format|
      format.html { redirect_back_or_to root_path, status: :see_other }
      format.json { render json: Voting::VoteSummary.for_event(@event, user_id: current_user_id).to_h }
    end
  end

  def render_invalid_vote
    respond_to do |format|
      format.html { redirect_back_or_to root_path, alert: "Unknown vote.", status: :see_other }
      format.json { render json: { error: "vote must be 'up' or 'down'" }, status: :unprocessable_content }
    end
  end
end

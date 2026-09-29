class EventsController < ApplicationController
  PER_PAGE = 20

  def index
    @page = [ params[:page].to_i, 1 ].max
    events = Event.upcoming.offset((@page - 1) * PER_PAGE).limit(PER_PAGE + 1).to_a

    @next_page = events.size > PER_PAGE
    @events = events.first(PER_PAGE)
    @votes = Voting::VoteSummary.for_events(@events, user_id: current_user_id)
  end
end

# Authentication via Clerk. Clerk::Rack::Middleware (added by the clerk-sdk-ruby Railtie)
# verifies the Clerk session token from the `__session` cookie or Authorization header
# and exposes the result as `request.env["clerk"]`, available here through `clerk`.
# The Clerk user id (`sub` claim, e.g. "user_2abc...") is the app's user identity.
module Authentication
  extend ActiveSupport::Concern
  include Clerk::Authenticatable

  included do
    helper_method :current_user_id, :signed_in?
  end

  private

  def current_user_id
    clerk&.user_id
  end

  def signed_in?
    current_user_id.present?
  end

  def require_authentication!
    return if signed_in?

    respond_to do |format|
      format.html { redirect_to sign_in_path, alert: "Please sign in to vote.", status: :see_other }
      format.json { render json: { error: "authentication_required" }, status: :unauthorized }
    end
  end
end

module ApplicationHelper
  def clerk_publishable_key
    ENV["CLERK_PUBLISHABLE_KEY"].presence
  end

  # The Clerk Frontend API host is encoded in the publishable key: pk_<env>_<base64("host$")>.
  def clerk_frontend_api
    Base64.decode64(clerk_publishable_key.split("_", 3).last).delete_suffix("$")
  end
end

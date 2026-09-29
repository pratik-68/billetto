# Hosts Clerk's prebuilt <SignIn/> and <SignUp/> components (mounted by ClerkJS in the layout).
class AuthController < ApplicationController
  def sign_in
    redirect_to root_path if signed_in?
  end

  def sign_up
    redirect_to root_path if signed_in?
  end
end

Rails.application.routes.draw do
  root "events#index"

  resources :events, only: :index do
    resource :vote, only: %i[update destroy]
  end

  # Pages hosting Clerk's prebuilt sign-in / sign-up components.
  get "sign-in", to: "auth#sign_in", as: :sign_in
  get "sign-up", to: "auth#sign_up", as: :sign_up

  # Rails Event Store browser (development only).
  if Rails.env.development?
    mount RubyEventStore::Browser::App.for(event_store_locator: -> { Rails.configuration.event_store }), at: "/res"
  end

  get "up" => "rails/health#show", as: :rails_health_check
end

Rails.application.routes.draw do
  # Health check — required for Railway deploy verification
  # GET /up → 200 OK
  get "up" => "rails/health#show", as: :rails_health_check

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.

  root "application#index"
end

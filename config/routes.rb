Rails.application.routes.draw do
  # Health check — required for Railway deploy verification
  get "up" => "rails/health#show", as: :rails_health_check

  root "application#index"

  # BigBox Collections webhook receiver
  # BigBox POSTs to this URL after each collection run.
  # Configure in BigBox UI: set Webhook URL + X-Bigbox-Secret header.
  namespace :webhooks do
    post "bigbox", to: "bigbox#receive"
  end

  # Admin — read-only pricing data views + pricing sync
  namespace :admin do
    resources :material_prices, only: [:index]

    # Pricing sync: seed baselines, run BigBox→default_pricings sync, check status
    scope :pricing do
      post "seed",   to: "pricing_syncs#seed",   as: :pricing_seed
      post "sync",   to: "pricing_syncs#sync",   as: :pricing_sync
      get  "status", to: "pricing_syncs#status", as: :pricing_status
    end
  end
end

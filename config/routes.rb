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

    # Pricing pipeline: load BigBox data → sync to default_pricings → check status
    scope :pricing do
      post "load",   to: "bigbox_data_loads#create", as: :pricing_load    # step 1: fetch from BigBox API
      post "seed",   to: "pricing_syncs#seed",       as: :pricing_seed    # step 2a: seed Jesse baselines
      post "sync",   to: "pricing_syncs#sync",       as: :pricing_sync    # step 2b: run BigBox→default_pricings sync
      get  "status", to: "pricing_syncs#status",     as: :pricing_status  # step 3: inspect results
      get  "debug_bigbox",       to: "bigbox_debug#show",                  as: :pricing_debug_bigbox        # diagnostic: raw BigBox search response
      get  "debug_collections",  to: "bigbox_debug#collections_probe",    as: :pricing_debug_collections   # probe Collections API
      post "debug_collections",  to: "bigbox_debug#collections_create_test"                                # test create collection
    end
  end
end

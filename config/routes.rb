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
    # TEA-198: read-only dashboard over default_pricings + material_prices,
    # grouped by trade/section with TYPE badges and BigBox live indicator.
    get "pricing_dashboard", to: "pricing_dashboards#index", as: :pricing_dashboard

    # TEA-324: per-trade product review CSV export. One row per pricing key with
    # product name + source so John can mark wrong mappings with a Y/N column.
    get "pricing_review.csv", to: "pricing_reviews#export", as: :pricing_review_csv

    # TEA-236: internal test estimate form (operator sandbox). GET renders the
    # form; POST re-renders the same page with rendered MaterialListGenerator
    # results. Read-only. NOT customer-facing.
    get  "test_estimate", to: "test_estimates#index",  as: :test_estimate
    post "test_estimate", to: "test_estimates#index"

    resources :material_prices, only: [:index] do
      collection do
        # TEA-164: mirrors bigbox:purge_junk_rows rake. Dry-run by default;
        # pass confirm=yes to actually delete. Same fingerprint as the rake:
        # source = "bigbox_loader" AND price IS NULL.
        post "purge_junk", to: "material_price_purges#create", as: :purge_junk
      end
    end

    # Pricing pipeline: load BigBox data → sync to default_pricings → check status
    scope :pricing do
      post "load",               to: "bigbox_data_loads#create",        as: :pricing_load              # legacy: per-SKU search load
      post "seed",               to: "pricing_syncs#seed",              as: :pricing_seed              # step 2a: seed Jesse baselines (plumbing only)
      post "seed_all",           to: "pricing_syncs#seed_all",          as: :pricing_seed_all          # TEA-198: seed all 8 trades from YAML
      post "sync",               to: "pricing_syncs#sync",              as: :pricing_sync              # step 2b: run BigBox→default_pricings sync
      get  "status",             to: "pricing_syncs#status",            as: :pricing_status            # step 3: inspect results
      get  "probe",              to: "pricing_syncs#probe",             as: :pricing_probe             # TEA-327: per-key source + material_price rows (read-only diag)
      post "collection",         to: "bigbox_collections#create",       as: :pricing_collection_create # create 89-SKU BigBox collection
      get  "collection/status",  to: "bigbox_collections#status",       as: :pricing_collection_status # list BigBox collections
      post "collection/ingest",  to: "bigbox_collections#ingest",       as: :pricing_collection_ingest # pull results → material_prices
      get  "debug_bigbox",          to: "bigbox_debug#show",                    as: :pricing_debug_bigbox        # diagnostic: raw BigBox search response
      get  "debug_collections",    to: "bigbox_debug#collections_probe",      as: :pricing_debug_collections   # probe Collections API
      post "debug_collections",    to: "bigbox_debug#collections_create_test"                                  # test create collection
      post "debug_destinations",   to: "bigbox_debug#destinations_probe",     as: :pricing_debug_destinations  # probe webhook destination
      get  "collection_run",       to: "bigbox_debug#collection_run",         as: :pricing_collection_run      # trigger collection run

      # TEA-341: synchronous trigger for the locked-URL daily refresh job.
      post "locked_refresh",       to: "locked_price_refreshes#create",       as: :pricing_locked_refresh
    end
  end
end

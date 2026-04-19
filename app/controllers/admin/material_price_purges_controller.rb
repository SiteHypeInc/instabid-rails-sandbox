module Admin
  # TEA-164 — HTTP mirror of the `bigbox:purge_junk_rows` rake task so the
  # purge can run via `curl` without needing the Railway CLI.
  #
  # Fingerprint (same as the rake): source = "bigbox_loader" AND price IS NULL.
  # Dry-run by default. Pass `confirm=yes` to actually delete.
  #
  #   curl -X POST https://<app>/admin/material_prices/purge_junk
  #   curl -X POST https://<app>/admin/material_prices/purge_junk?confirm=yes
  class MaterialPricePurgesController < ActionController::Base
    protect_from_forgery with: :null_session

    # POST /admin/material_prices/purge_junk
    def create
      scope = MaterialPrice.where(source: "bigbox_loader").where(price: nil)

      rows = scope.order(:trade, :sku).map do |row|
        {
          id:       row.id,
          trade:    row.trade,
          sku:      row.sku,
          zip_code: row.zip_code,
          name:     row.name
        }
      end

      if confirmed?
        deleted = scope.destroy_all.size
        remaining = MaterialPrice.where(source: "bigbox_loader").where(price: nil).count

        render json: {
          status:    "purged",
          dry_run:   false,
          deleted:   deleted,
          remaining: remaining,
          rows:      rows
        }
      else
        render json: {
          status:  "dry_run",
          dry_run: true,
          count:   rows.size,
          rows:    rows,
          hint:    "Re-run with confirm=yes to actually delete."
        }
      end
    end

    private

    def confirmed?
      params[:confirm].to_s.strip.downcase == "yes"
    end
  end
end

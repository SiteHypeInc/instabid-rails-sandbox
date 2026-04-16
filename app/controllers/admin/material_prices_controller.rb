module Admin
  class MaterialPricesController < ApplicationController
    # Sandbox: no auth middleware yet. Wire in auth before production use.
    layout false  # view is a standalone HTML page

    SORT_COLUMNS = %w[trade fetched_at price name category sku].freeze
    PER_PAGE = 100

    def index
      @prices = MaterialPrice.all
      @prices = @prices.by_trade(params[:trade]) if params[:trade].present?

      sort_col = SORT_COLUMNS.include?(params[:sort]) ? params[:sort] : "fetched_at"
      sort_dir = params[:dir] == "asc" ? "asc" : "desc"
      @prices = @prices.order("#{sort_col} #{sort_dir}")

      @prices = @prices.limit(PER_PAGE).offset(page_offset)

      @trades          = MaterialPrice.distinct.pluck(:trade).compact.sort
      @total_count     = MaterialPrice.count
      @last_receipt    = WebhookReceipt.recent.first
      @receipt_history = WebhookReceipt.recent.limit(10)
    end

    private

    def page_offset
      ([params[:page].to_i, 1].max - 1) * PER_PAGE
    end
  end
end

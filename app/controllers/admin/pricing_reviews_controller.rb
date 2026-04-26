require "csv"

module Admin
  # TEA-324: per-trade product review export.
  # Emits one CSV row per pricing key across all 8 trades so John can scan and
  # mark the wrong product mappings (Y/N column) without doing math.
  class PricingReviewsController < ApplicationController
    def export
      presenter = PricingDashboardPresenter.new
      prices_by_sku = MaterialPrice.where.not(price: nil).group_by(&:sku)

      csv = CSV.generate do |out|
        out << ["trade", "pricing_key", "product_name", "price", "source", "unit", "right_product_yn", "notes"]

        presenter.trades.each do |t|
          trade_data = presenter.trade(t[:key])
          next unless trade_data

          trade_data[:sections].each do |section|
            section[:items].each do |item|
              source, product_name = source_and_name(item, prices_by_sku)
              out << [
                t[:key],
                item[:key],
                product_name,
                item[:display_value],
                source,
                item[:unit],
                "",
                ""
              ]
            end
          end
        end
      end

      send_data csv,
                filename: "instabid_product_review_#{Date.current}.csv",
                type: "text/csv",
                disposition: params[:download] == "1" ? "attachment" : "inline"
    end

    private

    def source_and_name(item, prices_by_sku)
      if item[:bigbox_live]
        rows = (item[:hd_skus] || []).flat_map { |sku| prices_by_sku[sku.to_s] || [] }
        names = rows.map(&:name).compact.uniq
        ["HD Live", names.first || "(unnamed BigBox row)"]
      elsif item[:web_search_live]
        rows = (prices_by_sku[item[:key].to_s] || []).select { |mp| mp.source.to_s.start_with?("web_search") }
        names = rows.map(&:name).compact.uniq
        label = item[:price_source] == "web_search_range" ? "Web Search Range" : "Web Search"
        [label, names.first || "(no product name)"]
      elsif item[:source_tag] == "bigbox_hd"
        ["HD Cached", "(live BigBox row missing — value cached from prior sync)"]
      elsif item[:source_tag].to_s.start_with?("web_search")
        ["Web Cached", "(live web search row missing — value cached from prior sync)"]
      else
        ["Manual", "(no product mapped)"]
      end
    end
  end
end

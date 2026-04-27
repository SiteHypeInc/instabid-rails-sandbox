module Admin
  class PricingDashboardsController < ApplicationController
    layout false

    def index
      requested_zip = params[:zip].to_s.presence
      @selected_zip = ServiceAreaZip.find(requested_zip)&.zip if requested_zip
      @available_zips = ServiceAreaZip.zips

      presenter = PricingDashboardPresenter.new(zip_code: @selected_zip)
      @trades = presenter.trades
      requested = params[:trade].to_s.downcase
      selected_key = @trades.any? { |t| t[:key] == requested } ? requested : @trades.first&.dig(:key)
      @selected_trade_key = selected_key
      @trade = presenter.trade(selected_key) if selected_key
    end
  end
end

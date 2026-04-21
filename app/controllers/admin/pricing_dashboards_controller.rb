module Admin
  class PricingDashboardsController < ApplicationController
    layout false

    def index
      presenter = PricingDashboardPresenter.new
      @trades = presenter.trades
      requested = params[:trade].to_s.downcase
      selected_key = @trades.any? { |t| t[:key] == requested } ? requested : @trades.first&.dig(:key)
      @selected_trade_key = selected_key
      @trade = presenter.trade(selected_key) if selected_key
    end
  end
end

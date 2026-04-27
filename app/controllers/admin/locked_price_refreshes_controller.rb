module Admin
  # POST /admin/pricing/locked_refresh
  #
  # Synchronously runs LockedPriceRefreshJob (TEA-341) and returns the run
  # report as JSON. Exists because the deployed sandbox does not run a
  # solid_queue worker, so the recurring schedule in config/recurring.yml
  # never fires on its own. This endpoint gives operators (and the daily
  # external cron we will eventually wire up) a deterministic way to trigger
  # the refresh and read back the result.
  #
  # Matches the open-admin auth posture used by BigboxDataLoadsController and
  # BigboxCollectionsController in this sandbox app — no API key, sandbox-only.
  class LockedPriceRefreshesController < ActionController::Base
    protect_from_forgery with: :null_session

    def create
      report = LockedPriceRefreshJob.new.perform

      render json: {
        status:            "ok",
        attempted:         report.attempted,
        succeeded:         report.succeeded,
        failed:            report.failed,
        median_latency_ms: report.median_latency_ms,
        by_status:         report.by_status,
        by_source:         report.respond_to?(:by_source) ? report.by_source : nil
      }
    rescue => e
      Rails.logger.error("[Admin::LockedPriceRefreshesController] #{e.class}: #{e.message}")
      render json: { status: "error", error: e.class.to_s, message: e.message }, status: :internal_server_error
    end
  end
end

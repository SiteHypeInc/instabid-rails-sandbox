module Admin
  # POST /admin/pricing/locked_refresh
  #
  # Trigger LockedPriceRefreshJob (TEA-341). With SOLID_QUEUE_IN_PUMA=true the
  # job runs async inside the Puma process, so this endpoint returns
  # immediately and the operator polls catalog_skus tracking columns for
  # completion. Sync mode (?sync=1) is retained for short test runs where
  # blocking on the result is acceptable — but a full 163-SKU run blows past
  # Railway's HTTP request window, hence async-by-default.
  #
  # Matches the open-admin auth posture used by BigboxDataLoadsController and
  # BigboxCollectionsController in this sandbox app — no API key, sandbox-only.
  class LockedPriceRefreshesController < ActionController::Base
    protect_from_forgery with: :null_session

    def create
      if ActiveModel::Type::Boolean.new.cast(params[:sync])
        report = LockedPriceRefreshJob.new.perform
        render json: sync_payload(report)
      else
        job = LockedPriceRefreshJob.perform_later
        render json: {
          status:  "enqueued",
          job_id:  job.job_id,
          message: "Poll catalog_skus.last_scrape_at to track progress"
        }
      end
    rescue => e
      Rails.logger.error("[Admin::LockedPriceRefreshesController] #{e.class}: #{e.message}")
      render json: { status: "error", error: e.class.to_s, message: e.message }, status: :internal_server_error
    end

    private

    def sync_payload(report)
      {
        status:            "ok",
        attempted:         report.attempted,
        succeeded:         report.succeeded,
        failed:            report.failed,
        median_latency_ms: report.median_latency_ms,
        by_status:         report.by_status,
        by_source:         report.respond_to?(:by_source) ? report.by_source : nil
      }
    end
  end
end

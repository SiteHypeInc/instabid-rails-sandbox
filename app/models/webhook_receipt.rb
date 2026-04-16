class WebhookReceipt < ApplicationRecord
  validates :source, presence: true
  validates :received_at, presence: true
  validates :products_received, :products_upserted, :products_failed,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :recent, -> { order(received_at: :desc) }
  scope :failed, -> { where(status: "error") }

  def success?
    status == "success"
  end

  def partial?
    status == "partial"
  end
end

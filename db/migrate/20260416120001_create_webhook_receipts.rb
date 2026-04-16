class CreateWebhookReceipts < ActiveRecord::Migration[8.1]
  def change
    create_table :webhook_receipts do |t|
      t.string  :source,          null: false, default: "bigbox"
      t.integer :products_received, null: false, default: 0
      t.integer :products_upserted, null: false, default: 0
      t.integer :products_failed,   null: false, default: 0
      t.integer :payload_bytes,     null: false, default: 0
      t.string  :status,            null: false, default: "success"
      t.text    :error_summary
      t.string  :remote_ip
      t.datetime :received_at,     null: false

      t.timestamps null: false
    end

    add_index :webhook_receipts, :source
    add_index :webhook_receipts, :received_at
    add_index :webhook_receipts, :status
  end
end

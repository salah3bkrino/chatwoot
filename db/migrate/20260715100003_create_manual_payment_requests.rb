class CreateManualPaymentRequests < ActiveRecord::Migration[7.1]
  def change
    create_table :manual_payment_requests do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.references :subscription_plan, null: false, foreign_key: true
      t.integer :status, null: false, default: 0  # pending, approved, rejected
      t.integer :payment_method, null: false, default: 0  # vodafone_cash, instapay
      t.string :sender_phone
      t.string :transfer_reference
      t.string :receipt_url
      t.integer :amount_cents, null: false, default: 0
      t.string :currency, default: 'EGP'
      t.text :admin_notes
      t.references :approved_by, foreign_key: { to_table: :users }, index: true
      t.datetime :approved_at
      t.integer :months, null: false, default: 1
      t.timestamps
    end

    add_index :manual_payment_requests, :status
  end
end

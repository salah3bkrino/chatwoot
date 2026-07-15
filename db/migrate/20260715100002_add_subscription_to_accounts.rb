class AddSubscriptionToAccounts < ActiveRecord::Migration[7.1]
  def change
    add_reference :accounts, :subscription_plan, foreign_key: true, index: true
    add_column :accounts, :subscription_status, :integer, default: 0, null: false
    add_column :accounts, :subscription_end_date, :datetime
    add_column :accounts, :trial_started_at, :datetime
    add_index :accounts, :subscription_status
    add_index :accounts, :subscription_end_date
  end
end

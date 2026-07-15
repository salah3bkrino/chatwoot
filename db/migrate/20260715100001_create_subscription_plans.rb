class CreateSubscriptionPlans < ActiveRecord::Migration[7.1]
  def change
    create_table :subscription_plans do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.integer :price_cents, null: false, default: 0
      t.string :currency, null: false, default: 'USD'
      t.integer :max_agents, null: false, default: 3
      t.integer :max_inboxes, null: false, default: 5
      t.jsonb :features, null: false, default: {}
      t.boolean :active, null: false, default: true
      t.integer :trial_days, null: false, default: 14
      t.string :stripe_price_id
      t.timestamps
    end

    add_index :subscription_plans, :slug, unique: true
    add_index :subscription_plans, :active
  end
end

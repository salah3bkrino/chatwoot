# == Schema Information
#
# Table name: subscription_plans
#
#  id              :bigint           not null, primary key
#  name            :string           not null
#  slug            :string           not null
#  price_cents     :integer          default(0), not null
#  currency        :string           default("USD"), not null
#  max_agents      :integer          default(3), not null
#  max_inboxes     :integer          default(5), not null
#  features        :jsonb            default({}), not null
#  active          :boolean          default(true), not null
#  trial_days      :integer          default(14), not null
#  stripe_price_id :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#

class SubscriptionPlan < ApplicationRecord
  has_many :accounts, dependent: :nullify, inverse_of: :subscription_plan
  has_many :manual_payment_requests, dependent: :destroy

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :price_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :max_agents, numericality: { greater_than: 0 }
  validates :max_inboxes, numericality: { greater_than: 0 }

  scope :active, -> { where(active: true) }

  STARTER_FEATURES = %w[whatsapp_official campaigns captain_ai].freeze
  ENTERPRISE_FEATURES = (STARTER_FEATURES + %w[unlimited_agents green_tick_support priority_support]).freeze

  def price
    price_cents / 100.0
  end

  def feature_enabled?(feature)
    features[feature.to_s] == true
  end
end

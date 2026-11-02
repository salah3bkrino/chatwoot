require 'administrate/base_dashboard'

class ManualPaymentDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    account: Field::BelongsTo,
    subscription_plan: Field::BelongsTo,
    status: Field::String,
    amount_cents: Field::Number,
    created_at: Field::DateTime,
    updated_at: Field::DateTime,
  }.freeze

  COLLECTION_ATTRIBUTES = %i[id account subscription_plan status amount_cents].freeze
  SHOW_PAGE_ATTRIBUTES = %i[id account subscription_plan status amount_cents created_at updated_at].freeze
  FORM_ATTRIBUTES = %i[account subscription_plan status amount_cents].freeze
  COLLECTION_FILTERS = {}.freeze
end

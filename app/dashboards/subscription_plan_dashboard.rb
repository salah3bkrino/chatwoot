require 'administrate/base_dashboard'

class SubscriptionPlanDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    name: Field::String,
    price_cents: Field::Number,
    active: Field::Boolean,
    created_at: Field::DateTime,
    updated_at: Field::DateTime,
  }.freeze

  COLLECTION_ATTRIBUTES = %i[id name price_cents active].freeze
  SHOW_PAGE_ATTRIBUTES = %i[id name price_cents active created_at updated_at].freeze
  FORM_ATTRIBUTES = %i[name price_cents active].freeze
  COLLECTION_FILTERS = {}.freeze
end

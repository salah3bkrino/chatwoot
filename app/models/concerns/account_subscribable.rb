module AccountSubscribable
  extend ActiveSupport::Concern

  included do
    belongs_to :subscription_plan, optional: true
    has_many :manual_payment_requests, dependent: :destroy

    enum :subscription_status, {
      trial: 0,
      active: 1,
      suspended: 2,
      expired: 3
    }, prefix: :subscription

    scope :subscription_expiring_soon, -> { where(subscription_end_date: ..3.days.from_now).where(subscription_status: :active) }
    scope :subscription_expired, -> { where('subscription_end_date < ?', Time.current).where(subscription_status: [:active, :trial]) }
  end

  def subscription_active?
    return true if subscription_trial? && trial_still_valid?

    subscription_active_status? && subscription_end_date.present? && subscription_end_date.future?
  end

  def trial_still_valid?
    trial_started_at.present? && trial_started_at > 14.days.ago
  end

  def trial_days_remaining
    return 0 unless subscription_trial? && trial_started_at.present?

    [(trial_started_at + 14.days - Time.current).to_i / 1.day, 0].max
  end

  def days_until_expiry
    return nil if subscription_end_date.blank?

    [(subscription_end_date - Time.current).to_i / 1.day, 0].max
  end

  def agents_limit
    subscription_plan&.max_agents || 3
  end

  def inboxes_limit
    subscription_plan&.max_inboxes || 5
  end

  def plan_feature_enabled?(feature)
    subscription_plan&.feature_enabled?(feature) || false
  end

  def agents_limit_reached?
    account_users.count >= agents_limit
  end

  def inboxes_limit_reached?
    inboxes.count >= inboxes_limit
  end

  # Returns the Atmta-plan agent cap when a plan is active, nil otherwise.
  # Used by usage_limits to override the global ChatwootApp.max_limit.
  def atmta_agents_limit
    return nil unless subscription_plan.present? && subscription_active?

    subscription_plan.max_agents
  end

  # Returns the Atmta-plan inbox cap when a plan is active, nil otherwise.
  def atmta_inboxes_limit
    return nil unless subscription_plan.present? && subscription_active?

    subscription_plan.max_inboxes
  end
end

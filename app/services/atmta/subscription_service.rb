# rubocop:disable Style/ClassAndModuleChildren
module Atmta
  class SubscriptionService
    def initialize(account:)
      @account = account
    end

    # تفعيل باقة لحساب (يدوي أو عبر Stripe)
    def activate!(plan:, months: 1)
      end_date = compute_end_date(months)

      @account.update!(
        subscription_plan: plan,
        subscription_status: :active,
        subscription_end_date: end_date
      )

      # تحديث الـ limits الخاصة بالحساب بناءً على الباقة
      sync_limits_from_plan!(plan)
    end

    # تفعيل الفترة التجريبية للحسابات الجديدة
    def start_trial!(plan:)
      @account.update!(
        subscription_plan: plan,
        subscription_status: :trial,
        trial_started_at: Time.current,
        subscription_end_date: 14.days.from_now
      )
      sync_limits_from_plan!(plan)
    end

    # إيقاف الحساب عند انتهاء الاشتراك
    def suspend!
      @account.update!(
        subscription_status: :suspended,
        subscription_end_date: nil
      )
    end

    # ترقية الباقة
    def upgrade!(new_plan:, months: 1)
      activate!(plan: new_plan, months: months)
    end

    private

    def compute_end_date(months)
      base = @account.subscription_end_date&.future? ? @account.subscription_end_date : Time.current
      base + months.months
    end

    def sync_limits_from_plan!(plan)
      current_limits = @account.limits || {}

      @account.update!(
        limits: current_limits.merge(
          'max_agents' => plan.max_agents,
          'max_inboxes' => plan.max_inboxes
        )
      )
    end
  end
end
# rubocop:enable Style/ClassAndModuleChildren

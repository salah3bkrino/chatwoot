class Api::V1::Accounts::SubscriptionsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?

  # GET /api/v1/accounts/:account_id/subscription
  def show
    render json: subscription_payload
  end

  private

  def subscription_payload
    {
      plan: current_account.subscription_plan,
      status: current_account.subscription_status,
      subscription_end_date: current_account.subscription_end_date,
      trial_days_remaining: current_account.trial_days_remaining,
      days_until_expiry: current_account.days_until_expiry,
      agents_used: current_account.account_users.count,
      agents_limit: current_account.agents_limit,
      inboxes_used: current_account.inboxes.count,
      inboxes_limit: current_account.inboxes_limit,
      pending_payment_requests: current_account.manual_payment_requests.pending.count
    }
  end

end

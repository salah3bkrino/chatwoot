class Api::V1::Accounts::SubscriptionsController < Api::V1::Accounts::BaseController
  before_action :check_admin!

  # GET /api/v1/accounts/:account_id/subscription
  def show
    render json: subscription_payload
  end

  # POST /api/v1/accounts/:account_id/subscription/manual_payment
  # العميل يرفع إشعار الدفع (فودافون كاش / إنستاباي)
  def create_manual_payment
    plan = SubscriptionPlan.active.find(params[:plan_id])

    request = current_account.manual_payment_requests.create!(
      subscription_plan: plan,
      payment_method: params[:payment_method],
      sender_phone: params[:sender_phone],
      transfer_reference: params[:transfer_reference],
      amount_cents: (params[:amount].to_f * 100).to_i,
      currency: params[:currency] || 'EGP',
      months: params[:months] || 1
    )

    render json: { message: I18n.t('subscription.manual_payment_submitted'), request_id: request.id }, status: :created
  end

  # GET /api/v1/accounts/:account_id/subscription/plans
  def plans
    render json: SubscriptionPlan.active.order(:price_cents)
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

class SuperAdmin::SubscriptionPlansController < SuperAdmin::ApplicationController
  before_action :set_plan, only: [:edit, :update, :destroy]

  def index
    @plans = SubscriptionPlan.order(:price_cents)
  end

  def new
    @plan = SubscriptionPlan.new
  end

  def edit; end

  def create
    @plan = SubscriptionPlan.new(plan_params)
    if @plan.save
      redirect_to super_admin_subscription_plans_path, notice: 'Plan created successfully.' # rubocop:disable Rails/I18nLocaleTexts
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @plan.update(plan_params)
      redirect_to super_admin_subscription_plans_path, notice: 'Plan updated successfully.' # rubocop:disable Rails/I18nLocaleTexts
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @plan.update!(active: false)
    redirect_to super_admin_subscription_plans_path, notice: 'Plan suspended successfully.' # rubocop:disable Rails/I18nLocaleTexts
  end

  private

  def set_plan
    @plan = SubscriptionPlan.find(params[:id])
  end

  def plan_params
    params.require(:subscription_plan).permit(
      :name, :slug, :price_cents, :currency, :max_agents, :max_inboxes,
      :active, :trial_days, :stripe_price_id,
      features: {}
    )
  end
end

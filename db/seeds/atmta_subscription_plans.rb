# db/seeds/atmta_subscription_plans.rb
# يقوم بإنشاء باقات Atmta الأساسية إذا لم تكن موجودة

Rails.logger.info 'Seeding Atmta subscription plans...'

starter = SubscriptionPlan.find_or_create_by!(slug: 'starter') do |plan|
  plan.name = 'Starter'
  plan.price_cents = 4900  # $49
  plan.currency = 'USD'
  plan.max_agents = 3
  plan.max_inboxes = 5
  plan.trial_days = 14
  plan.active = true
  plan.features = {
    'whatsapp_official' => true,
    'campaigns' => true,
    'captain_ai' => true,
    'unlimited_agents' => false,
    'green_tick_support' => false,
    'priority_support' => false
  }
end

enterprise = SubscriptionPlan.find_or_create_by!(slug: 'enterprise') do |plan|
  plan.name = 'Enterprise'
  plan.price_cents = 9900  # $99
  plan.currency = 'USD'
  plan.max_agents = 999
  plan.max_inboxes = 50
  plan.trial_days = 14
  plan.active = true
  plan.features = {
    'whatsapp_official' => true,
    'campaigns' => true,
    'captain_ai' => true,
    'unlimited_agents' => true,
    'green_tick_support' => true,
    'priority_support' => true
  }
end

Rails.logger.info "✅ Created/Updated plans: #{starter.name} ($#{starter.price}) and #{enterprise.name} ($#{enterprise.price})"

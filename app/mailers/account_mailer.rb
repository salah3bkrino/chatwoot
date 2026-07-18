class AccountMailer < AdministratorNotifications::BaseMailer
  def subscription_expired(account, user)
    Current.account = account
    @action_url = "#{ENV.fetch('FRONTEND_URL', nil)}/app/accounts/#{account.id}/settings/billing"
    @meta = { 'account_name' => account.name }

    send_notification('Your subscription has expired', to: user.email, action_url: @action_url, meta: @meta)
  end
end

module Atmta
  class SuspendExpiredSubscriptionsJob < ApplicationJob
    queue_as :default

    def perform
      Account.subscription_expired.find_each do |account|
        Rails.logger.info("[Atmta] Suspending expired account ##{account.id} - #{account.name}")
        Atmta::SubscriptionService.new(account: account).suspend!
        notify_account_suspended(account)
      end
    end

    private

    def notify_account_suspended(account)
      owner = account.account_users.where(role: :administrator).first&.user
      return unless owner

      AccountMailer.subscription_expired(account, owner).deliver_later
    rescue StandardError => e
      Rails.logger.error("[Atmta] Failed to notify account ##{account.id}: #{e.message}")
    end
  end
end

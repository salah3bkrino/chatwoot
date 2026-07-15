# rubocop:disable Style/ClassAndModuleChildren
module Atmta
  class SuspendExpiredSubscriptionsJob < ApplicationJob
    queue_as :default

    def perform
      expired_accounts = Account.subscription_expired

      expired_accounts.find_each do |account|
        Rails.logger.info("[Atmta] Suspending expired account ##{account.id} - #{account.name}")
        Atmta::SubscriptionService.new(account: account).suspend!
        notify_account_suspended(account)
      end
    end

    private

    def notify_account_suspended(account)
      # إرسال إيميل للأدمن الرئيسي للحساب يخبره بانتهاء الاشتراك
      owner = account.account_users.where(role: :administrator).first&.user
      return unless owner

      AccountMailer.subscription_expired(account, owner).deliver_later
    rescue StandardError => e
      Rails.logger.error("[Atmta] Failed to notify account ##{account.id}: #{e.message}")
    end
  end
end
# rubocop:enable Style/ClassAndModuleChildren

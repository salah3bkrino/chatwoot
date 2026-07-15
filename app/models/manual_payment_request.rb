# == Schema Information
#
# Table name: manual_payment_requests
#
#  id                    :bigint    not null, primary key
#  account_id            :bigint    not null
#  subscription_plan_id  :bigint    not null
#  status                :integer   default(0), not null
#  payment_method        :integer   default(0), not null
#  sender_phone          :string
#  transfer_reference    :string
#  receipt_url           :string
#  amount_cents          :integer   default(0), not null
#  currency              :string    default("EGP")
#  admin_notes           :text
#  approved_by_id        :bigint
#  approved_at           :datetime
#  months                :integer   default(1), not null
#  created_at            :datetime  not null
#  updated_at            :datetime  not null
#

class ManualPaymentRequest < ApplicationRecord
  belongs_to :account
  belongs_to :subscription_plan
  belongs_to :approved_by, class_name: 'SuperAdmin', optional: true

  enum :status, { pending: 0, approved: 1, rejected: 2 }
  enum :payment_method, { vodafone_cash: 0, instapay: 1 }

  validates :sender_phone, presence: true
  validates :months, numericality: { greater_than: 0 }
  validates :amount_cents, numericality: { greater_than: 0 }

  scope :pending_review, -> { where(status: :pending).order(created_at: :desc) }

  def approve!(super_admin)
    transaction do
      update!(status: :approved, approved_by: super_admin, approved_at: Time.current)
      Atmta::SubscriptionService.new(account: account).activate!(
        plan: subscription_plan,
        months: months
      )
    end
  end

  def reject!(super_admin, notes: nil)
    update!(status: :rejected, approved_by: super_admin, approved_at: Time.current, admin_notes: notes)
  end

  def amount
    amount_cents / 100.0
  end
end

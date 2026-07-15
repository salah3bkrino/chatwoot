class SuperAdmin::ManualPaymentsController < SuperAdmin::ApplicationController
  def index
    @payment_requests = ManualPaymentRequest
                        .includes(:account, :subscription_plan, :approved_by)
                        .order(created_at: :desc)
    @payment_requests = @payment_requests.where(status: params[:status]) if params[:status].present?
  end

  # POST /super_admin/manual_payments/:id/approve
  def approve
    request = ManualPaymentRequest.find(params[:id])

    if request.pending?
      request.approve!(current_super_admin)
      redirect_to super_admin_manual_payments_path, notice: "✅ تم تفعيل اشتراك #{request.account.name} بنجاح"
    else
      redirect_to super_admin_manual_payments_path, alert: 'This request has already been processed.' # rubocop:disable Rails/I18nLocaleTexts
    end
  rescue StandardError => e
    redirect_to super_admin_manual_payments_path, alert: "خطأ: #{e.message}"
  end

  # POST /super_admin/manual_payments/:id/reject
  def reject
    request = ManualPaymentRequest.find(params[:id])
    request.reject!(current_super_admin, notes: params[:admin_notes])
    redirect_to super_admin_manual_payments_path, notice: "تم رفض طلب #{request.account.name}"
  end
end

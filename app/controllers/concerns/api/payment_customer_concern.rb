# frozen_string_literal: true

# Authorize customers before payment actions can contact a gateway or create records.
module API::PaymentCustomerConcern
  extend ActiveSupport::Concern

  included do
    before_action :authorize_payment_customers
  end

  private

  def authorize_payment_customers
    return unless current_user&.manager? && !current_user.admin?

    customer_ids = [params[:customer_id], params.dig(:cart_items, :customer_id), params[:user_id]]
    customer_ids << PaymentSchedule.find(params[:payment_schedule_id]).user.id if params[:payment_schedule_id].present?
    customer_ids << @current_order.statistic_profile.user_id if @current_order&.statistic_profile
    customer_ids.compact.uniq.each { |id| authorize User.find(id), :update? }
  end
end

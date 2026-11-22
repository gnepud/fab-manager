# frozen_string_literal: true

# module definition
module Cart; end

# Provides methods to update the customer of the given cart
class Cart::SetCustomerService
  # @param operator [User]
  def initialize(operator)
    @operator = operator
  end

  # @param order[Order]
  # @param customer [User]
  def call(order, customer)
    return order unless @operator.privileged?

    return order unless order.operator_profile_id.blank? || order.operator_profile_id == @operator.invoicing_profile.id

    return order unless order.state == 'cart'

    ActiveRecord::Base.transaction do
      order.statistic_profile_id = customer.statistic_profile.id
      order.operator_profile_id = @operator.invoicing_profile.id
      order.order_items.each do |item|
        update_item_user(item, customer)
      end
      unset_offer(order, customer)
      Cart::UpdateTotalService.new.call(order)
      order.save
    end
    order.reload
  end

  private

  # If the operator is also the customer, he cannot offer items to himself, so we unset all the offers
  # @param order[Order]
  # @param customer [User]
  def unset_offer(order, customer)
    return unless @operator == customer

    order.order_items.each do |item|
      item.is_offered = false
      item.save
    end
  end

  # @param item[OrderItem]
  # @param customer [User]
  def update_item_user(item, customer)
    return unless item.orderable_type.match(/^CartItem::/)

    orderable = item.orderable
    all_items = item.order.order_items.map(&:orderable)
    attributes = { customer_profile: customer.invoicing_profile }
    attributes[:operator_profile] = @operator.invoicing_profile if orderable.respond_to?(:operator_profile=)
    attributes.merge!(reservation_attributes(customer, all_items)) if orderable.is_a?(CartItem::Reservation) && orderable.respond_to?(:plan=)
    attributes[:subscription] = customer.subscription if orderable.is_a?(CartItem::FreeExtension)

    orderable.assign_attributes(attributes)
    validate_extension(orderable) if orderable.is_a?(CartItem::FreeExtension)
    return if orderable.save(context: all_items)

    raise ActiveRecord::RecordInvalid, orderable
  end

  def reservation_attributes(customer, all_items)
    pending_subscription = all_items.find { |orderable| orderable.is_a?(CartItem::Subscription) }
    { plan: pending_subscription&.plan || customer.subscribed_plan, new_subscription: pending_subscription.present? }
  end

  def validate_extension(orderable)
    orderable.start_at
  rescue InvalidSubscriptionError => e
    orderable.errors.add(:subscription, orderable.subscription.nil? ? :blank : e.message)
    raise ActiveRecord::RecordInvalid, orderable
  end
end

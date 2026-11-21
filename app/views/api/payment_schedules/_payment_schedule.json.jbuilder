# frozen_string_literal: true

json.extract! payment_schedule, :id, :reference, :created_at, :payment_method
json.total payment_schedule.total / 100.00
json.chained_footprint payment_schedule.check_footprint
json.user do
  json.id payment_schedule.invoicing_profile&.user&.id
  json.name payment_schedule.invoicing_profile.full_name
end
if payment_schedule.operator_profile
  json.operator do
    json.id payment_schedule.operator_profile.user_id
    json.extract! payment_schedule.operator_profile, :first_name, :last_name
  end
end
json.main_object do
  json.type payment_schedule.main_object&.object_type
  json.id payment_schedule.main_object&.object_id
end
if payment_schedule.gateway_subscription
  # this attribute is used to known which gateway should we interact with, in the front-end
  json.gateway payment_schedule.gateway_subscription.gateway
end
wallet_amount = payment_schedule.wallet_amount.to_i
items = payment_schedule.payment_schedule_items
first_item = items.min_by { |item| [item.due_date.nil? ? 1 : 0, item.due_date, item.id] } unless wallet_amount.zero?
json.items items do |item|
  json.partial! 'api/payment_schedules/payment_schedule_item', item: item
  item_wallet_amount = item == first_item ? wallet_amount : 0
  json.amount_due (item.amount - item_wallet_amount) / 100.00
end

# frozen_string_literal: true

json.title notification.notification_type
amount = notification.attached_object.total / 100.0
json.description t('.your_schedule_is_ready_html',
                   REFERENCE: notification.attached_object.reference,
                   AMOUNT: CurrencyFormatter.format(amount),
                   SCHEDULE_ID: notification.attached_object.id)

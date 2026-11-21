json.title notification.notification_type
json.description t('.refund_created',
                   AMOUNT: CurrencyFormatter.format(notification.attached_object.total / 100.00),
                   USER: ERB::Util.html_escape(notification.attached_object.invoicing_profile&.full_name))

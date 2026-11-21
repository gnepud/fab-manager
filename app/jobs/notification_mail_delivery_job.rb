# frozen_string_literal: true

# Deliver notification emails only once their database records are committed.
class NotificationMailDeliveryJob < ActionMailer::MailDeliveryJob
  self.enqueue_after_transaction_commit = :always
end

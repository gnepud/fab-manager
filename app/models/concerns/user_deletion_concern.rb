# frozen_string_literal: true

# Preserve accounts while reservations or subscriptions are still in progress.
module UserDeletionConcern
  extend ActiveSupport::Concern

  included do
    before_destroy :check_deletion_eligibility, prepend: true
  end

  private

  def check_deletion_eligibility
    return unless statistic_profile
    return unless future_reservations? || subscriptions.where(canceled_at: nil).any? { |subscription| !subscription.expired? }

    errors.add(:base, I18n.t('members.deletion_blocked'))
    throw :abort
  end

  def future_reservations?
    reservations.joins(slots_reservations: :slot)
                .where(slots_reservations: { canceled_at: nil })
                .exists?(['slots.start_at > ?', Time.current])
  end
end

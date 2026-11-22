# frozen_string_literal: true

# send a notification if child age > 18 years ago
class ChildAgeWorker
  include Sidekiq::Worker

  def perform
    children = Child.where(birthday: Date.current.advance(years: -18, days: 2))
    children.each do |child|
      NotificationCenter.call type: 'notify_user_when_child_age_will_be_18',
                              receiver: child.user,
                              attached_object: child
    end
  end
end

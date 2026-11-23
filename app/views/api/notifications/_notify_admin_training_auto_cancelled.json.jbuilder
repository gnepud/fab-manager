# frozen_string_literal: true

json.title notification.notification_type
refund_text = if notification.meta_data['auto_refund']
                t('.auto_refund')
              elsif notification.get_meta_data(:manual_refund) != false
                t('.manual_refund')
              end
json.description "#{t('.auto_cancelled_training', **{
                        TRAINING: ERB::Util.html_escape(notification.attached_object.trainings.first.name),
                        DATE: I18n.l(notification.attached_object.start_at.to_date)
                      })} #{refund_text}"

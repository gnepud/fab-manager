# frozen_string_literal: true

require 'test_helper'

class PaymentSchedulesTest < ActionDispatch::IntegrationTest
  def setup
    @user = User.friendly.find('pjproudhon')
    login_as(@user, scope: :user)
  end

  test "should get user's schedules" do
    get payment_schedules_url
    assert_response :success

    assert_equal @user.invoicing_profile.payment_schedules.count, json_response(response.body).length
  end

  test 'should report the amount due after wallet credit for the first cheque only' do
    login_as(User.with_role(:admin).first, scope: :user)
    schedule = payment_schedules('payment_schedule_12')
    schedule.update!(payment_method: 'check', wallet_amount: 6_200)
    first, second, tied = schedule.ordered_items.first(3)
    [first, second, tied].each { |item| item.update!(amount: 10_000, state: 'pending', payment_method: nil) }
    tied.update!(due_date: first.due_date)
    assert_predicate first, :first?
    assert_not_predicate tied, :first?

    first_item_queries = []
    capture_sql = lambda do |*args|
      sql = args.last[:sql]
      first_item_queries << sql if sql.match?(/FROM "payment_schedule_items".*ORDER BY .*LIMIT/i)
    end
    ActiveSupport::Notifications.subscribed(capture_sql, 'sql.active_record') do
      post '/api/payment_schedules/list', params: { query: { page: 1, size: 20 } }, as: :json
    end
    assert_response :success
    assert_empty first_item_queries

    items = json_response(response.body).find { |entry| entry[:id] == schedule.id }.fetch(:items).index_by { |item| item[:id] }
    assert_equal [100.0, 100.0], [items[first.id][:amount], items[second.id][:amount]]
    assert_equal 38.0, items[first.id][:amount_due]
    assert_equal 100.0, items[second.id][:amount_due]
    assert_equal 100.0, items[tied.id][:amount_due]
  end
end

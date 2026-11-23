# frozen_string_literal: true

require 'test_helper'

class OrderInProgressTest < ActionDispatch::IntegrationTest
  setup do
    @order = Order.find(2)
    @admin = User.find_by(username: 'admin')
    login_as(@admin, scope: :user)
  end

  teardown do
    Warden.test_reset!
  end

  test 'ready orders cannot return to in progress and keep their pickup instructions' do
    note = 'Collect at the side entrance'
    activity = @order.order_activities.find_or_initialize_by(activity_type: 'ready')
    activity.update!(operator_profile_id: @admin.invoicing_profile.id, note: note)

    %i[en fr].each do |locale|
      assert_invalid_transition(locale)
      assert_equal note, Orders::OrderService.withdrawal_instructions(@order)
    end
  end

  test 'paid orders can still be marked in progress' do
    @order.update!(state: 'paid')

    assert_difference '@order.order_activities.count', 1 do
      update_state
      assert_response :ok
    end

    assert_equal 'in_progress', @order.reload.state
    activity = @order.order_activities.order(:id).last
    assert_equal 'in_progress', activity.activity_type
    assert_equal @admin.invoicing_profile.id, activity.operator_profile_id
  end

  test 'all other states remain blocked from transitioning to in progress' do
    %w[cart payment_failed in_progress canceled refunded delivered].each do |state|
      @order.update!(state: state)
      assert_invalid_transition
    end
  end

  private

  def update_state(locale = :en)
    patch "/api/orders/#{@order.id}?locale=#{locale}", params: { order: { state: 'in_progress' } }.to_json, headers: default_headers
  end

  def assert_invalid_transition(locale = :en)
    original_attributes = @order.reload.attributes
    original_activities = @order.order_activities.order(:id).pluck(:id, :activity_type, :note)
    counts = ['OrderActivity.count', 'Notification.count', 'ProductStockMovement.count', 'Invoice.count', 'WalletTransaction.count']

    assert_no_difference counts do
      update_state(locale)
      assert_response :unprocessable_entity
    end

    assert_equal [I18n.t('errors.messages.invalid_order_state', locale: locale)], JSON.parse(response.body)
    assert_equal original_attributes, @order.reload.attributes
    assert_equal original_activities, @order.order_activities.order(:id).pluck(:id, :activity_type, :note)
  end
end

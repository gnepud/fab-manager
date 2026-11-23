# frozen_string_literal: true

require 'test_helper'

class ProductLowStockAlertTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    @product = Product.find(11)
    @product.update!(stock: { internal: 20, external: 20 }, low_stock_alert: true, low_stock_threshold: 10)
    @notification_type = NotificationType.find_by!(name: 'notify_admin_low_stock_threshold')
    NotificationPreference.where(notification_type: @notification_type).find_each { |preference| preference.update!(email: true) }
    @receivers = User.admins_and_managers.count
    login_as(User.find_by!(username: 'admin'), scope: :user)
  end

  teardown do
    Warden.test_reset!
  end

  [0, -1].each do |quantity|
    test "rejected quantity #{quantity} does not create low stock notifications" do
      stock = @product.stock.deep_dup
      assert_no_difference ['Notification.count', 'low_stock_notifications.count', 'ProductStockMovement.count'] do
        update_product(product_stock_movements_attributes: [outgoing('external', 12), outgoing('external', quantity)])
        assert_response :unprocessable_entity
      end
      assert_equal stock, @product.reload.stock
    end

    test "rejected quantity #{quantity} does not enqueue low stock emails" do
      assert_no_enqueued_emails do
        update_product(product_stock_movements_attributes: [outgoing('external', 12), outgoing('external', quantity)])
        assert_response :unprocessable_entity
      end
    end
  end

  test 'another product validation error prevents notifications and emails' do
    stock = @product.stock.deep_dup
    assert_no_difference ['Notification.count', 'low_stock_notifications.count', 'ProductStockMovement.count'] do
      assert_no_enqueued_emails do
        update_product(name: '', product_stock_movements_attributes: [outgoing('internal', 12)])
        assert_response :unprocessable_entity
      end
    end
    assert_equal stock, @product.reload.stock
  end

  test 'rejected product creation with initial stock does not notify or persist' do
    [0, 2].each do |quantity|
      assert_no_difference ['Product.count', 'ProductStockMovement.count', 'Notification.count'] do
        assert_no_enqueued_emails do
          create_product(name: '', product_stock_movements_attributes: [{ stock_type: 'external', reason: 'inward_stock', quantity: quantity }])
          assert_response :unprocessable_entity
        end
      end
    end
  end

  test 'a successful update below both thresholds alerts each recipient exactly once' do
    assert_difference 'low_stock_notifications.count', @receivers do
      assert_enqueued_emails @receivers do
        update_product(product_stock_movements_attributes: [outgoing('internal', 12), outgoing('external', 12)])
        assert_response :ok
      end
    end
    assert_equal({ 'internal' => 8, 'external' => 8 }, @product.reload.stock)

    assert_no_difference 'Notification.count' do
      assert_no_enqueued_emails do
        update_product(description: 'No stock movement')
        assert_response :ok
      end
    end
  end

  test 'successful creation with initial low stock alerts once for the saved product' do
    assert_difference 'low_stock_notifications.count', @receivers do
      assert_enqueued_emails @receivers do
        create_product(product_stock_movements_attributes: [{ stock_type: 'external', reason: 'inward_stock', quantity: 2 }])
        assert_response :created
      end
    end
    product = Product.find(JSON.parse(response.body)['id'])
    assert_equal 2, product.stock['external']
    assert_equal @receivers, low_stock_notifications.where(attached_object: product).count
  end

  test 'creation without initial movements does not alert for default zero stock' do
    assert_no_difference 'Notification.count' do
      assert_no_enqueued_emails do
        create_product({})
        assert_response :created
      end
    end
  end

  test 'stock above the threshold and disabled alerts do not notify' do
    assert_no_difference 'Notification.count' do
      assert_no_enqueued_emails do
        update_product(product_stock_movements_attributes: [outgoing('external', 2)])
        assert_response :ok
        update_product(low_stock_alert: false, product_stock_movements_attributes: [outgoing('external', 12)])
        assert_response :ok
      end
    end
  end

  test 'stock saved through the service does not alert if its transaction rolls back' do
    stock = @product.stock.deep_dup
    assert_no_difference ['Notification.count', 'ProductStockMovement.count'] do
      assert_no_enqueued_emails do
        Product.transaction(requires_new: true) do
          ProductService.update_stock(@product, [outgoing('external', 12)]).save!
          raise ActiveRecord::Rollback
        end
      end
    end
    assert_equal stock, @product.reload.stock
  end

  test 'a successful service stock save alerts only once' do
    assert_difference 'low_stock_notifications.count', @receivers do
      assert_enqueued_emails @receivers do
        ProductService.update_stock(@product, [outgoing('external', 12)]).save!
        @product.save!
      end
    end
  end

  private

  def low_stock_notifications
    Notification.where(notification_type: @notification_type)
  end

  def outgoing(stock_type, quantity)
    { stock_type: stock_type, reason: 'sold', quantity: quantity }
  end

  def update_product(attributes)
    put "/api/products/#{@product.id}",
        params: { product: { amount: @product.amount / 100.0 }.merge(attributes) }.to_json, headers: default_headers
  end

  def create_product(attributes)
    product = { name: 'Low stock product', slug: 'low-stock-product', product_category_id: 3,
                amount: 12, is_active: true, low_stock_alert: true, low_stock_threshold: 10 }
    post '/api/products', params: { product: product.merge(attributes) }.to_json, headers: default_headers
  end
end

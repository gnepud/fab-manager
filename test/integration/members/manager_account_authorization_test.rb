# frozen_string_literal: true

require 'test_helper'

class ManagerAccountAuthorizationTest < ActionDispatch::IntegrationTest
  setup do
    Warden.test_reset!
    @manager = users(:user5)
    @manager.add_role :manager
    @other_manager = users(:user3)
    @other_manager.add_role :manager
    login_as(@manager, scope: :user)
  end

  teardown do
    Warden.test_reset!
  end

  test 'manager cannot change admin credentials' do
    assert_credentials_protected(users(:user1))
  end

  test 'manager cannot change another manager credentials' do
    assert_credentials_protected(@other_manager)
  end

  test 'manager can change ordinary member credentials' do
    member = users(:user2)
    update_credentials(member)

    assert_response :ok
    assert_equal 'updated-account@example.com', member.reload.email
    assert member.valid_password?('UpdatedPassword123!')
  end

  test 'manager can update own profile' do
    put "/api/members/#{@manager.id}", params: { user: { username: 'updated-manager' } }.to_json, headers: default_headers

    assert_response :ok
    assert_equal 'updated-manager', @manager.reload.username
  end

  test 'manager cannot validate privileged accounts' do
    [users(:user1), @other_manager].each do |target|
      target.update!(validated_at: 1.day.ago)
      validated_at = target.reload.validated_at
      patch "/api/members/#{target.id}/validate", params: { user: { validated_at: Time.current } }.to_json, headers: default_headers

      assert_response :forbidden
      assert_equal validated_at, target.reload.validated_at
    end
  end

  private

  def update_credentials(target)
    put "/api/members/#{target.id}", params: {
      user: { email: 'updated-account@example.com', password: 'UpdatedPassword123!', password_confirmation: 'UpdatedPassword123!' }
    }.to_json, headers: default_headers
  end

  def assert_credentials_protected(target)
    original = target.attributes.slice('email', 'encrypted_password', 'unconfirmed_email')
    update_credentials(target)

    assert_response :forbidden
    assert_equal original, target.reload.attributes.slice('email', 'encrypted_password', 'unconfirmed_email')
  end
end

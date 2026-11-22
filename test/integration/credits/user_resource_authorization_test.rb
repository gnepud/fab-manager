# frozen_string_literal: true

require 'test_helper'

module Credits; end

class Credits::UserResourceAuthorizationTest < ActionDispatch::IntegrationTest
  setup do
    Warden.test_reset!
    @manager = users(:user5)
    @manager.add_role :manager
    @other_manager = users(:user3)
    @other_manager.add_role :manager
    @member = users(:user2)
    @admin = users(:user1)
  end

  teardown do
    Warden.test_reset!
  end

  %w[Machine Space].each do |resource|
    test "manager can read a normal member's #{resource} credits" do
      login_as(@manager, scope: :user)

      get "/api/credits/user/#{@member.id}/#{resource}", headers: default_headers

      assert_response :success
      assert_equal [], json_response(response.body)
    end

    test "manager cannot read an admin's #{resource} credits" do
      assert_credit_access @manager, @admin, resource, :forbidden
    end

    test "manager cannot read another manager's #{resource} credits" do
      assert_credit_access @manager, @other_manager, resource, :forbidden
    end

    test "member cannot read someone else's #{resource} credits" do
      assert_credit_access @member, users(:user4), resource, :forbidden
    end

    test "manager can read own #{resource} credits" do
      assert_credit_access @manager, @manager, resource, :success
    end

    test "admin can still read another manager's #{resource} credits" do
      assert_credit_access @admin, @other_manager, resource, :success
    end

    test "member can still read own #{resource} credits" do
      assert_credit_access @member, @member, resource, :success
    end
  end

  private

  def assert_credit_access(operator, target, resource, status)
    login_as(operator, scope: :user)

    get "/api/credits/user/#{target.id}/#{resource}", headers: default_headers

    assert_response status
  end
end

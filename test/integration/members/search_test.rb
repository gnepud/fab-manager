# frozen_string_literal: true

require 'test_helper'

class MembersSearchTest < ActionDispatch::IntegrationTest
  def setup
    @public_member = users(:user2)
    @private_member = users(:user3)
    @staff = users(:user1)
    @staff.update!(is_allow_contact: false)
    [@public_member, @private_member, @staff].each do |user|
      user.profile.update!(last_name: 'SearchVisibility')
    end
  end

  %i[user6 user2].each do |operator|
    test "#{operator} only finds public profiles" do
      login_as(users(operator), scope: :user)

      get '/api/members/search/SearchVisibility', headers: default_headers

      assert_response :success
      assert_equal [@public_member.id], json_response(response.body).pluck(:id)
    end
  end

  test 'admin still finds private profiles and staff' do
    login_as(@staff, scope: :user)

    get '/api/members/search/SearchVisibility', headers: default_headers

    assert_response :success
    assert_equal [@public_member.id, @private_member.id, @staff.id].sort, json_response(response.body).pluck(:id).sort
  end

  test 'manager still finds private profiles and staff' do
    manager = users(:user4)
    manager.remove_role(:member)
    manager.add_role(:manager)
    login_as(manager, scope: :user)

    get '/api/members/search/SearchVisibility', headers: default_headers

    assert_response :success
    assert_equal [@public_member.id, @private_member.id, @staff.id].sort, json_response(response.body).pluck(:id).sort
  end

  test 'search with no matches returns an empty list' do
    login_as(users(:user6), scope: :user)

    get '/api/members/search/NoSuchProfile', headers: default_headers

    assert_response :success
    assert_empty json_response(response.body)
  end

  test 'search requires authentication' do
    get '/api/members/search/SearchVisibility', headers: default_headers

    assert_response :unauthorized
  end
end

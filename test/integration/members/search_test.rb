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

  test 'booking search excludes other privileged accounts for managers but includes themselves' do
    manager, other_manager = booking_managers
    login_as(manager, scope: :user)

    get '/api/members/search/SearchVisibility', params: { booking: true }, headers: default_headers

    assert_response :success
    ids = json_response(response.body).pluck(:id).uniq
    assert_equal [@public_member.id, @private_member.id, manager.id].sort, ids.sort
    assert_not_includes ids, @staff.id
    assert_not_includes ids, other_manager.id
  end

  test 'booking search leaves admin access unchanged' do
    manager, other_manager = booking_managers
    login_as(@staff, scope: :user)

    get '/api/members/search/SearchVisibility', params: { booking: true }, headers: default_headers

    assert_response :success
    assert_equal [@public_member.id, @private_member.id, @staff.id, manager.id, other_manager.id].sort,
                 json_response(response.body).pluck(:id).uniq.sort
  end

  test 'booking search with no matches is empty' do
    manager, = booking_managers
    login_as(manager, scope: :user)

    get '/api/members/search/NoSuchProfile', params: { booking: true }, headers: default_headers

    assert_response :success
    assert_empty json_response(response.body)
  end

  private

  def booking_managers
    %i[user4 user5].map do |fixture|
      manager = users(fixture)
      manager.add_role(:manager)
      manager.profile.update!(last_name: 'SearchVisibility')
      manager
    end
  end
end

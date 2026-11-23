# frozen_string_literal: true

require 'test_helper'

class AccountDeletionTest < ActionDispatch::IntegrationTest
  setup do
    @member = users(:user2)
    @reservation = reservations('reservation_2')
    @reservation.update!(statistic_profile: @member.statistic_profile)
    subscriptions('subscription_1').update!(statistic_profile: @member.statistic_profile)
    @slot = @reservation.slots.first
    @slot.update!(start_at: 2.days.from_now, end_at: 2.days.from_now + 1.hour)
  end

  teardown do
    Warden.test_reset!
  end

  test 'self deletion refuses future bookings without logging out or changing records' do
    login_as(@member, scope: :user)
    assert_refused("/api/members/#{@member.id}")

    get "/api/members/#{@member.id}", headers: default_headers
    assert_response :success
  end

  test 'admin member deletion refuses future bookings' do
    login_as(users(:user1), scope: :user)
    assert_refused("/api/members/#{@member.id}")
  end

  test 'partner and manager deletion endpoint respects the rule' do
    login_as(users(:user1), scope: :user)
    assert_refused("/api/users/#{@member.id}")
  end

  test 'administrator deletion endpoint respects the rule' do
    @member.add_role(:admin)
    login_as(users(:user1), scope: :user)
    assert_refused("/api/admins/#{@member.id}")
  end

  test 'Devise deletion endpoint respects the rule' do
    login_as(@member, scope: :user)
    assert_refused('/users.json')
  end

  test 'HTML Devise deletion redirects with a readable alert and preserves the session' do
    login_as(@member, scope: :user)

    delete '/users'

    assert_response :see_other
    assert_redirected_to root_path(anchor: '!/dashboard/settings')
    assert_equal I18n.t('members.deletion_blocked'), flash[:alert]
    get "/api/members/#{@member.id}", headers: default_headers
    assert_response :success
  end

  test 'an active subscription alone prevents deletion' do
    @reservation.slots_reservations.first.update!(canceled_at: Time.current)
    subscriptions('subscription_1').update!(canceled_at: nil)
    login_as(@member, scope: :user)

    assert_refused("/api/members/#{@member.id}")
  end

  test 'past reservations and a canceled subscription do not prevent normal deletion' do
    @slot.update!(start_at: 2.days.ago, end_at: 2.days.ago + 1.hour)
    login_as(@member, scope: :user)

    delete "/api/members/#{@member.id}", headers: default_headers

    assert_response :no_content
    assert_not User.exists?(@member.id)
    assert Reservation.exists?(@reservation.id)
  end

  test 'Devise still deletes an eligible account' do
    @slot.update!(start_at: 2.days.ago, end_at: 2.days.ago + 1.hour)
    login_as(@member, scope: :user)

    delete '/users.json', headers: default_headers

    assert_response :no_content
    assert_not User.exists?(@member.id)
  end

  test 'SSO merge cannot silently delete an account with future bookings' do
    account = users(:user1)
    account.update!(auth_token: 'merge-deletion-test')
    @member.update!(provider: auth_providers('auth_provider_1').strategy_name, uid: 'merge-source')
    original = account.reload.attributes
    login_as(@member, scope: :user)

    put "/api/members/#{@member.id}/merge", params: { user: { auth_token: account.auth_token } }.to_json, headers: default_headers

    assert_response :unprocessable_entity
    assert_equal I18n.t('members.deletion_blocked'), json_response(response.body)[:error]
    assert User.exists?(@member.id)
    assert_equal original, account.reload.attributes
  end

  private

  def assert_refused(path)
    original = [@member.profile.reload.attributes, @member.statistic_profile.reload.attributes, @reservation.reload.attributes,
                @reservation.slots_reservations.reload.map(&:attributes), @slot.reload.attributes]

    assert_no_difference('User.count') { delete "#{path}?locale=fr", headers: default_headers }

    assert_response :unprocessable_entity
    assert_equal ['Impossible de supprimer ce compte : il possède des réservations à venir ou un abonnement actif.'],
                 json_response(response.body)
    assert_equal original, [@member.profile.reload.attributes, @member.statistic_profile.reload.attributes, @reservation.reload.attributes,
                            @reservation.slots_reservations.reload.map(&:attributes), @slot.reload.attributes]
  end
end

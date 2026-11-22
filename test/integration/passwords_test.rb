# frozen_string_literal: true

require 'test_helper'

class PasswordsTest < ActionDispatch::IntegrationTest
  test 'missing reset token returns a translated full message' do
    reset_password('')

    assert_response :unprocessable_entity
    assert_equal ['Lien de réinitialisation du mot de passe doit être rempli(e)'], json_response(response.body)[:errors]
  end

  test 'invalid reset token returns a translated full message' do
    reset_password('invalid-lifecycle-token')

    assert_response :unprocessable_entity
    assert_equal ["Lien de réinitialisation du mot de passe n'est pas valide"], json_response(response.body)[:errors]
  end

  test 'expired reset token returns a translated full message' do
    token = users(:user2).send(:set_reset_password_token)
    users(:user2).update_columns(reset_password_sent_at: 2.days.ago)

    reset_password(token)

    assert_response :unprocessable_entity
    assert_equal ['Lien de réinitialisation du mot de passe est périmé, veuillez en demander un autre'], json_response(response.body)[:errors]
  end

  test 'weak password errors remain readable' do
    token = users(:user2).send(:set_reset_password_token)

    reset_password(token, 'weak')

    assert_response :unprocessable_entity
    errors = json_response(response.body)[:errors]
    assert_kind_of Array, errors
    assert errors.any? { |message| message.include?(I18n.t('app.public.common.password_is_too_weak', locale: :fr)) }
    assert errors.any? { |message| message.include?(I18n.t('app.public.common.password_is_too_weak_explanations', locale: :fr)) }
  end

  test 'valid reset still succeeds' do
    token = users(:user2).send(:set_reset_password_token)

    reset_password(token)

    assert_response :success
    assert users(:user2).reload.valid_password?('StrongResetPassword123!')
  end

  private

  def reset_password(token, password = 'StrongResetPassword123!')
    put '/users/password.json?locale=fr', params: {
      user: { reset_password_token: token, password: password, password_confirmation: password }
    }.to_json, headers: default_headers
  end
end

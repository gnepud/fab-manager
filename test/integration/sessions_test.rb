# frozen_string_literal: true

require 'test_helper'
require 'minitest/mock'

class SessionsTest < ActionDispatch::IntegrationTest
  test 'external sign in posts back to the active provider with a CSRF token' do
    %w[SamlProvider OpenIdConnectProvider OAuth2Provider].each do |type|
      provider = Struct.new(:providable_type, :strategy_name).new(type, 'saml-local')
      Rails.configuration.stub(:auth_provider, provider) do
        get '/users/sign_in'

        assert_response :success
        assert_select 'form[action="/users/auth/saml-local"][method="post"]' do
          assert_select 'input[name="authenticity_token"]' do |inputs|
            assert inputs.first['value'].present?
          end
        end
        assert_select 'script', text: /submit.call/
      end
    end
  end
end

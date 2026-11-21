Openlab.configure do |config|
  config.base_uri = Rails.configuration.x.settings.openlab_base_uri if Rails.configuration.x.settings.openlab_base_uri
  config.httparty_verify = Rails.configuration.x.settings.openlab_ssl_verify
  config.httparty_verify_peer = Rails.configuration.x.settings.openlab_ssl_verify_peer
end

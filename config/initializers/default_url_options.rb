# frozen_string_literal: true

Rails.application.routes.default_url_options.merge!(
  host: Rails.configuration.x.settings.default_host,
  protocol: Rails.configuration.x.settings.default_protocol
)
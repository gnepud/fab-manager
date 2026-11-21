# frozen_string_literal: true

ENV['RAILS_ENV'] ||= 'test'
require_relative '../../config/environment'
require 'minitest/autorun'
require 'minitest/mock'

class XlsxTemplateLookupTest < Minitest::Test
  def test_mailer_lookup_before_controller_load_preserves_xlsx_templates
    resolver = ActionMailer::Base.view_paths.to_a.find { |path| path.to_s == Rails.root.join('app/views').to_s }
    resolver.find_all('notifications_mailer', 'layouts', false, { formats: [:html], handlers: [:erb], locale: [:en], variants: [] })

    lookup = ApplicationController.new.lookup_context
    %w[users_members users_reservations users_subscriptions availabilities_index statistics_global statistics_current].each do |name|
      template = lookup.find_template("exports/#{name}", [], false, [], formats: [:xlsx], handlers: [:axlsx])
      assert_equal :xlsx, template.format
    end

    Stylesheet.stub(:primary, '#112233') do
      content = ApplicationController.render(template: 'exports/users_members', locals: { members: [] },
                                             formats: [:xlsx], handlers: [:axlsx])
      assert_equal "PK\x03\x04".b, content.byteslice(0, 4)
    end

    assert_raises(ActionView::MissingTemplate) do
      lookup.find_template('exports/nonexistent', [], false, [], formats: [:xlsx], handlers: [:axlsx])
    end
  end
end

# frozen_string_literal: true

require 'test_helper'

class TranslationKeysTest < ActiveSupport::TestCase
  REFERENCE_LOCALE = :en
  LOCALES_TO_CHECK = %w[de es es-MX fr it no pt sv zh zu].freeze
  SKIP_FILES = %w[rails devise].freeze

  FILE_IDS = Rails.root.glob("config/locales/*.#{REFERENCE_LOCALE}.yml")
    .map { File.basename(_1, ".#{REFERENCE_LOCALE}.yml") }
    .reject { SKIP_FILES.include?(_1) }
    .push(nil)

  LOCALES_TO_CHECK.each do |locale|
    FILE_IDS.each do |file_id|
      reference_name = [file_id, REFERENCE_LOCALE, 'yml'].compact.join('.')
      locale_name = [file_id, locale, 'yml'].compact.join('.')

      test "#{locale_name} contains every leaf key from #{reference_name}" do
        reference_file = Rails.root.join('config/locales', reference_name)
        locale_file = Rails.root.join('config/locales', locale_name)
        assert_path_exists locale_file

        reference_keys = leaf_keys(YAML.load_file(reference_file).values.first)
        locale_keys = leaf_keys(YAML.load_file(locale_file).values.first)
        missing = reference_keys - locale_keys

        assert_empty missing, "Missing translations in #{locale_name}:\n#{missing.join("\n")}"
      end
    end
  end

  private

  def leaf_keys(value, prefix = [])
    return [prefix.join('.')] unless value.is_a?(Hash)

    value.flat_map { |key, child| leaf_keys(child, prefix + [key]) }
  end
end

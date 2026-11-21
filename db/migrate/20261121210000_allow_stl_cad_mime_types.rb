# frozen_string_literal: true

class AllowStlCadMimeTypes < ActiveRecord::Migration[7.2]
  MIME_TYPES = %w[model/stl application/vnd.ms-pki.stl model/x.stl-binary model/x.stl-ascii].freeze

  def up
    setting = Setting.find_by(name: 'allowed_cad_mime_types')
    return unless setting

    setting.with_lock do
      value = setting.value.to_s
      missing = MIME_TYPES - value.split
      return if missing.empty?

      Setting.set(setting.name, [value, *missing].reject(&:empty?).join(' '))
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'Cannot distinguish existing administrator MIME types from appended defaults'
  end
end

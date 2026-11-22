# frozen_string_literal: true

require 'test_helper'

class LicenceTest < ActiveSupport::TestCase
  test 'destroying a licence clears its reference on the project' do
    licence = licences('licence_1')
    project = projects('project_1')
    assert_equal licence.id, project.licence_id

    licence.destroy!

    assert_nil project.reload.licence_id
  end
end

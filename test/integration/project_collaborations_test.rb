# frozen_string_literal: true

require 'test_helper'

class ProjectCollaborationsTest < ActionDispatch::IntegrationTest
  setup do
    @project = Project.find(1)
    @collaborator = User.find(2)
    login_as(@collaborator, scope: :user)
  end

  test 'pending collaborator cannot update a project or its collaborators' do
    @project.project_users.create!(user: @collaborator, is_valid: false)
    original_name = @project.name

    %i[patch put].each do |method|
      public_send(method, "/api/projects/#{@project.id}",
                  params: { project: { name: 'Unauthorized change', user_ids: [] } }, as: :json)

      assert_response :forbidden
      assert_equal original_name, @project.reload.name
      assert @project.project_users.exists?(user: @collaborator, is_valid: false)
    end
  end

  test 'accepted collaborator can update a project' do
    @project.project_users.create!(user: @collaborator, is_valid: true)

    %i[patch put].each do |method|
      public_send(method, "/api/projects/#{@project.id}", params: { project: { name: "Accepted change via #{method}" } }, as: :json)

      assert_response :success
      assert_equal "Accepted change via #{method}", @project.reload.name
    end
  end

  test 'unrelated member cannot update a project or download markdown' do
    patch "/api/projects/#{@project.id}", params: { project: { name: 'Unauthorized change' } }, as: :json
    assert_response :forbidden

    get "/api/projects/#{@project.id}/markdown"
    assert_response :forbidden
  end

  test 'markdown download requires collaborator acceptance' do
    invitation = @project.project_users.create!(user: @collaborator, is_valid: false)

    get "/api/projects/#{@project.id}/markdown"
    assert_response :forbidden

    invitation.update!(is_valid: true)

    get "/api/projects/#{@project.id}/markdown"
    assert_response :success
  end
end

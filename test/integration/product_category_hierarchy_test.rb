# frozen_string_literal: true

require 'test_helper'

class ProductCategoryHierarchyTest < ActionDispatch::IntegrationTest
  setup do
    login_as(User.find_by(username: 'admin'), scope: :user)
  end

  teardown do
    Warden.test_reset!
  end

  test 'a category with children cannot acquire a parent' do
    assert_invalid_parent(1, 2)
  end

  test 'a category cannot have a child category as its parent' do
    assert_invalid_parent(2, 3)
  end

  test 'a category cannot be its own parent or a descendant of itself' do
    assert_invalid_parent(2, 2)
    assert_invalid_parent(1, 3)
  end

  test 'creating a third level returns a translated validation error' do
    %i[en fr].each do |locale|
      I18n.with_locale(locale) do
        assert_no_difference 'ProductCategory.count' do
          post "/api/product_categories?locale=#{locale}",
               params: { product_category: { name: 'Too deep', slug: 'too-deep', parent_id: 3 } }.to_json,
               headers: default_headers
          assert_response :unprocessable_entity
        end
        assert_equal [I18n.t('errors.messages.invalid_category_hierarchy')], JSON.parse(response.body)
        assert_no_match(/translation missing/i, response.body)
      end
    end
  end

  test 'roots and children of roots can be created and leaves can be moved or promoted' do
    [nil, 2].each_with_index do |parent_id, index|
      assert_difference 'ProductCategory.count', 1 do
        post '/api/product_categories',
             params: { product_category: { name: "Category #{index}", slug: "category-#{index}", parent_id: parent_id } }.to_json,
             headers: default_headers
        assert_response :created
      end
      assert_equal [parent_id], ProductCategory.where(slug: "category-#{index}").pluck(:parent_id)
    end

    [2, nil].each do |parent_id|
      update_parent(3, parent_id)
      assert_response :ok
      assert_equal [parent_id], ProductCategory.where(id: 3).pluck(:parent_id)
    end
  end

  private

  def update_parent(id, parent_id)
    patch "/api/product_categories/#{id}", params: { product_category: { parent_id: parent_id } }.to_json, headers: default_headers
  end

  def assert_invalid_parent(id, parent_id)
    original_hierarchy = ProductCategory.order(:id).pluck(:id, :parent_id, :position)
    update_parent(id, parent_id)
    assert_response :unprocessable_entity
    assert_equal [I18n.t('errors.messages.invalid_category_hierarchy')], JSON.parse(response.body)
    assert_equal original_hierarchy, ProductCategory.order(:id).pluck(:id, :parent_id, :position)
  end
end

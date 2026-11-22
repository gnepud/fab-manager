# frozen_string_literal: true

# Category is a first-level filter, used to categorize Products.
# It is mandatory to choose a Category when creating a Product.
class ProductCategory < ApplicationRecord
  extend FriendlyId
  friendly_id :name, use: :slugged

  validates :name, :slug, presence: true
  validates :slug, uniqueness: true
  validate :two_level_hierarchy

  belongs_to :parent, class_name: 'ProductCategory'
  has_many :children, class_name: 'ProductCategory', foreign_key: :parent_id, inverse_of: :parent, dependent: :nullify

  has_many :products, dependent: :nullify

  acts_as_list scope: :parent, top_of_list: 1

  private

  def two_level_hierarchy
    return if parent_id.blank? && parent.nil?
    return if parent.present? && parent != self && parent.parent.nil? && !children.exists?

    errors.add(:base, :invalid_category_hierarchy)
  end
end

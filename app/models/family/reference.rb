# One household fact: a wifi password, a filter size, the vet's number.
class Family::Reference < ApplicationRecord
  belongs_to :updated_by, class_name: "User", optional: true

  validates :title, presence: true
  validates :category, inclusion: { in: Family::REFERENCE_CATEGORIES }

  scope :ordered, -> { order(pinned: :desc, title: :asc) }

  # Everything the page searches over. Rendered into each row's data-search so the
  # as-you-type filter and the no-JS form fall back on exactly the same haystack.
  def searchable_text
    [title, value, notes, category].compact_blank.join(" ").downcase
  end

  def matches?(query)
    query.blank? || searchable_text.include?(query.to_s.strip.downcase)
  end
end

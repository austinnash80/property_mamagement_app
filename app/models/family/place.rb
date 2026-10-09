# Somewhere worth going: a restaurant to try, a shop, the farmers market.
class Family::Place < ApplicationRecord
  belongs_to :created_by, class_name: "User", optional: true

  validates :name, presence: true
  validates :kind, inclusion: { in: Family::PLACE_KINDS.keys }

  before_validation :tidy_url

  scope :ordered,   -> { order(favorite: :desc, name: :asc) }
  scope :want_to_go, -> { where(visited_at: nil) }
  scope :been,       -> { where.not(visited_at: nil) }
  scope :favorites,  -> { where(favorite: true) }
  scope :of_kind, ->(kind) { kind.present? ? where(kind: kind) : all }

  def visited?
    visited_at.present?
  end

  def kind_label
    Family::PLACE_KINDS[kind] || "Other"
  end

  def mark_visited!
    update!(visited_at: Time.current)
  end

  def mark_unvisited!
    update!(visited_at: nil)
  end

  private

  # "joesdiner.com" -> "https://joesdiner.com" so the link actually works.
  def tidy_url
    self.url = url.to_s.strip
    self.url = nil if url.blank?
    self.url = "https://#{url}" if url.present? && !url.match?(%r{\Ahttps?://}i)
  end
end

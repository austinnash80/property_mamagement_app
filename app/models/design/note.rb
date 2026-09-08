class Design::Note < ApplicationRecord
  belongs_to :concept, class_name: "Design::Concept", optional: true

  validates :body, presence: true
  before_validation :default_title

  scope :recent, -> { order(pinned: :desc, updated_at: :desc) }
  scope :search, lambda { |q|
    next all if q.blank?
    like = "%#{sanitize_sql_like(q)}%"
    where("design_notes.title ILIKE :q OR design_notes.body ILIKE :q OR design_notes.tags ILIKE :q", q: like)
  }

  def tag_list
    Design.tag_list(tags)
  end

  # Body preview for cards; skips the first line when it was used as the title.
  def excerpt(len = 200)
    first, rest = body.to_s.split("\n", 2)
    text = (rest.present? && derived_title(first) == title) ? rest : body.to_s
    text.strip.truncate(len)
  end

  private

  def default_title
    self.title = derived_title(body.to_s.lines.first) if title.blank?
  end

  def derived_title(line)
    line.to_s.sub(/\A#+\s*/, "").strip.truncate(80)
  end
end

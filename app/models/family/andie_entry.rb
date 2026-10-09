# One fact kept for Andie: the pediatrician's number, the home address, the
# school office line. `value` is the short answer, `notes` the context around it.
class Family::AndieEntry < ApplicationRecord
  belongs_to :updated_by, class_name: "User", optional: true

  validates :title, presence: true
  validates :section, inclusion: { in: Family::ANDIE_SECTIONS }

  scope :ordered, -> { order(title: :asc) }

  # Most of what gets kept here is a phone number, so a value that looks like one
  # is rendered as a tel: link and can be tapped to dial.
  PHONE = /\A\+?[\d\s().-]{7,}\z/

  def phone?
    value.present? && value.match?(PHONE)
  end

  def tel_href
    "tel:#{value.gsub(/[^\d+]/, '')}"
  end
end

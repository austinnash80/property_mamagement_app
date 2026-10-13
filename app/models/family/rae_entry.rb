# One fact kept for Rae, the dog: the vet's number, her food, the groomer, the
# microchip number. `value` is the short answer, `notes` the context around it.
class Family::RaeEntry < ApplicationRecord
  belongs_to :updated_by, class_name: "User", optional: true

  validates :title, presence: true
  validates :section, inclusion: { in: Family::RAE_SECTIONS }

  scope :ordered, -> { order(title: :asc) }

  # A value that looks like a phone number is rendered as a tel: link and can be
  # tapped to dial.
  PHONE = /\A\+?[\d\s().-]{7,}\z/

  def phone?
    value.present? && value.match?(PHONE)
  end

  def tel_href
    "tel:#{value.gsub(/[^\d+]/, '')}"
  end
end

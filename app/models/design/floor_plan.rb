# A 2D floor plan drawn in the browser editor (app/assets/javascripts/design/floorplan.js).
# All geometry is stored in :data in feet:
#   grid      snap size in ft (0.5 = 6")
#   walls     [{id, x1, y1, x2, y2, type: "exterior"|"interior", thickness}]
#   rooms     [{id, name, x, y, w, h}]
#   openings  [{id, type: "door"|"window", wall, pos, width, swing, hinge}]  (pos = ft from wall start)
#   labels    [{id, text, x, y, size}]
#   fixtures  [{id, kind, x, y, w, h, rot, label}]   (stairs, plumbing, appliances, furniture; see FIXTURES in the JS)
class Design::FloorPlan < ApplicationRecord
  belongs_to :concept, class_name: "Design::Concept"
  has_one_attached :thumbnail

  DEFAULT_DATA = { "version" => 1, "grid" => 0.5, "walls" => [], "rooms" => [], "openings" => [], "labels" => [], "fixtures" => [] }.freeze
  SECTIONS = %w[walls rooms openings labels fixtures].freeze

  validates :name, presence: true
  validates :width_ft, :depth_ft, numericality: { greater_than: 0, less_than_or_equal_to: 1000 }
  validate  :data_is_well_formed

  scope :ordered, -> { order(:position, :id) }

  def data_with_defaults
    DEFAULT_DATA.merge(data.presence || {})
  end

  def walls    = Array(data["walls"])
  def rooms    = Array(data["rooms"])
  def openings = Array(data["openings"])
  def fixtures = Array(data["fixtures"])

  def total_area_sqft
    rooms.sum { |r| r["w"].to_f * r["h"].to_f }
  end

  def doors_count   = openings.count { |o| o["type"] == "door" }
  def windows_count = openings.count { |o| o["type"] == "window" }

  # "data:image/png;base64,...." from the editor's canvas snapshot.
  def thumbnail_from_data_url(url)
    Design.attach_data_url(thumbnail, url, "#{name.parameterize}-thumb")
  end

  private

  def data_is_well_formed
    return if data.blank?
    return errors.add(:data, "must be an object") unless data.is_a?(Hash)
    SECTIONS.each do |k|
      errors.add(:data, "#{k} must be a list") if data.key?(k) && !data[k].is_a?(Array)
    end
  end
end

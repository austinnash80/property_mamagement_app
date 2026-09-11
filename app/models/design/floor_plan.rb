# A 2D floor plan drawn in the browser editor (app/assets/javascripts/design/floorplan.js).
# All geometry is stored in :data in feet:
#   grid      snap size in ft (0.5 = 6")
#   walls     [{id, x1, y1, x2, y2, type: "exterior"|"interior", thickness}]
#   rooms     [{id, name, pts: [[x,y],...], x, y, w, h}]   (pts = polygon; x/y/w/h = bounding box)
#   openings  [{id, type: "door"|"window", wall, pos, width, swing, hinge, height, kind (door: exterior|interior|garage), sill (window)}]  (pos = ft from wall start)
#   labels    [{id, text, x, y, size}]
#   fixtures  [{id, kind, x, y, w, h, rot, label}]   (stairs, plumbing, appliances, furniture; see FIXTURES in the JS)
#   guides    [{id, x1, y1, x2, y2, label}]   reference-only dashed lines (setbacks, distances); never rendered in 3D
#   roofs     [{id, x, y, w, h, style hip|gable|shed|flat, pitch, ridge auto|x|y, overhang, eave, high n|s|w|e}]   roof sections drawn with the Roof tool; replace the automatic roof in 3D
class Design::FloorPlan < ApplicationRecord
  belongs_to :concept, class_name: "Design::Concept"
  has_one_attached :thumbnail

  DEFAULT_DATA = { "version" => 1, "grid" => 0.5, "walls" => [], "rooms" => [], "openings" => [], "labels" => [], "fixtures" => [], "guides" => [], "roofs" => [] }.freeze
  SECTIONS = %w[walls rooms openings labels fixtures guides roofs].freeze

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

  # Rooms are polygons (pts) since 2026-09-10; older rooms are rectangles (x, y, w, h).
  def total_area_sqft
    rooms.sum { |r| self.class.room_area(r) }
  end

  def self.room_area(r)
    pts = Array(r["pts"])
    return r["w"].to_f * r["h"].to_f if pts.size < 3
    pts.each_index.sum { |i| a = pts[i]; b = pts[(i + 1) % pts.size]; a[0].to_f * b[1].to_f - b[0].to_f * a[1].to_f }.abs / 2
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

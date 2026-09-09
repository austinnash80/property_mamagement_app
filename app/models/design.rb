# Namespace for the Design Center section (architectural design: concepts,
# idea notes, image library; floor plans and renderings in later phases).
# Independent of the property-management and portfolio tables; every table
# here is prefixed design_.
module Design
  def self.table_name_prefix
    "design_"
  end

  CONCEPT_KINDS    = %w[whole_home floor_plan remodel adu exterior interior kitchen bath landscape other].freeze
  CONCEPT_STATUSES = %w[idea in_progress complete].freeze
  IMAGE_CATEGORIES = %w[inspiration sketch floor_plan elevation exterior interior kitchen bath landscape materials rendering site other].freeze

  # Attach a browser data URL ("data:image/png;base64,...") to an Active Storage attachment.
  def self.attach_data_url(attachment, url, basename)
    m = url.to_s.match(%r{\Adata:(image/(\w+));base64,(.+)\z}m) or return false
    ext = m[2] == "jpeg" ? "jpg" : m[2]
    attachment.attach(io: StringIO.new(Base64.decode64(m[3])), filename: "#{basename}.#{ext}", content_type: m[1])
    true
  end

  # "kitchen island, white oak" -> ["kitchen island", "white oak"]
  # "kitchen island white-oak"  -> ["kitchen", "island", "white-oak"]
  def self.tag_list(str)
    s = str.to_s
    (s.include?(",") ? s.split(",") : s.split).map(&:strip).reject(&:blank?)
  end
end

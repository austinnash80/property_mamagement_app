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

  # "kitchen island, white oak" -> ["kitchen island", "white oak"]
  # "kitchen island white-oak"  -> ["kitchen", "island", "white-oak"]
  def self.tag_list(str)
    s = str.to_s
    (s.include?(",") ? s.split(",") : s.split).map(&:strip).reject(&:blank?)
  end
end

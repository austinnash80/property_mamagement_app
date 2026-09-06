# Namespace for the Project Portfolio section. Fully independent of the
# property-management tables; every table here is prefixed portfolio_.
module Portfolio
  def self.table_name_prefix
    "portfolio_"
  end

  TRADES = %w[
    Demolition Framing Drywall Insulation Electrical Plumbing HVAC Roofing
    Flooring Tile Cabinetry Countertops Painting Doors\ &\ Windows Trim\ &\ Finish
    Landscaping Concrete\ &\ Masonry Fencing Appliances Furnishing Cleaning Other
  ].freeze

  PERFORMED_BY = { "self" => "Self (Austin)", "sub" => "Subcontractor", "mixed" => "Self + Sub" }.freeze
  PROJECT_STATUSES = %w[planned in_progress completed].freeze
  PHOTO_STAGES = %w[before during after].freeze
  EXPENSE_CATEGORIES = %w[materials labor permits tools rentals delivery other].freeze
  DOCUMENT_KINDS = %w[permit plan contract invoice warranty inspection other].freeze
  PROPERTY_TYPES = %w[residential condo commercial].freeze
end

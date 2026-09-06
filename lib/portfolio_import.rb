# Helpers shared by the portfolio import rake tasks: property guessing,
# trade flags, and suggested grouping for triage.
module PortfolioImport
  PROPERTY_RULES = [
    [/\b(332|334)\b|playa|la jolla|92037/i,                       "332/334 Playa"],
    [/54493/i,                                                    "54493 Tanglewood (sold)"],
    [/tanglewood|54487|la quinta|pga ?west|92253/i,               "54487 Tanglewood"],
    [/cortez|indian wells|78200|78-200|92210/i,                   "Cortez"],
    [/trellis|530 k|k st|unit 212|#212|92101 .*212/i,             "Trellis"],
    [/pacific hwy|1205 pacific|unit 404|#404|grande north/i,      "Pacific"],
    [/office|fourth ave|4th ave|2750|sequoia cpe|suite 100|ste 100/i, "Office"]
  ].freeze

  FLAG_RULES = {
    "CABINET"    => /cabinet|vanity|drawer|door front|toe kick|filler|crown mold|cabinets/i,
    "FLOORING"   => /floor|vinyl plank|laminate|underlayment|baseboard|transition strip|reducer|t-mold|quarter round|shoe mold|lvp/i,
    "TILE"       => /\btile|grout|thinset|mortar|backsplash|ledger panel/i,
    "COUNTERTOP" => /countertop|quartz|granite|butcher block/i,
    "PLUMBING"   => /plumb|faucet|toilet|water heater|sewer|repipe|pex|valve|shower|tub|drain|sink/i,
    "ELECTRICAL" => /electric|outlet|breaker|panel|wire|romex|light fixture|recessed|switch|ev charger/i,
    "HVAC"       => /hvac|heating|air conditioning|furnace|condenser|thermostat|duct|mini split|lennox|timo|sun valley|jackson and foster|all seasons/i,
    "ROOFING"    => /roof|shingle|gaf|eagleview/i,
    "APPLIANCE"  => /appliance|thermador|fridge|refrigerator|dishwasher|range|oven|washer|dryer|microwave/i,
    "PERMIT"     => /permit|dsd|plan check|development services|owner builder|inspection/i,
    "DESIGN"     => /architect|hllk|design development|schematic|structural|geotech|topo|survey|engineering|qualls|geowest/i,
    "DOORS_WINDOWS" => /window|sliding door|door co|vision windows|precision door|garage door/i,
    "PAINT"      => /paint|primer|behr|sherwin|dunn edwards/i,
    "LUMBER"     => /lumber|2x4|2x6|plywood|osb|stud|framing|joist|beam/i,
    "DRYWALL"    => /drywall|sheetrock|joint compound|mud|tape/i,
    "FASTENERS"  => /screw|nail|anchor|fastener/i,
    "TOOLS"      => /tool|blade|drill|saw|rental contract|rental/i
  }.freeze

  # Vendors that only ever worked on one property (from the ledger + email review).
  VENDOR_HINTS = [
    [/hllk|qualls|geowest|acculine|topo|roof masters|mission roofing|coast roofing|eagleview|r\.?a\.?d\.? construction|chickenbone|dsd|development services|accela|matt goodwin|hilary/i, "332/334 Playa"],
    [/bill howe|white glove|cos\b|vinyl flooring|seabreeze|trellis|kathy/i, "Trellis"],
    [/premier residential|vantage point|prs\b|la quinta|pga west|timo'?s|jackson and foster|roto-rooter|indian wells/i, nil], # desert vendors: Cortez or Tanglewood, leave to the two-property hint below
    [/grande north|action property/i, "Pacific"],
    [/sliding door co|cabinets & more|costa lake|granite factory|gfd|sequoia|nash office|gtc design/i, "Office"]
  ].freeze

  def self.guess_property(text)
    PROPERTY_RULES.each { |re, name| return name if re.match?(text.to_s) }
    VENDOR_HINTS.each { |re, name| return name if name && re.match?(text.to_s) }
    nil
  end

  # Softer hint used only for the suggested group when no property is known.
  def self.region_hint(text)
    return "Desert (Cortez/Tanglewood)" if text.to_s =~ /timo'?s|jackson and foster|roto-rooter|premier residential|vantage point|desert|coachella|iid\b/i
    return "San Diego (Trellis/Pacific/Playa)" if text.to_s =~ /point loma|alvarado|valley plumbing|sun valley|all seasons|pats plumbing|extreme plumbing|protec|xyg|precision door|mr\.? rooter/i
    nil
  end

  def self.flags_for(text)
    FLAG_RULES.select { |_, re| re.match?(text.to_s) }.keys
  end

  # Coarse "suggested group" so the inbox can present likely projects:
  # <property or ?> · <year> · <dominant trade>
  def self.suggested_group(property, date, flags, vendor: nil, region: nil)
    yr = date ? date.year : "????"
    trade = (flags & %w[DESIGN PERMIT ROOFING HVAC PLUMBING ELECTRICAL CABINET FLOORING TILE COUNTERTOP APPLIANCE DOORS_WINDOWS]).first ||
            (flags & %w[LUMBER DRYWALL PAINT]).first || (flags.include?("TOOLS") ? "TOOLS/RENTAL" : "MISC")
    "#{property || region || 'Unknown property'} · #{yr} · #{trade}"
  end
end

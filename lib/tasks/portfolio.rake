namespace :portfolio do
  desc "Seed the portfolio property list (idempotent; matches on name)"
  task seed_properties: :environment do
    rows = [
      { name: "Office — 2750 Fourth Ave STE 100", address: "2750 Fourth Ave STE 100, San Diego, CA 92103", property_type: "commercial", status: "owned", position: 1, notes: "Full office build-out from a shell." },
      { name: "54493 Tanglewood (sold)",          address: "54493 Tanglewood, La Quinta, CA 92253",           property_type: "residential", status: "sold",  position: 2 },
      { name: "54487 Tanglewood",                 address: "54487 Tanglewood, La Quinta, CA 92253",           property_type: "residential", status: "owned", position: 3 },
      { name: "Cortez",                           address: "78200 Cortez Ln. Unit 144, Indian Wells, CA 92210", property_type: "condo",     status: "owned", position: 4 },
      { name: "Trellis",                          address: "530 K St Unit 212, San Diego, CA 92101",          property_type: "condo",       status: "owned", position: 5 },
      { name: "Pacific",                          address: "1205 Pacific Hwy Unit 404, San Diego, CA 92101",  property_type: "condo",       status: "owned", position: 6 },
      { name: "332 Playa Del Norte",              address: "332 Playa Del Norte, La Jolla, CA 92037",         property_type: "residential", status: "owned", position: 7 },
      { name: "334 Playa Del Norte",              address: "334 Playa Del Norte, La Jolla, CA 92037",         property_type: "residential", status: "owned", position: 8 }
    ]
    rows.each do |attrs|
      rec = Portfolio::Property.find_or_initialize_by(name: attrs[:name])
      rec.assign_attributes(attrs) if rec.new_record?
      rec.save!
      puts "#{rec.new_record? ? 'created' : 'ok'}  #{rec.name}"
    end
  end
end

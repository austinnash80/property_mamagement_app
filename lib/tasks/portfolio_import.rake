require "csv"
require "json"
require_relative "../portfolio_import"

namespace :portfolio do
  # rake "portfolio:import_homedepot[orders.json,receipts.json,/path/to/homedepot]"
  desc "Import Home Depot orders (harvested JSON) into the portfolio inbox"
  task :import_homedepot, [:orders_json, :receipts_json, :dir] => :environment do |_, args|
    raw      = JSON.parse(File.read(args[:orders_json]))
    # accept either the raw pf_orders map or the combined export {orders:, receipts:}
    orders   = raw["orders"] || raw
    receipts = raw["receipts"] || (args[:receipts_json] && File.exist?(args[:receipts_json].to_s) ? JSON.parse(File.read(args[:receipts_json])) : {})
    dir      = args[:dir] || File.expand_path("~/Projects/portfolio-sources/homedepot")
    created = updated = 0
    orders.each do |key, rec|
      link = rec["link"] || {}; d = rec["data"] || {}
      next if d["error"] && d.size == 1
      on   = d["orderNumber"] || link["order"]
      date = (d["salesDate"] || link["date"]).to_s
      lis  = (d["fulfillmentGroups"] || []).flat_map { |g| g["lineItems"] || [] }
      lis  = d["lineItems"] if lis.empty? && d["lineItems"]
      items = lis.map do |li|
        { "sku" => li["skuNumber"] || li["thdSku"], "model" => li["modelNumber"], "brand" => li["brandName"],
          "description" => li["description"] || li["itemDescFromCatalog"] || li["itemDescFromPOS"],
          "department" => li["departmentName"], "class_name" => li["className"], "subclass" => li["subClassName"],
          "qty" => li["quantity"] || li["currentQuantity"], "unit_price" => li["netUnitPrice"] || li["unitPrice"] || li["originalUnitPrice"],
          "line_total" => li["pretaxTotal"] || li["totalPrice"] }
      end
      text  = ([d["POJobName"], d["storeName"], d["orderOrigin"]] + items.map { |i| [i["description"], i["department"], i["class_name"], i["brand"]].join(" ") }).join(" | ")
      flags = PortfolioImport.flags_for(text)
      flags -= %w[TOOLS] if flags.size > 1 && flags.include?("TOOLS") && !text.match?(/rental/i)
      prop  = PortfolioImport.guess_property(d["POJobName"].to_s) || nil
      total = d["grandTotalAmount"]
      is_return = link["tt"] == "R" || (total && total.to_f < 0)
      title = "Home Depot #{is_return ? 'return' : 'purchase'} ##{on} — #{items.size} item#{'s' unless items.size == 1}: #{items.first(3).map { |i| i['description'].to_s.truncate(45) }.join('; ')}"
      occurred = Date.parse(date) rescue nil
      doc = Portfolio::SourceDocument.find_or_initialize_by(source: "homedepot", source_ref: "#{on}|#{date}")
      doc.assign_attributes(occurred_on: occurred, vendor: "The Home Depot", title: title.truncate(250),
        description: "Store: #{d['storeName']} ##{d['storeNumber'] || link['store']} · Origin: #{d['orderOrigin'] || link['origin']} · PO/Job: #{d['POJobName'].presence || '-'} · Payment: #{(d['tenders'] || d['paymentMethods'] || []).map { |t| "#{t['type'] || t['cardType']} #{t['value'] || t['lastFour']}" }.join(', ')}",
        property_guess: prop, amount: total, kind: (is_return ? "receipt" : "receipt"), flags: flags.join(" "),
        suggested_group: PortfolioImport.suggested_group(prop, occurred, flags),
        metadata: { "line_items" => items, "po_job" => d["POJobName"], "store" => d["storeName"], "store_number" => d["storeNumber"] || link["store"],
                    "origin" => d["orderOrigin"] || link["origin"], "subtotal" => d["subTotalAmount"], "tax" => d["taxTotalAmount"], "is_return" => is_return })
      new_rec = doc.new_record?
      doc.save!
      base = "HD_#{date}_#{on.to_s.gsub(/[^A-Za-z0-9-]/, '')}"
      attach = ->(path) { doc.files.attach(io: File.open(path), filename: File.basename(path)) unless doc.files.any? { |f| f.filename.to_s == File.basename(path) } }
      pdf = File.join(dir, "receipts_pdf", "#{base}.pdf");        attach.call(pdf) if File.exist?(pdf)
      img = File.join(dir, "receipts_store_images", "#{base}_receipt.jpg"); attach.call(img) if File.exist?(img)
      new_rec ? created += 1 : updated += 1
    end
    puts "Home Depot import: created #{created}, updated #{updated}, total #{Portfolio::SourceDocument.where(source: 'homedepot').count}"
  end

  # rake "portfolio:import_gmail[/path/to/PF_manifest_gmail_attachments.csv,/path/to/folder,/path/to/curated.csv]"
  desc "Import Gmail attachments (from the downloaded PF_ files + manifest) into the inbox"
  task :import_gmail, [:manifest_csv, :dir, :curated_csv] => :environment do |_, args|
    dir = args[:dir]
    rows = CSV.read(args[:manifest_csv], headers: true)
    curated = {}
    if args[:curated_csv] && File.exist?(args[:curated_csv])
      CSV.read(args[:curated_csv], headers: true).each { |r| curated[[r["subject"], r["date"]]] = r }
    end
    by_thread = rows.group_by { |r| r["thread_id"] }
    created = updated = missing_files = 0
    by_thread.each do |tid, trs|
      first = trs.first
      subj  = first["subject"].to_s; sender = first["sender"].to_s.sub(/\s*\d+$/, "").sub(/,?\s*me\b/, "").strip
      date  = (Date.parse(first["date"].to_s.gsub(/[  ]/, " ")) rescue nil)
      files = trs.map { |r| r["saved_as"] }.compact_blank.uniq
      names = trs.map { |r| r["attachment_name"] }.compact_blank.uniq
      text  = [subj, sender, names.join(" ")].join(" | ")
      prop  = PortfolioImport.guess_property(text)
      flags = PortfolioImport.flags_for(text)
      kind  = case text
              when /invoice|receipt|payment/i then "invoice"
              when /estimate|proposal|quote|bid/i then "estimate"
              when /permit|dsd|plan check|issuance|owner builder/i then "permit"
              when /plans|architectural set|design development|schematic|survey|topo|geotech|structural/i then "plans"
              when /contract|agreement|scope/i then "contract"
              else (names.all? { |n| n =~ /\.(jpe?g|png|heic|gif)$/i } && names.any?) ? "photo" : "other"
              end
      # amount: try to read $ figures from subject/filenames (e.g., "Austin Nash 580.00.pdf", "invoice $350.00")
      amt = text.scan(/\$\s?([\d,]+\.\d{2})/).flatten.first || names.join(" ").scan(/(?<![\d.])(\d{2,5}\.\d{2})(?!\d)/).flatten.first
      doc = Portfolio::SourceDocument.find_or_initialize_by(source: "gmail", source_ref: tid)
      doc.assign_attributes(occurred_on: date, vendor: sender.presence, title: subj.presence || names.first,
        description: "Attachments: #{names.join('; ')}", property_guess: prop, amount: (amt && amt.delete(",").to_f),
        kind: kind, flags: flags.join(" "), suggested_group: PortfolioImport.suggested_group(prop, date, flags),
        metadata: { "attachment_names" => names, "gmail_date" => first["date"], "sender_raw" => first["sender"] })
      new_rec = doc.new_record?
      doc.save!
      files.each do |fn|
        path = File.join(dir, fn)
        unless File.exist?(path) then missing_files += 1; next end
        next if doc.files.any? { |f| f.filename.to_s == fn }
        doc.files.attach(io: File.open(path), filename: fn)
      end
      new_rec ? created += 1 : updated += 1
    end
    puts "Gmail import: created #{created}, updated #{updated}, missing files #{missing_files}, total #{Portfolio::SourceDocument.where(source: 'gmail').count}"
  end

  desc "Recompute property guesses, flags and suggested groups for inbox docs still unreviewed"
  task regroup: :environment do
    Portfolio::SourceDocument.unreviewed.find_each do |d|
      text = [d.title, d.vendor, d.description, d.metadata["po_job"], d.metadata["store"], d.metadata["origin"], d.line_items.map { |li| li.values_at("description", "department", "class_name").join(" ") }.join(" ")].join(" | ")
      flags = PortfolioImport.flags_for(text)
      prop  = d.property_guess.presence || PortfolioImport.guess_property(text)
      group = PortfolioImport.suggested_group(prop, d.occurred_on, flags, region: PortfolioImport.region_hint(text))
      if d.source == "icloud"
        path = (d.metadata["path"] || d.metadata["folder"]).to_s
        parts = path.split("/")
        sub = parts.length >= 2 ? parts[1..-1].reject { |x| x == File.basename(path) && parts.length > 2 && d.metadata["path"] }.first(2).join(" / ") : nil
        sub = parts[1] if parts.length == 2 && d.metadata["path"] # file directly in property folder
        group = "#{prop || parts[0]} · #{(sub.presence || 'root folder')}"
      end
      d.update_columns(flags: flags.join(" "), property_guess: prop, suggested_group: group)
    end
    puts "regrouped #{Portfolio::SourceDocument.unreviewed.count}"
  end
end

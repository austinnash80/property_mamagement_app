require_relative "../portfolio_import"

namespace :portfolio do
  # rake "portfolio:import_icloud[/path/to/folder]"
  # Imports every file under the property sub-folders (Cortez, Playa Norte, ...)
  # as inbox source documents. One document per file, except photo folders where
  # each folder becomes one document with many images. HEIC images are converted
  # to JPEG with `sips` first so browsers can show them.
  desc "Import the iCloud Properties folder tree into the portfolio inbox"
  task :import_icloud, [:root] => :environment do |_, args|
    root = File.expand_path(args[:root] || "~/Projects/portfolio-sources/gmail")
    folder_property = { "Cortez" => "Cortez", "Pacific" => "Pacific", "Playa Norte" => "332/334 Playa", "Tanglewood" => "54487 Tanglewood", "Trellis" => "Trellis", "Other" => nil }
    skip_re = /\.(indd|idlk|js|psd|ai|html|DS_Store|css|map|json|xml|plist)$/i
    image_re = /\.(jpe?g|png|heic|heif|gif|webp|tiff?)$/i
    tmp = Rails.root.join("tmp", "heic"); FileUtils.mkdir_p(tmp)
    created = updated = skipped = 0

    to_jpeg = lambda do |path|
      return path unless path =~ /\.hei[cf]$/i
      out = tmp.join(File.basename(path).sub(/\.hei[cf]$/i, ".jpg")).to_s
      system("sips", "-s", "format", "jpeg", "-s", "formatOptions", "85", path, "--out", out, out: File::NULL, err: File::NULL) unless File.exist?(out)
      File.exist?(out) ? out : nil
    end
    date_from = lambda do |text, fallback_path|
      m = text.match(/(20\d\d)[-_.\/ ]?(\d\d)[-_.\/ ]?(\d\d)/) && (Date.new(m[1].to_i, m[2].to_i, m[3].to_i) rescue nil)
      m ||= text.match(/\b(\d{1,2})[-\/.](\d{1,2})[-\/.](20?\d\d)\b/) && (Date.strptime([$1, $2, $3.length == 2 ? "20#{$3}" : $3].join("/"), "%m/%d/%Y") rescue nil)
      m ||= (y = text[/\b(20[12]\d)\b/, 1]) && Date.new(y.to_i, 6, 30)
      m || (File.mtime(fallback_path).to_date rescue nil)
    end

    folder_property.each do |folder, prop|
      dir = File.join(root, folder)
      next unless Dir.exist?(dir)
      all = Dir.glob(File.join(dir, "**", "*")).select { |f| File.file?(f) && f !~ skip_re && File.basename(f) !~ /^\./ }
      # group: photos by their immediate folder; everything else one per file
      photo_groups = all.select { |f| f =~ image_re }.group_by { |f| File.dirname(f) }
      others = all.reject { |f| f =~ image_re }

      photo_groups.each do |pdir, files|
        rel = pdir.sub(root + "/", "")
        ref = "icloud:#{rel}"
        text = "#{folder} #{rel}"
        flags = PortfolioImport.flags_for(text)
        dates = files.map { |f| File.mtime(f).to_date rescue nil }.compact
        occurred = dates.min
        doc = Portfolio::SourceDocument.find_or_initialize_by(source: "icloud", source_ref: ref)
        doc.assign_attributes(occurred_on: occurred, vendor: "iCloud folder", title: "Photos: #{rel} (#{files.size})",
          description: "Folder #{rel}; dates #{dates.minmax.map(&:to_s).uniq.join(' – ')}", property_guess: prop || PortfolioImport.guess_property(text),
          kind: "photo", flags: flags.join(" "), suggested_group: PortfolioImport.suggested_group(prop || PortfolioImport.guess_property(text), occurred, flags.presence || ["PHOTOS"]),
          metadata: { "folder" => rel, "file_count" => files.size, "files" => files.map { |f| File.basename(f) }.first(300) })
        new_rec = doc.new_record?; doc.save!
        existing = doc.files.map { |f| f.filename.to_s }.to_set
        files.sort.each do |f|
          src = to_jpeg.call(f) or next
          fn = File.basename(src)
          next if existing.include?(fn)
          doc.files.attach(io: File.open(src), filename: fn)
        end
        new_rec ? created += 1 : updated += 1
      end

      others.each do |f|
        rel = f.sub(root + "/", "")
        ref = "icloud:#{rel}"
        name = File.basename(f, ".*")
        text = "#{folder} #{rel}"
        flags = PortfolioImport.flags_for(text)
        kind = case text
               when /invoice|receipt|reciept|payment|paid/i then "invoice"
               when /estimate|proposal|quote|bid/i then "estimate"
               when /permit|dsd|plan check|inspection/i then "permit"
               when /plan|drawing|design|render|architect|hllk|survey|geotech|structural|dims/i then "plans"
               when /contract|agreement|lease|scope|signed/i then "contract"
               else "other"
               end
        next if rel =~ /lease|mortgage|insurance|property tax|tax bill|closing|escrow|buyer statement|business tax|tot ?certificate|short term rental/i && kind != "invoice" && (skipped += 1)
        amt = name.scan(/\$\s?([\d,]+\.\d{2})/).flatten.first
        occurred = date_from.call(rel, f)
        doc = Portfolio::SourceDocument.find_or_initialize_by(source: "icloud", source_ref: ref)
        doc.assign_attributes(occurred_on: occurred, vendor: (rel.split("/")[1] if rel.count("/") >= 2), title: name.tr("_", " "),
          description: "iCloud file #{rel}", property_guess: prop || PortfolioImport.guess_property(text), amount: (amt && amt.delete(",").to_f),
          kind: kind, flags: flags.join(" "), suggested_group: PortfolioImport.suggested_group(prop || PortfolioImport.guess_property(text), occurred, flags),
          metadata: { "path" => rel, "bytes" => File.size(f) })
        new_rec = doc.new_record?; doc.save!
        doc.files.attach(io: File.open(f), filename: File.basename(f)) unless doc.files.any? { |a| a.filename.to_s == File.basename(f) }
        new_rec ? created += 1 : updated += 1
      end
    end
    puts "iCloud import: created #{created}, updated #{updated}, skipped (leases/mortgage/insurance/tax) #{skipped}, total #{Portfolio::SourceDocument.where(source: 'icloud').count}"
  end
end

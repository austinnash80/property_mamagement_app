# Design Center import tasks. Run with Spring disabled and the AWS keys loaded so
# files land in S3 like browser uploads:
#   export DISABLE_SPRING=1 && source ~/.zshrc
namespace :design do
  IMAGE_EXTENSIONS = %w[.jpg .jpeg .png .gif .webp .heic .heif .tif .tiff .bmp].freeze

  desc "Import images from a file or folder (recursive). rails 'design:import_images[/path,Concept title,category,tags]'"
  task :import_images, [:path, :concept, :category, :tags] => :environment do |_t, args|
    path = File.expand_path(args[:path].to_s)
    abort "Usage: rails 'design:import_images[/path/to/file_or_folder,Concept title,category,tags]'" if args[:path].blank? || !File.exist?(path)

    category = args[:category].presence || "inspiration"
    abort "Unknown category '#{category}'. Use one of: #{Design::IMAGE_CATEGORIES.join(', ')}" unless Design::IMAGE_CATEGORIES.include?(category)
    concept = args[:concept].present? ? Design::Concept.find_or_create_by!(title: args[:concept].strip) : nil

    files = if File.directory?(path)
      Dir.glob(File.join(path, "**", "*")).select { |f| File.file?(f) && IMAGE_EXTENSIONS.include?(File.extname(f).downcase) }.sort
    else
      [path]
    end
    abort "No image files found under #{path}" if files.empty?

    created = skipped = 0
    files.each do |f|
      checksum = Digest::MD5.file(f).base64digest
      already  = ActiveStorage::Attachment.where(record_type: "Design::Image", name: "file").joins(:blob)
                                          .where(active_storage_blobs: { checksum: checksum }).exists?
      if already
        skipped += 1
        puts "skip      #{File.basename(f)} (already imported)"
        next
      end

      image = Design::Image.new(concept: concept, category: category, tags: args[:tags].presence)
      image.file.attach(io: File.open(f), filename: File.basename(f))
      image.save!
      created += 1
      puts "imported  #{File.basename(f)} -> /design/images/#{image.id}"
    end

    service = ActiveStorage::Blob.service.class.name.demodulize.sub("Service", "")
    puts "Done: #{created} imported, #{skipped} skipped#{concept ? ", concept '#{concept.title}'" : ''}, category #{category}, storage #{service}."
  end

  desc "Add a note from a text/markdown file (first line becomes the title). rails 'design:add_note[/path/to/idea.md,Concept title]'"
  task :add_note, [:path, :concept] => :environment do |_t, args|
    path = File.expand_path(args[:path].to_s)
    abort "Usage: rails 'design:add_note[/path/to/idea.md,Concept title]'" unless File.file?(path)

    concept = args[:concept].present? ? Design::Concept.find_or_create_by!(title: args[:concept].strip) : nil
    text    = File.read(path).strip
    first, rest = text.split("\n", 2)
    heading = first.to_s.start_with?("#") || (first.to_s.length <= 80 && rest.present?)
    title   = heading ? first.sub(/\A#+\s*/, "").strip : nil
    body    = heading && rest.present? ? rest.strip : text

    note = Design::Note.create!(title: title, body: body, concept: concept)
    puts "created note ##{note.id} '#{note.title}'#{concept ? " in concept '#{concept.title}'" : ''} -> /design/notes/#{note.id}"
  end
end

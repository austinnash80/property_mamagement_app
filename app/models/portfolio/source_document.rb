# A raw document harvested from an outside source (Gmail attachment, Home Depot
# order, iCloud folder...) waiting to be triaged: keep / discard / assign to a
# project. Kept separate from Expense/Document/Photo so the originals survive
# whatever we decide later.
class Portfolio::SourceDocument < ApplicationRecord
  STATUSES = %w[unreviewed keep discard].freeze
  KINDS    = %w[invoice receipt estimate permit plans photo contract other].freeze
  SOURCES  = %w[gmail homedepot icloud manual].freeze

  belongs_to :project,   class_name: "Portfolio::Project",  optional: true
  belongs_to :work_item, class_name: "Portfolio::WorkItem", optional: true
  has_many_attached :files

  validates :source, inclusion: { in: SOURCES }
  validates :status, inclusion: { in: STATUSES }
  validates :kind,   inclusion: { in: KINDS }

  scope :unreviewed, -> { where(status: "unreviewed") }
  scope :kept,       -> { where(status: "keep") }
  scope :by_date,    -> { order(Arel.sql("occurred_on DESC NULLS LAST"), id: :desc) }

  def flag_list
    flags.to_s.split
  end

  def line_items
    Array(metadata["line_items"])
  end

  def year
    occurred_on&.year
  end

  def image_files
    files.select { |f| f.blob.image? }
  end

  def document_files
    files.reject { |f| f.blob.image? }
  end

  # Turn this source document into a first-class project record. Returns the
  # created record. The source document stays and is marked kept + linked.
  def promote!(as:)
    raise "assign a project first" unless project
    rec = case as.to_s
          when "expense"
            e = project.expenses.create!(purchased_on: occurred_on, amount: amount, description: title.to_s.truncate(200),
                                         source: vendor, category: "materials", work_item: work_item,
                                         notes: "Imported from #{source} #{source_ref}")
            document_files.each { |f| e.receipts.attach(f.blob) }
            image_files.each   { |f| e.receipts.attach(f.blob) } if document_files.empty?
            e
          when "document"
            d = project.documents.new(kind: (%w[permit plans contract].include?(kind) ? kind.sub("plans", "plan") : "other"),
                                      title: title.to_s.truncate(200), issued_on: occurred_on, notes: "Imported from #{source} #{source_ref}")
            first = document_files.first || files.first
            d.file.attach(first.blob) if first
            d.save!
            d
          when "photos"
            image_files.map do |f|
              p = project.photos.new(stage: "during", caption: title.to_s.truncate(200), taken_on: occurred_on, work_item: work_item)
              p.image.attach(f.blob)
              p.save!
              p
            end
          else
            raise ArgumentError, "unknown promotion #{as}"
          end
    update!(status: "keep", metadata: metadata.merge("promoted_as" => as.to_s, "promoted_at" => Time.zone.now.iso8601))
    rec
  end
end

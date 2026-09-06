class Portfolio::Project < ApplicationRecord
  belongs_to :property, class_name: "Portfolio::Property"
  has_many :work_items, -> { order(:position, :started_on, :id) }, class_name: "Portfolio::WorkItem", dependent: :destroy
  has_many :expenses,   -> { order(:purchased_on, :id) },          class_name: "Portfolio::Expense",  dependent: :destroy
  has_many :photos,     -> { order(:position, :taken_on, :id) },   class_name: "Portfolio::Photo",    dependent: :destroy
  has_many :documents,  -> { order(:issued_on, :id) },             class_name: "Portfolio::Document", dependent: :destroy
  has_many :source_documents, class_name: "Portfolio::SourceDocument", dependent: :nullify

  validates :title, presence: true
  validates :status, inclusion: { in: Portfolio::PROJECT_STATUSES }

  scope :by_date, -> { order(Arel.sql("started_on DESC NULLS LAST"), id: :desc) }

  def total_cost
    expenses.sum(:amount)
  end

  def vendors
    Portfolio::Vendor.where(id: work_items.select(:vendor_id)).or(
      Portfolio::Vendor.where(id: expenses.select(:vendor_id))
    ).distinct.order(:name)
  end

  def trades
    work_items.map(&:trade).compact.uniq
  end

  def date_range
    [started_on, completed_on].compact.map { |d| d.strftime("%b %Y") }.uniq.join(" – ")
  end
end

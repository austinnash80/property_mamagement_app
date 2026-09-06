class Portfolio::WorkItem < ApplicationRecord
  belongs_to :project, class_name: "Portfolio::Project"
  belongs_to :vendor,  class_name: "Portfolio::Vendor", optional: true
  has_many :expenses, class_name: "Portfolio::Expense", dependent: :nullify
  has_many :photos,   class_name: "Portfolio::Photo",   dependent: :nullify
  has_many :source_documents, class_name: "Portfolio::SourceDocument", dependent: :nullify

  validates :title, presence: true
  validates :performed_by, inclusion: { in: Portfolio::PERFORMED_BY.keys }

  def performed_by_label
    Portfolio::PERFORMED_BY[performed_by] || performed_by
  end
end

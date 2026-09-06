class Portfolio::Expense < ApplicationRecord
  belongs_to :project,   class_name: "Portfolio::Project"
  belongs_to :work_item, class_name: "Portfolio::WorkItem", optional: true
  belongs_to :vendor,    class_name: "Portfolio::Vendor",   optional: true
  has_many_attached :receipts

  validates :amount, numericality: true, allow_nil: true
  validates :category, inclusion: { in: Portfolio::EXPENSE_CATEGORIES }
end

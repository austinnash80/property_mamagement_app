class Portfolio::Vendor < ApplicationRecord
  has_many :work_items, class_name: "Portfolio::WorkItem", dependent: :nullify
  has_many :expenses,   class_name: "Portfolio::Expense",  dependent: :nullify

  validates :name, presence: true

  scope :ordered, -> { order(:name) }

  def projects
    Portfolio::Project.where(id: work_items.select(:project_id)).or(
      Portfolio::Project.where(id: expenses.select(:project_id))
    ).distinct
  end

  def total_paid
    expenses.sum(:amount)
  end
end

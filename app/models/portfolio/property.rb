class Portfolio::Property < ApplicationRecord
  has_many :projects, class_name: "Portfolio::Project", dependent: :destroy
  has_one_attached :cover_photo

  validates :name, presence: true

  scope :ordered, -> { order(:position, :name) }

  def label
    address.present? ? "#{name} — #{address}" : name
  end

  def total_cost
    Portfolio::Expense.joins(:project).where(portfolio_projects: { property_id: id }).sum(:amount)
  end
end

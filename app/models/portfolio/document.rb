class Portfolio::Document < ApplicationRecord
  belongs_to :project, class_name: "Portfolio::Project"
  has_one_attached :file

  validates :title, presence: true
  validates :kind, inclusion: { in: Portfolio::DOCUMENT_KINDS }
end

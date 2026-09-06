class CreatePortfolioSourceDocuments < ActiveRecord::Migration[6.1]
  def change
    create_table :portfolio_source_documents do |t|
      t.string  :source, null: false            # gmail, homedepot, icloud, manual
      t.string  :source_ref                      # gmail thread id, HD order number...
      t.date    :occurred_on
      t.string  :vendor
      t.string  :title
      t.text    :description
      t.string  :property_guess
      t.string  :suggested_group
      t.decimal :amount, precision: 12, scale: 2
      t.string  :kind, default: "other"          # invoice, receipt, estimate, permit, plans, photo, other
      t.string  :flags                           # space-separated: CABINET FLOORING ...
      t.string  :status, default: "unreviewed"   # unreviewed, keep, discard
      t.references :project,   foreign_key: { to_table: :portfolio_projects }
      t.references :work_item, foreign_key: { to_table: :portfolio_work_items }
      t.jsonb   :metadata, default: {}
      t.text    :notes
      t.timestamps
    end
    add_index :portfolio_source_documents, :status
    add_index :portfolio_source_documents, :source
    add_index :portfolio_source_documents, :occurred_on
    add_index :portfolio_source_documents, [:source, :source_ref], unique: true
  end
end

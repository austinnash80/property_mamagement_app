class CreatePortfolioTables < ActiveRecord::Migration[6.1]
  def change
    create_table :portfolio_properties do |t|
      t.string  :name, null: false
      t.string  :address
      t.string  :property_type
      t.date    :acquired_on
      t.date    :sold_on
      t.string  :status, default: "owned"
      t.text    :notes
      t.integer :position, default: 0
      t.timestamps
    end

    create_table :portfolio_vendors do |t|
      t.string :name, null: false
      t.string :trade
      t.string :contact_name
      t.string :phone
      t.string :email
      t.string :website
      t.string :license_number
      t.text   :notes
      t.timestamps
    end

    create_table :portfolio_projects do |t|
      t.references :property, null: false, foreign_key: { to_table: :portfolio_properties }
      t.string  :title, null: false
      t.string  :summary
      t.text    :description
      t.date    :started_on
      t.date    :completed_on
      t.string  :status, default: "completed"
      t.string  :permit_number
      t.text    :permit_notes
      t.text    :notes
      t.integer :position, default: 0
      t.timestamps
    end

    create_table :portfolio_work_items do |t|
      t.references :project, null: false, foreign_key: { to_table: :portfolio_projects }
      t.references :vendor, foreign_key: { to_table: :portfolio_vendors }
      t.string  :title, null: false
      t.string  :trade
      t.text    :description
      t.string  :performed_by, default: "self"
      t.date    :started_on
      t.date    :completed_on
      t.decimal :hours, precision: 8, scale: 1
      t.text    :notes
      t.integer :position, default: 0
      t.timestamps
    end

    create_table :portfolio_expenses do |t|
      t.references :project, null: false, foreign_key: { to_table: :portfolio_projects }
      t.references :work_item, foreign_key: { to_table: :portfolio_work_items }
      t.references :vendor, foreign_key: { to_table: :portfolio_vendors }
      t.date    :purchased_on
      t.decimal :amount, precision: 12, scale: 2
      t.string  :description
      t.string  :category, default: "materials"
      t.string  :source
      t.string  :invoice_number
      t.text    :notes
      t.timestamps
    end

    create_table :portfolio_photos do |t|
      t.references :project, null: false, foreign_key: { to_table: :portfolio_projects }
      t.references :work_item, foreign_key: { to_table: :portfolio_work_items }
      t.string  :stage, default: "after"
      t.string  :caption
      t.date    :taken_on
      t.integer :position, default: 0
      t.timestamps
    end

    create_table :portfolio_documents do |t|
      t.references :project, null: false, foreign_key: { to_table: :portfolio_projects }
      t.string :kind, default: "other"
      t.string :title, null: false
      t.date   :issued_on
      t.text   :notes
      t.timestamps
    end

    add_index :portfolio_projects, :started_on
    add_index :portfolio_expenses, :purchased_on
    add_index :portfolio_photos, :taken_on
  end
end

class CreateDesignTables < ActiveRecord::Migration[6.1]
  def change
    # A concept is one design idea: a floor plan, a kitchen, an ADU, a whole
    # house. Notes and images may belong to a concept; floor plans and
    # renderings will hang off it in later phases.
    create_table :design_concepts do |t|
      t.string  :title, null: false
      t.string  :kind, default: "other"          # whole_home, floor_plan, kitchen...
      t.string  :status, default: "idea"         # idea, in_progress, complete
      t.string  :location                        # which property / site, free text
      t.string  :summary
      t.text    :description
      t.integer :position, default: 0
      t.timestamps
    end

    create_table :design_notes do |t|
      t.references :concept, foreign_key: { to_table: :design_concepts }
      t.string  :title
      t.text    :body, null: false
      t.string  :tags                            # comma separated
      t.boolean :pinned, default: false, null: false
      t.timestamps
    end

    # Image library: inspiration photos, sketches, reference plans. The file
    # itself is an Active Storage attachment named :file.
    create_table :design_images do |t|
      t.references :concept, foreign_key: { to_table: :design_concepts }
      t.string  :title
      t.text    :caption
      t.string  :category, default: "inspiration"
      t.string  :tags
      t.string  :source                          # URL, book, "my sketch"...
      t.integer :position, default: 0
      t.timestamps
    end

    add_index :design_concepts, :position
    add_index :design_notes,  :pinned
    add_index :design_images, :category
  end
end

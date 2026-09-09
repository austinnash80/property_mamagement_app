class CreateDesignFloorPlans < ActiveRecord::Migration[6.1]
  def change
    # One drawing per level of a concept ("Main floor", "Second floor"). The
    # geometry lives in :data as JSON (walls, rooms, openings, labels; feet).
    create_table :design_floor_plans do |t|
      t.references :concept, null: false, foreign_key: { to_table: :design_concepts }
      t.string  :name, null: false
      t.string  :level                                   # "Level 1", "Basement"...
      t.decimal :width_ft, precision: 7, scale: 2, default: 60, null: false   # drawing area
      t.decimal :depth_ft, precision: 7, scale: 2, default: 40, null: false
      t.jsonb   :data, null: false, default: {}
      t.text    :notes
      t.integer :position, default: 0
      t.timestamps
    end
    add_index :design_floor_plans, :position
  end
end

class AddRenderSettingsToDesignConcepts < ActiveRecord::Migration[6.1]
  def change
    # 3D view choices (roof style, exterior, roof color, floor) shared by every level of the concept.
    add_column :design_concepts, :render_settings, :jsonb, null: false, default: {}
  end
end

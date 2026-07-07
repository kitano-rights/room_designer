class CreateFurnitures < ActiveRecord::Migration[8.1]
  def change
    create_table :furnitures do |t|
      t.references :room, null: false, foreign_key: true
      t.string :kind, null: false
      t.float :pos_x, null: false, default: 0.0
      t.float :pos_y, null: false, default: 0.0
      t.float :rotation, null: false, default: 0.0

      t.timestamps
    end
  end
end

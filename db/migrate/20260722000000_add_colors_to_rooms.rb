class AddColorsToRooms < ActiveRecord::Migration[8.1]
  def change
    add_column :rooms, :wall_color, :string, default: "#ffffff", null: false
    add_column :rooms, :floor_color, :string, default: "#ffffff", null: false
  end
end

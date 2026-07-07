class CreateRooms < ActiveRecord::Migration[8.1]
  def change
    create_table :rooms do |t|
      t.string :name, null: false, default: "無題の部屋"
      t.json :corners, null: false, default: []

      t.timestamps
    end
  end
end

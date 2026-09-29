class CreateEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :events do |t|
      t.string :external_id, null: false
      t.string :title, null: false
      t.text :description
      t.datetime :starts_at, null: false
      t.datetime :ends_at
      t.string :url
      t.string :image_url
      t.string :location_name
      t.string :city
      t.string :country_code
      t.jsonb :raw_payload, null: false, default: {}
      t.datetime :synced_at, null: false

      t.timestamps
    end

    add_index :events, :external_id, unique: true
    add_index :events, :starts_at
    add_check_constraint :events, "ends_at IS NULL OR ends_at >= starts_at", name: "events_ends_after_start"
  end
end

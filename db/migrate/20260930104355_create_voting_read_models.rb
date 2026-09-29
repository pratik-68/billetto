# Read models projected from the Voting domain events stored in Rails Event Store.
# They can be dropped and rebuilt at any time (`rake voting:rebuild_read_models`).
class CreateVotingReadModels < ActiveRecord::Migration[8.1]
  def change
    create_table :vote_tallies do |t|
      t.references :event, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
      t.integer :upvotes, null: false, default: 0
      t.integer :downvotes, null: false, default: 0

      t.timestamps
    end
    add_check_constraint :vote_tallies, "upvotes >= 0 AND downvotes >= 0", name: "vote_tallies_non_negative"

    create_table :event_votes do |t|
      t.references :event, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.string :user_id, null: false
      t.string :vote, null: false

      t.timestamps
    end
    add_index :event_votes, %i[event_id user_id], unique: true
    add_index :event_votes, :user_id
    add_check_constraint :event_votes, "vote IN ('up', 'down')", name: "event_votes_vote_direction"
  end
end

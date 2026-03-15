class CreateRaffleDraws < ActiveRecord::Migration[8.1]
  def change
    create_table :raffle_draws do |t|
      t.references :winner, null: false, foreign_key: { to_table: :entrants }
      t.integer :eligible_count, null: false
      t.string :draw_type, null: false, default: "winner"
      t.text :admin_note

      t.timestamps
    end
  end
end

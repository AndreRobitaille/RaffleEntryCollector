class CreateEntrants < ActiveRecord::Migration[8.1]
  def change
    create_table :entrants do |t|
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :email, null: false
      t.string :company, null: false
      t.string :job_title, null: false
      t.json :interest_areas, default: []
      t.boolean :eligibility_confirmed, null: false, default: false
      t.string :eligibility_status, null: false, default: "eligible"
      t.string :exclusion_reason

      t.timestamps
    end

    add_index :entrants, :email
    add_index :entrants, [ :first_name, :last_name, :company ]
    add_index :entrants, :eligibility_status
  end
end

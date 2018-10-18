class CreateParticipations < ActiveRecord::Migration
  def change
    create_table :participations do |t|
      t.integer :member_id
      t.integer :chat_id

      t.timestamps
    end
  end
end

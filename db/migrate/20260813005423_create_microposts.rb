class CreateMicroposts < ActiveRecord::Migration[7.1]
  def change
    create_table :microposts do |t|
      t.references :user, null: false, foreign_key: true, index: true
      t.text    :content,        null: false
      t.integer :comments_count, null: false, default: 0

      t.timestamps null: false
    end
    add_index :microposts, :created_at
  end
end

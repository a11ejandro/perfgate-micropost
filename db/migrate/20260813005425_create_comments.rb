class CreateComments < ActiveRecord::Migration[7.1]
  def change
    create_table :comments do |t|
      t.references :user,      null: false, foreign_key: true, index: true
      t.references :micropost, null: false, foreign_key: true, index: false
      t.text :content,         null: false

      t.timestamps null: false
    end
    add_index :comments, :created_at
    add_index :comments, %i[micropost_id created_at]
  end
end

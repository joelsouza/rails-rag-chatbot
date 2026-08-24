class CreateDocument < ActiveRecord::Migration[8.1]
  def change
    create_table :documents do |t|
      t.text :content
      t.text :source
      t.timestamps
    end
  end
end

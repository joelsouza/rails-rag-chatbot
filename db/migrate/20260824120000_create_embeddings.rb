class CreateEmbeddings < ActiveRecord::Migration[8.1]
  def change
    create_table :embeddings do |t|
      t.references :document, null: false, foreign_key: true
      t.text :content
      t.vector :embedding, limit: 3_072
      t.timestamps
    end
  end
end

class Document < ApplicationRecord
  has_many :embeddings, dependent: :destroy
end

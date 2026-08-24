class EmbedDocumentChunkJob < ApplicationJob
  queue_as :default

  retry_on GeminiEmbeddingService::Error,
    wait: :polynomially_longer,
    attempts: 5

  def perform(document_id, chunk)
    document = Document.find_by(id: document_id)
    return unless document

    vector = GeminiEmbeddingService.new.embed_document(chunk)

    Embedding.create!(
      document: document,
      content: chunk,
      embedding: vector
    )
  end
end

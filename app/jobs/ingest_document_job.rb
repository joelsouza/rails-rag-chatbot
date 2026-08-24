class IngestDocumentJob < ApplicationJob
  queue_as :default

  def perform(document_id)
    document = Document.find_by(id: document_id)
    return unless document

    TextChunker.call(document.content).each do |chunk|
      EmbedDocumentChunkJob.perform_later(document.id, chunk)
    end
  end
end

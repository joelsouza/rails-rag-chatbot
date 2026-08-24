require "test_helper"

class EmbedDocumentChunkJobTest < ActiveJob::TestCase
  class FakeGeminiEmbeddingService
    attr_reader :embed_document_calls

    def initialize
      @embed_document_calls = []
    end

    def embed_document(text)
      @embed_document_calls << text
      Array.new(3_072, 0.1)
    end
  end

  def with_stub_embedding_service
    original = GeminiEmbeddingService.method(:new)
    fake = FakeGeminiEmbeddingService.new
    GeminiEmbeddingService.define_singleton_method(:new) { fake }
    begin
      yield fake
    ensure
      GeminiEmbeddingService.define_singleton_method(:new, original)
    end
  end

  test "embeds the chunk and creates an embedding for the document" do
    document = Document.create!(content: "original text", source: "text input")
    vector = Array.new(3_072, 0.1)

    with_stub_embedding_service do |fake|
      assert_difference "document.embeddings.count", 1 do
        EmbedDocumentChunkJob.perform_now(document.id, "chunk text")
      end
      assert_equal [ "chunk text" ], fake.embed_document_calls
    end

    embedding = document.embeddings.last
    assert_equal "chunk text", embedding.content
    assert_equal vector, embedding.embedding
  end

  test "exits without calling Gemini or creating a row when the document is missing" do
    with_stub_embedding_service do |fake|
      assert_no_difference "Embedding.count" do
        EmbedDocumentChunkJob.perform_now(99_999, "chunk text")
      end
      assert_empty fake.embed_document_calls
    end
  end
end

require "test_helper"

class ChatServiceTest < ActiveSupport::TestCase
  def setup
    Embedding.delete_all
    Document.delete_all
  end

  class FakeGeminiEmbeddingService
    def embed_query(_text)
      Array.new(3_072, 0.2)
    end
  end

  class FakeGroqAnswerService
    attr_reader :context, :question

    def generate(context:, question:)
      @context = context
      @question = question
      "The answer is in the retrieved context."
    end
  end

  def with_stub_services
    original_embedding = GeminiEmbeddingService.method(:new)
    original_answer = GroqAnswerService.method(:new)
    fake_embedding = FakeGeminiEmbeddingService.new
    fake_answer = FakeGroqAnswerService.new
    GeminiEmbeddingService.define_singleton_method(:new) { fake_embedding }
    GroqAnswerService.define_singleton_method(:new) { fake_answer }
    begin
      yield fake_answer
    ensure
      GeminiEmbeddingService.define_singleton_method(:new, original_embedding)
      GroqAnswerService.define_singleton_method(:new, original_answer)
    end
  end

  def test_builds_context_and_returns_answer_and_sources_from_matching_embeddings
    document = Document.create!(content: "doc", source: "text input")
    document.embeddings.create!(content: "chunk one", embedding: Array.new(3_072, 0.1))
    document.embeddings.create!(content: "chunk two", embedding: Array.new(3_072, 0.1))

    with_stub_services do |fake_answer|
      result = ChatService.new.call("What is the answer?")

      assert_equal "chunk one\n\n---\n\nchunk two", fake_answer.context
      assert_equal "What is the answer?", fake_answer.question
      assert_equal "The answer is in the retrieved context.", result.answer

      assert_equal 2, result.sources.length
      assert_equal "chunk one", result.sources[0][:content]
      assert_equal "text input", result.sources[0][:source]
      assert_equal "chunk two", result.sources[1][:content]
      assert_equal "text input", result.sources[1][:source]
    end
  end

  def test_returns_no_relevant_documents_when_no_embeddings_match
    with_stub_services do |fake_answer|
      result = ChatService.new.call("What is the answer?")

      assert_equal "No relevant documents found.", result.answer
      assert_empty result.sources
      assert_nil fake_answer.context
      assert_nil fake_answer.question
    end
  end

  def test_rejects_a_blank_question
    with_stub_services do |_fake_answer|
      error = assert_raises(ArgumentError) do
        ChatService.new.call("   ")
      end

      assert_equal "Question must not be blank", error.message
    end
  end
end

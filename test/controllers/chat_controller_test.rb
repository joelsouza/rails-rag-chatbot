require "test_helper"

class ChatControllerTest < ActionDispatch::IntegrationTest
  class FakeChatService
    attr_reader :call_count, :last_question

    def initialize
      @call_count = 0
      @last_question = nil
    end

    def call(question)
      @call_count += 1
      @last_question = question
      ChatService::Result.new(answer: "The answer.", sources: [])
    end
  end

  def with_stub_chat_service
    original = ChatService.method(:new)
    fake = FakeChatService.new
    ChatService.define_singleton_method(:new) { fake }
    begin
      yield fake
    ensure
      ChatService.define_singleton_method(:new, original)
    end
  end

  test "GET /chat returns success" do
    get chat_path
    assert_response :success
  end

  test "POST /chat with a valid question calls the service and redirects with the answer as a notice" do
    with_stub_chat_service do |fake|
      post chat_path, params: { question: "What is the capital of France?" }

      assert_redirected_to chat_path
      assert_equal 1, fake.call_count
      assert_equal "What is the capital of France?", fake.last_question
      assert_equal "The answer.", flash[:notice]
    end
  end

  test "POST /chat with a blank question does not call the service and redirects with an alert" do
    with_stub_chat_service do |fake|
      post chat_path, params: { question: "   " }

      assert_redirected_to chat_path
      assert_equal 0, fake.call_count
      assert_equal "Ask a question to search the knowledge base.", flash[:alert]
    end
  end

  test "POST /chat when the service raises GeminiEmbeddingService::Error redirects with an alert" do
    original = ChatService.method(:new)
    ChatService.define_singleton_method(:new) do
      Object.new.tap do |fake|
        fake.define_singleton_method(:call) do |_question|
          raise GeminiEmbeddingService::Error, "boom"
        end
      end
    end

    begin
      post chat_path, params: { question: "What is the capital of France?" }

      assert_redirected_to chat_path
      assert_equal "The answer could not be generated. Please try again.", flash[:alert]
    ensure
      ChatService.define_singleton_method(:new, original)
    end
  end
end

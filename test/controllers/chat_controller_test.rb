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

  test "POST /chat with a valid question calls the service and renders the answer" do
    with_stub_chat_service do |fake|
      post chat_path, params: { question: "What is the capital of France?" }

      assert_response :success
      assert_equal 1, fake.call_count
      assert_equal "What is the capital of France?", fake.last_question
      assert_select ".message-answer .message__body", text: "The answer."
      assert_select ".message-question .message__body", text: "What is the capital of France?"
    end
  end

  test "POST /chat with a blank question does not call the service and shows an alert" do
    with_stub_chat_service do |fake|
      post chat_path, params: { question: "   " }

      assert_response :unprocessable_entity
      assert_equal 0, fake.call_count
      assert_equal "Ask a question to search the knowledge base.", flash[:alert]
    end
  end

  test "HTMX POST /chat with a blank question renders a safe error" do
    with_stub_chat_service do |fake|
      post chat_path,
        params: { question: "   " },
        headers: { "HX-Request" => "true" }

      assert_response :success
      assert_equal 0, fake.call_count
      assert_select ".message-question", count: 0
      assert_select ".message-error .message__body", text: "Ask a question to search the knowledge base.", count: 1
    end
  end

  test "POST /chat when the service raises GeminiEmbeddingService::Error shows an alert" do
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

      assert_response :success
      assert_equal "The answer could not be generated. Please try again.", flash[:alert]
      assert_select ".message-error .message__body", text: "The answer could not be generated. Please try again."
      assert_not_includes response.body, "boom"
    ensure
      ChatService.define_singleton_method(:new, original)
    end
  end

  test "HTMX POST /chat with a valid question renders only the new exchange" do
    with_stub_chat_service do |fake|
      post chat_path,
        params: { question: "What is the capital of France?" },
        headers: { "HX-Request" => "true" }

      assert_response :success
      assert_equal 1, fake.call_count
      assert_select ".message-question .message__body", text: "What is the capital of France?", count: 1
      assert_select ".message-answer .message__body", text: "The answer.", count: 1
      assert_select "header", count: 0
      assert_select "main", count: 0
      assert_select ".composer", count: 0
    end
  end

  test "HTMX POST /chat when the service raises GeminiEmbeddingService::Error renders a safe error" do
    original = ChatService.method(:new)
    ChatService.define_singleton_method(:new) do
      Object.new.tap do |fake|
        fake.define_singleton_method(:call) do |_question|
          raise GeminiEmbeddingService::Error, "provider details"
        end
      end
    end

    begin
      post chat_path,
        params: { question: "What is the capital of France?" },
        headers: { "HX-Request" => "true" }

      assert_response :success
      assert_select ".message-question .message__body", text: "What is the capital of France?", count: 1
      assert_select ".message-error .message__body", text: "The answer could not be generated. Please try again.", count: 1
      assert_not_includes response.body, "provider details"
    ensure
      ChatService.define_singleton_method(:new, original)
    end
  end
end

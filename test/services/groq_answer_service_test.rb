require "minitest/autorun"
require "json"
require "net/http"
require_relative "../../app/services/groq_answer_service"

class GroqAnswerServiceTest < Minitest::Test
  def test_generates_an_answer_from_the_supplied_context_and_question
    response = http_response(
      Net::HTTPOK.new("1.1", "200", "OK"),
      {
        choices: [
          { message: { content: "The answer is in the retrieved context." } }
        ]
      }
    )
    request = nil
    connection = Object.new
    connection.define_singleton_method(:request) do |value|
      request = value
      response
    end

    service = GroqAnswerService.new(api_key: "test-key")
    service.define_singleton_method(:connection) { connection }
    answer = service.generate(
      context: "Retrieved information",
      question: "What is the answer?"
    )

    body = JSON.parse(request.body)

    assert_equal "The answer is in the retrieved context.", answer
    assert_equal "Bearer test-key", request["Authorization"]
    assert_equal "application/json", request["Content-Type"]
    assert_equal GroqAnswerService::MODEL, body.fetch("model")
    assert_equal 0, body.fetch("temperature")
    assert_includes body.dig("messages", 1, "content"), "Retrieved information"
    assert_includes body.dig("messages", 1, "content"), "What is the answer?"
  end

  def test_raises_a_provider_error_for_an_unsuccessful_response
    response = http_response(
      Net::HTTPTooManyRequests.new("1.1", "429", "Too Many Requests"),
      { error: { message: "Rate limit reached" } }
    )
    connection = Object.new
    connection.define_singleton_method(:request) { |_request| response }
    service = GroqAnswerService.new(api_key: "test-key")
    service.define_singleton_method(:connection) { connection }

    error = assert_raises(GroqAnswerService::Error) do
      service.generate(context: "Context", question: "Question")
    end

    assert_equal "Groq answer request failed (HTTP 429): Rate limit reached", error.message
  end

  def test_rejects_a_successful_response_without_answer_content
    response = http_response(Net::HTTPOK.new("1.1", "200", "OK"), { choices: [] })
    connection = Object.new
    connection.define_singleton_method(:request) { |_request| response }
    service = GroqAnswerService.new(api_key: "test-key")
    service.define_singleton_method(:connection) { connection }

    error = assert_raises(GroqAnswerService::Error) do
      service.generate(context: "Context", question: "Question")
    end

    assert_equal "Groq returned a response without an answer", error.message
  end

  private

  def http_response(response, body)
    response.tap do
      response.instance_variable_set(:@body, JSON.generate(body))
      response.instance_variable_set(:@read, true)
    end
  end
end

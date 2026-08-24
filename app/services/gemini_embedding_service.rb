require "json"
require "net/http"
require "uri"

class GeminiEmbeddingService
  class Error < StandardError; end

  MODEL = "models/gemini-embedding-2"
  DIMENSIONS = 3_072
  ENDPOINT = URI(
    "https://generativelanguage.googleapis.com/v1beta/#{MODEL}:embedContent"
  )

  def initialize(api_key: ENV.fetch("GEMINI_API_KEY"))
    @api_key = api_key
  end

  def embed_document(text)
    embed(text, task_type: "RETRIEVAL_DOCUMENT")
  end

  def embed_query(text)
    embed(text, task_type: "RETRIEVAL_QUERY")
  end

  private

  def embed(text, task_type:)
    raise ArgumentError, "Embedding text must not be blank" if text.blank?

    request = Net::HTTP::Post.new(ENDPOINT)
    request["Content-Type"] = "application/json"
    request["x-goog-api-key"] = @api_key
    request.body = {
      model: MODEL,
      content: {
        parts: [{ text: text }]
      },
      embedContentConfig: {
        taskType: task_type,
        outputDimensionality: DIMENSIONS
      }
    }.to_json

    response = connection.request(request)
    payload = JSON.parse(response.body)

    unless response.is_a?(Net::HTTPSuccess)
      provider_message = payload.dig("error", "message")
      raise Error,
        "Gemini embedding request failed (HTTP #{response.code}): " \
        "#{provider_message || "No error details were returned"}"
    end

    values = payload.dig("embedding", "values")

    unless valid_embedding?(values)
      raise Error,
        "Gemini returned an invalid embedding; expected #{DIMENSIONS} numeric values"
    end

    values
  rescue JSON::ParserError => error
    raise Error, "Gemini returned an invalid JSON response", cause: error
  rescue Net::OpenTimeout, Net::ReadTimeout, SocketError => error
    raise Error, "Gemini embedding request could not reach the API", cause: error
  end

  def connection
    Net::HTTP.new(ENDPOINT.host, ENDPOINT.port).tap do |http|
      http.use_ssl = true
      http.open_timeout = 5
      http.read_timeout = 30
    end
  end

  def valid_embedding?(values)
    values.is_a?(Array) &&
      values.length == DIMENSIONS &&
      values.all?(Numeric)
  end
end

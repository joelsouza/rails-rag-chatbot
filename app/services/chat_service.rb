class ChatService
  class NoRelevantDocuments < StandardError; end

  Result = Struct.new(:answer, :sources, keyword_init: true)

  TOP_K = 5

  def initialize(
    embedding_service: GeminiEmbeddingService.new,
    answer_service: GroqAnswerService.new
  )
    @embedding_service = embedding_service
    @answer_service = answer_service
  end

  def call(question)
    raise ArgumentError, "Question must not be blank" if question.blank?

    question_embedding = @embedding_service.embed_query(question)

    embeddings = Embedding
      .nearest_neighbors(:embedding, question_embedding, distance: "cosine")
      .limit(TOP_K)

    if embeddings.empty?
      return Result.new(answer: "No relevant documents found.", sources: [])
    end

    context = embeddings.map(&:content).join("\n\n---\n\n")
    answer = @answer_service.generate(context: context, question: question)

    sources = embeddings.map do |embedding|
      { content: embedding.content, source: embedding.document&.source }
    end

    Result.new(answer: answer, sources: sources)
  end
end

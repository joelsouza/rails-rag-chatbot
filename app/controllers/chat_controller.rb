class ChatController < ApplicationController
  def index
  end

  def create
    @question = params[:question]

    if @question.blank?
      @error = "Ask a question to search the knowledge base."
      flash[:alert] = @error unless htmx_request?
      return render_chat_response(status: :unprocessable_entity)
    end

    @answer = ChatService.new.call(@question).answer
    render_chat_response
  rescue GeminiEmbeddingService::Error, GroqAnswerService::Error => error
    Rails.logger.error(
      "Chat answer generation failed: #{error.class}: #{error.message}"
    )
    @error = "The answer could not be generated. Please try again."
    flash[:alert] = @error unless htmx_request?
    render_chat_response
  end

  private

  def htmx_request?
    request.headers["HX-Request"] == "true"
  end

  def render_chat_response(status: :ok)
    if htmx_request?
      render partial: "chat/exchange", locals: { question: @question, answer: @answer, error: @error }, layout: false
    else
      render :index, status: status
    end
  end
end

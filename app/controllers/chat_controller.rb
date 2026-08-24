class ChatController < ApplicationController
  def index
  end

  def create
    question = params[:question]

    if question.blank?
      flash[:alert] = "Ask a question to search the knowledge base."
      return redirect_to chat_path
    end

    result = ChatService.new.call(question)

    flash[:notice] = result.answer
    redirect_to chat_path
  rescue GeminiEmbeddingService::Error, GroqAnswerService::Error => error
    flash[:alert] = "The answer could not be generated. Please try again."
    redirect_to chat_path
  end
end

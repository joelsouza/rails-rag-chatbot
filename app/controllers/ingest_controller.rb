class IngestController < ApplicationController
  def create
    if params[:text].blank?
      flash[:alert] = "Paste some text to add to the knowledge base."
      return redirect_to root_path
    end

    document = Document.create!(content: params[:text], source: "text input")
    IngestDocumentJob.perform_later(document.id)

    flash[:notice] = "Your text has been queued for indexing."
    redirect_to root_path
  end
end

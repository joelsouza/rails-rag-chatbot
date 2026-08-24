require "test_helper"

class IngestControllerTest < ActionDispatch::IntegrationTest
  test "valid text creates a document and enqueues the ingest job" do
    assert_difference "Document.count", 1 do
      assert_enqueued_with(job: IngestDocumentJob) do
        post ingest_path, params: { text: "Hello world" }
      end
    end

    document = Document.last
    assert_equal "Hello world", document.content
    assert_equal "text input", document.source
    assert_redirected_to root_path
    assert_equal "Your text has been queued for indexing.", flash[:notice]
  end

  test "blank text does not create a document or enqueue a job" do
    assert_no_difference "Document.count" do
      assert_no_enqueued_jobs do
        post ingest_path, params: { text: "" }
      end
    end

    assert_redirected_to root_path
    assert_equal "Paste some text to add to the knowledge base.", flash[:alert]
  end
end

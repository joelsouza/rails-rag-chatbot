require "test_helper"

class IngestDocumentJobTest < ActiveJob::TestCase
  test "chunks the document content and enqueues one child job per chunk" do
    document = Document.create!(content: "a" * 8_500, source: "text input")
    chunks = TextChunker.call(document.content)

    assert_enqueued_jobs(chunks.length, only: EmbedDocumentChunkJob) do
      IngestDocumentJob.perform_now(document.id)
    end

    enqueued = enqueued_jobs.select { |job| job["job_class"] == "EmbedDocumentChunkJob" }
    assert_equal chunks.length, enqueued.length

    enqueued.each_with_index do |job, index|
      assert_equal document.id, job["arguments"][0]
      assert_equal chunks[index], job["arguments"][1]
    end
  end

  test "exits without enqueuing child jobs when the document is missing" do
    assert_no_enqueued_jobs do
      IngestDocumentJob.perform_now(99_999)
    end
  end
end

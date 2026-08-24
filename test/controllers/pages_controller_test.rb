require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get pages_index_url
    assert_response :success
  end

  test "index renders the document upload form" do
    get pages_index_url
    assert_response :success

    assert_select "h1", text: "RAG Chatbot"
    assert_select "main.container article"
    assert_select "form[action='/ingest'][method='post'][enctype='multipart/form-data']"
    assert_select "label[for='ingest_file']", text: "Document file"
    assert_select "input[type='file'][name='file'][required]"
    assert_select "small#ingest_file_help", text: "Accepted formats: .txt, .md, and .markdown."
  end
end

require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get pages_index_url
    assert_response :success
  end

  test "index renders the document text form" do
    get pages_index_url
    assert_response :success

    assert_select "h1", text: "RAG Chatbot"
    assert_select "main.container article"
    assert_select "form[action='/ingest'][method='post']"
    assert_select "form[enctype='multipart/form-data']", count: 0
    assert_select "label[for='ingest_text']", text: "Document text"
    assert_select "textarea[name='text'][required]"
    assert_select "input[type='file']", count: 0
    assert_select "small#ingest_text_help", text: "The text is split into chunks and indexed for search."
  end
end

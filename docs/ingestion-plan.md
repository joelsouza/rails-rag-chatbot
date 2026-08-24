# Text Ingestion With Chunked Embeddings

## Status

Approved for implementation.

## Goal

Replace file upload with a textarea for the full document text. Store the original text as one `Document`. Split the text into chunks and create one related `Embedding` record for each chunk.

Embedding work must run asynchronously. Each chunk must use a separate job so one failed API request does not require the other chunks to run again.

## Decisions

- Accept pasted text instead of uploaded files.
- Store the original text in the `documents` table.
- Store each chunk and its vector in the related `embeddings` table.
- Set `Document#source` to `"text input"`.
- Use `IngestDocumentJob` to split a document and enqueue chunk jobs.
- Use one `EmbedDocumentChunkJob` for each chunk.
- Use `GeminiEmbeddingService#embed_document` to create each vector.
- Rewrite the initial migrations because the application is not deployed.
- Drop and recreate the development and test databases after rewriting the migrations.
- Show success and validation feedback through Rails flash messages.

## Request Flow

1. The user pastes the full document text into `pages#index`.
2. The form sends `POST /ingest` with a `text` parameter.
3. `IngestController#create` validates the text.
4. The controller creates a `Document` with the original text and source `"text input"`.
5. The controller enqueues `IngestDocumentJob` with the document ID.
6. `IngestDocumentJob` loads the document and calls `TextChunker`.
7. The job enqueues one `EmbedDocumentChunkJob` for each chunk.
8. Each chunk job calls `GeminiEmbeddingService#embed_document`.
9. Each chunk job creates an `Embedding` that belongs to the original document.

## Database Schema

### Documents

The `documents` table stores the original text.

| Column | Type | Purpose |
| --- | --- | --- |
| `id` | bigint | Primary key |
| `content` | text | Original pasted text |
| `source` | text | Input source, set to `"text input"` |
| `created_at` | datetime | Creation time |
| `updated_at` | datetime | Last update time |

The table does not contain an embedding vector.

### Embeddings

The `embeddings` table stores one text chunk and vector per row.

| Column | Type | Purpose |
| --- | --- | --- |
| `id` | bigint | Primary key |
| `document_id` | bigint | Required foreign key to `documents` |
| `content` | text | Text chunk used to create the vector |
| `embedding` | vector(3072) | Gemini embedding vector |
| `created_at` | datetime | Creation time |
| `updated_at` | datetime | Last update time |

## Migration Changes

### Existing document migration

Edit `db/migrate/20260822144121_create_document.rb` and remove the `embedding` column. Keep `content`, `source`, and timestamps.

### New embedding migration

Add a migration that creates the `embeddings` table with:

```ruby
t.references :document, null: false, foreign_key: true
t.text :content
t.vector :embedding, limit: 3_072
t.timestamps
```

Keep `db/migrate/20260822143213_install_neighbor_vector.rb` unchanged.

After the migration files change, recreate the local databases and regenerate `db/schema.rb`:

```sh
bin/rails db:drop db:create db:migrate
RAILS_ENV=test bin/rails db:drop db:create db:migrate
```

These commands delete all data in the local development and test databases.

## Models

### Document

```ruby
class Document < ApplicationRecord
  has_many :embeddings, dependent: :destroy
end
```

### Embedding

```ruby
class Embedding < ApplicationRecord
  belongs_to :document
  has_neighbors :embedding
end
```

`has_neighbors` belongs on `Embedding` because that model owns the vector column and performs similarity searches.

## User Interface

Update `app/views/pages/index.html.erb`:

- Replace the file input with a required textarea named `text`.
- Remove `multipart: true` from the form.
- Use the visible label `Document text`.
- Explain that the text is split into chunks and indexed.
- Change the submit button to `Add document`.
- Preserve the existing Pico CSS layout, Rails CSRF protection, label association, and helper-text association.

## Controller

Update `IngestController#create` to:

1. Reject blank text.
2. Create the `Document` synchronously.
3. Enqueue `IngestDocumentJob` with the document ID.
4. Redirect to the root page with a notice.

Expected behavior:

```ruby
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
```

## Jobs

### IngestDocumentJob

This job splits the original document and fans out the embedding work.

```ruby
class IngestDocumentJob < ApplicationJob
  queue_as :default

  def perform(document_id)
    document = Document.find_by(id: document_id)
    return unless document

    TextChunker.call(document.content).each do |chunk|
      EmbedDocumentChunkJob.perform_later(document.id, chunk)
    end
  end
end
```

### EmbedDocumentChunkJob

This job owns one Gemini request and one `Embedding` record.

```ruby
class EmbedDocumentChunkJob < ApplicationJob
  queue_as :default

  retry_on GeminiEmbeddingService::Error,
    wait: :polynomially_longer,
    attempts: 5

  def perform(document_id, chunk)
    document = Document.find_by(id: document_id)
    return unless document

    vector = GeminiEmbeddingService.new.embed_document(chunk)

    Embedding.create!(
      document: document,
      content: chunk,
      embedding: vector
    )
  end
end
```

The per-chunk job boundary gives each Gemini request an independent retry policy. A failed chunk does not re-embed successful chunks.

## Flash Messages

Update `app/views/layouts/application.html.erb` to render `notice` and `alert` messages before the page content. Use semantic, Pico-compatible markup and do not rely on color alone to communicate message meaning.

## Tests

### Page test

Update `test/controllers/pages_controller_test.rb` to verify:

- The form posts to `/ingest`.
- The form contains a required `textarea[name="text"]`.
- The file input and multipart encoding are gone.
- The helper text describes chunking and indexing.

### Controller tests

Update `test/controllers/ingest_controller_test.rb` to verify:

- Valid text creates one `Document`.
- Valid text enqueues one `IngestDocumentJob` with the document ID.
- The response redirects to the root page with a notice.
- Blank text does not create a document or enqueue a job.
- Blank text redirects with an alert.

### Fan-out job tests

Update `test/jobs/ingest_document_job_test.rb` to verify:

- The job chunks the document content.
- The job enqueues one `EmbedDocumentChunkJob` for each chunk.
- Every child job receives the correct document ID and chunk text.
- A missing document exits without enqueuing child jobs.

### Chunk embedding job tests

Add `test/jobs/embed_document_chunk_job_test.rb` to verify:

- The job calls `GeminiEmbeddingService#embed_document` with the chunk.
- The job creates an `Embedding` related to the correct document.
- The embedding row contains the chunk text and vector.
- A missing document exits without calling Gemini or creating a row.

## Verification

1. Recreate the development and test databases.
2. Run the changed controller, job, model, and service tests.
3. Run the full test suite.
4. Run RuboCop on all changed Ruby files.
5. Run `bin/rails zeitwerk:check`.
6. Open the root page in a browser at desktop and mobile widths.
7. Submit valid text and confirm the notice appears.
8. Submit blank text and confirm the validation alert appears.
9. Confirm the browser console has no errors.

## Out of Scope

- PDF extraction.
- Chat response generation.
- Similarity retrieval and prompt construction.
- Progress reporting for individual chunk jobs.

# RAG Chatbot (POC)

Rails RAG proof of concept. Paste text, index it, ask questions.

## Stack

- Rails 8, Postgres + pgvector, neighbor gem
- Gemini embeddings (3072-dim)
- Groq (Llama 3.1) answers
- ActiveJob (async chunk embedding)

## Setup

```sh
cp .env.example .env   # add real API keys
bin/rails db:create db:migrate
bin/rails server
```

## Flow

1. **Ingest** — paste text at `/`. Stored as `Document`, split into chunks, each embedded async into `Embedding`.
2. **Chat** — ask at `/chat`. Question embedded, top 5 chunks retrieved by cosine similarity, sent to Groq with context.

## Tests

```sh
bin/rails test
```

## Notes

- Chunk size 2000 chars, overlap 300.
- Requires valid `GEMINI_API_KEY` and `GROQ_API_KEY`.

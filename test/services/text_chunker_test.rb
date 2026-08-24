require "minitest/autorun"
require_relative "../../app/services/text_chunker"

class TextChunkerTest < Minitest::Test
  def test_splits_text_with_overlap
    chunks = TextChunker.call("abcdefghij", chunk_size: 4, overlap: 1)

    assert_equal %w[abcd defg ghij], chunks
  end

  def test_returns_empty_array_for_blank_text
    assert_empty TextChunker.call("   ")
  end

  def test_rejects_non_positive_chunk_size
    error = assert_raises(ArgumentError) do
      TextChunker.call("text", chunk_size: 0)
    end

    assert_equal "Chunk size must be a positive integer", error.message
  end

  def test_rejects_overlap_that_is_not_smaller_than_chunk_size
    error = assert_raises(ArgumentError) do
      TextChunker.call("text", chunk_size: 4, overlap: 4)
    end

    assert_equal "Overlap must be a non-negative integer smaller than chunk size", error.message
  end
end

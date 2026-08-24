class TextChunker
  DEFAULT_CHUNK_SIZE = 4_000
  DEFAULT_OVERLAP = 400

  def self.call(text, chunk_size: DEFAULT_CHUNK_SIZE, overlap: DEFAULT_OVERLAP)
    new(text, chunk_size:, overlap:).call
  end

  def initialize(text, chunk_size:, overlap:)
    raise ArgumentError, "Text must be a string" unless text.is_a?(String)
    unless chunk_size.is_a?(Integer) && chunk_size.positive?
      raise ArgumentError, "Chunk size must be a positive integer"
    end
    unless overlap.is_a?(Integer) && overlap >= 0 && overlap < chunk_size
      raise ArgumentError,
        "Overlap must be a non-negative integer smaller than chunk size"
    end

    @text = text
    @chunk_size = chunk_size
    @step = chunk_size - overlap
  end

  def call
    return [] if @text.strip.empty?

    chunks = []
    position = 0

    loop do
      chunks << @text.slice(position, @chunk_size)
      break if position + @chunk_size >= @text.length

      position += @step
    end

    chunks
  end
end

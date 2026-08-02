# frozen_string_literal: true

module NtiReceiptBuilder
  # The output of one render: presenters in paint order, whether the content overflows the
  # printable area, and how tall it actually is. Not cached — one per render, holding no
  # references after the response.
  class RenderResult
    attr_reader :elements, :content_height_mm

    def initialize(elements:, overflow:, content_height_mm:)
      @elements = elements
      @overflow = overflow
      @content_height_mm = content_height_mm
    end

    def overflow? = @overflow
  end
end

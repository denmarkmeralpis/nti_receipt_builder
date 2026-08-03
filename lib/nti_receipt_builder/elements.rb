# frozen_string_literal: true

module NtiReceiptBuilder
  # Canonical whitelist of layout-element shapes, style properties and size limits a
  # template's jsonb `layout` may contain. LayoutValidator is the only reader.
  #
  # Column keys are deliberately NOT here — they are declared by the host's variables class
  # on the collection variable, so the gem carries no domain vocabulary.
  #
  # MAX_ELEMENTS and the length caps are what bound the memory a single template can consume;
  # they are enforced before persistence, not by convention.
  module Elements
    TYPES = %w[variable text order_lines].freeze

    MAX_ELEMENTS = 60
    MIN_ELEMENT_DIMENSION_MM = 1.0

    Z_INDEX_MIN = 0
    Z_INDEX_MAX = 1000

    TEXT_ALIGNS = %w[left center right].freeze
    FONT_WEIGHTS = %w[normal bold].freeze

    STYLE_WHITELIST = {
      'font_size_pt' => { type: :numeric, min: 6, max: 72 },
      'font_weight' => { type: :enum, values: FONT_WEIGHTS },
      'text_align' => { type: :enum, values: TEXT_ALIGNS },
      'line_height' => { type: :numeric, min: 0.8, max: 3.0 }
    }.freeze

    TEXT_MAX_LENGTH = 500
    FALLBACK_MAX_LENGTH = 200
    PREFIX_MAX_LENGTH = 50
    SUFFIX_MAX_LENGTH = 50

    # There is deliberately no maximum: the host declares the column vocabulary, and
    # LayoutValidator rejects unknown and duplicated keys, so that vocabulary is already the
    # ceiling. A constant here would reject a host whose collection is simply wider than the
    # gem happened to anticipate.
    MIN_ORDER_LINE_COLUMNS = 1
    COLUMN_LABEL_MAX_LENGTH = 40

    ROW_SPACING_MIN_MM = 0.0
    ROW_SPACING_MAX_MM = 10.0
  end
end

# frozen_string_literal: true

module NtiReceiptBuilder
  # One receipt placeholder: where its value comes from, how it is labelled, how it is
  # formatted, and what stands in for it in the designer preview.
  #
  # Frozen on construction — these are read on every render and must never be mutated.
  class VariableDefinition
    DEFAULT_SAMPLE_ROW_COUNT = 3
    # Matches the builder's default order_lines element width, so freshly dropped tables fill it.
    DEFAULT_COLLECTION_WIDTH_MM = 60.0
    DEFAULT_COLUMN_ALIGN = 'left'

    attr_reader :key, :method_name, :label, :type, :columns

    def initialize(key:, method_name:, label:, type: nil, sample: nil, columns: nil)
      @key = -key.to_s
      @method_name = -method_name.to_s
      @label = -label.to_s
      @type = type
      @sample = sample
      @columns = columns
      freeze
    end

    # A variable that declares `columns:` IS the collection — there is no separate marker.
    def collection? = !@columns.nil?

    def column_keys = collection? ? @columns.keys : []

    def column_label(column_key)
      @columns&.dig(column_key, :label) || column_key.to_s.titleize
    end

    def column_type(column_key)
      @columns&.dig(column_key, :type)
    end

    # The column set the builder uses when a designer drops a fresh table onto the canvas.
    # Without this the builder would have to hardcode column keys, and any host whose columns
    # differ would get a layout its own validator rejects.
    def default_columns_config
      return [] unless collection?

      even_width_mm = (DEFAULT_COLLECTION_WIDTH_MM / column_keys.size).round(2)

      column_keys.map do |column_key|
        {
          'key' => column_key,
          'label' => column_label(column_key),
          'width_mm' => @columns.dig(column_key, :width_mm) || even_width_mm,
          'align' => @columns.dig(column_key, :align) || DEFAULT_COLUMN_ALIGN
        }
      end
    end

    # The declared sample, or a derived stand-in. Only ever called on the preview path, so
    # nothing is memoised — a frozen object cannot memoise, and previews are not hot.
    def sample
      declared = @sample.respond_to?(:call) ? @sample.call : @sample
      return declared unless declared.nil?

      collection? ? derived_collection_sample : label
    end

    private

    def derived_collection_sample
      Array.new(DEFAULT_SAMPLE_ROW_COUNT) do |index|
        column_keys.index_with { |column_key| "#{column_label(column_key)} #{index + 1}" }
      end
    end
  end
end

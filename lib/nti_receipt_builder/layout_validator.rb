# frozen_string_literal: true

module NtiReceiptBuilder
  # Structural + whitelist validation of a template's jsonb `layout`. This is the single
  # place that decides whether a submitted layout is safe to persist and render — it never
  # trusts client-side snap/clamp/whitelist checks, since those are UX conveniences only.
  #
  # Allowed variable keys and order-line column keys come from the host's variables class,
  # so this validator holds no domain vocabulary of its own.
  class LayoutValidator
    GEOMETRY_KEYS = %w[x_mm y_mm width_mm height_mm].freeze

    def initialize(layout:, paper_width_mm:, paper_height_mm:, margin_top_mm:, margin_right_mm:,
                   margin_bottom_mm:, margin_left_mm:, height_mode:,
                   variables_class: NtiReceiptBuilder.variables_class)
      @layout = layout
      @paper_width_mm = paper_width_mm
      @paper_height_mm = paper_height_mm
      @margin_top_mm = margin_top_mm
      @margin_right_mm = margin_right_mm
      @margin_bottom_mm = margin_bottom_mm
      @margin_left_mm = margin_left_mm
      @height_mode = height_mode
      @variables_class = variables_class
      @errors = []
    end

    def call
      unless @layout.is_a?(Array)
        @errors << 'must be an array of elements'
        return @errors
      end

      if @layout.size > Elements::MAX_ELEMENTS
        @errors << "may contain at most #{Elements::MAX_ELEMENTS} elements (has #{@layout.size})"
      end

      seen_ids = Set.new
      @layout.each_with_index { |element, index| validate_element(element, index, seen_ids) }

      @errors
    end

    private

    def validate_element(element, index, seen_ids)
      tag = "element ##{index + 1}"

      unless element.is_a?(Hash)
        @errors << "#{tag} must be an object"
        return
      end

      validate_id(element, tag, seen_ids)

      type = element['type']
      unless Elements::TYPES.include?(type)
        @errors << "#{tag} has an unknown type (#{type.inspect})"
        return
      end

      validate_geometry(element, tag)
      validate_z_index(element, tag)
      validate_visibility(element, tag)
      validate_styles(element, tag)

      case type
      when 'variable' then validate_variable(element, tag)
      when 'text' then validate_text(element, tag)
      when 'order_lines' then validate_order_lines(element, tag)
      end
    end

    def validate_id(element, tag, seen_ids)
      id = element['id']
      if !id.is_a?(String) || id.blank?
        @errors << "#{tag} is missing a valid id"
      elsif seen_ids.include?(id)
        @errors << "#{tag} has a duplicate id (#{id})"
      else
        seen_ids << id
      end
    end

    def validate_geometry(element, tag)
      return unless numeric_geometry?(element, tag)

      validate_position(element, tag)
      validate_dimensions(element, tag)
      validate_paper_bounds(element, tag)
    end

    # A single non-numeric coordinate stops geometry validation — the remaining checks would
    # all report on coerced zeros and bury the real problem.
    def numeric_geometry?(element, tag)
      offending = GEOMETRY_KEYS.find { |key| !element[key].is_a?(Numeric) }
      return true if offending.nil?

      @errors << "#{tag} has a non-numeric #{offending}"
      false
    end

    def validate_position(element, tag)
      return unless element['x_mm'].to_f.negative? || element['y_mm'].to_f.negative?

      @errors << "#{tag} has a negative position"
    end

    def validate_dimensions(element, tag)
      too_small = element['width_mm'].to_f < Elements::MIN_ELEMENT_DIMENSION_MM ||
                  element['height_mm'].to_f < Elements::MIN_ELEMENT_DIMENSION_MM
      return unless too_small

      @errors << "#{tag} is smaller than the minimum size of #{Elements::MIN_ELEMENT_DIMENSION_MM}mm"
    end

    def validate_paper_bounds(element, tag)
      x_mm = element['x_mm'].to_f
      y_mm = element['y_mm'].to_f

      @errors << "#{tag} extends beyond the paper width" if x_mm + element['width_mm'].to_f > @paper_width_mm

      return if @height_mode == 'content'

      @errors << "#{tag} extends beyond the paper height" if y_mm + element['height_mm'].to_f > @paper_height_mm
    end

    def validate_z_index(element, tag)
      return unless element.key?('z_index')

      value = element['z_index']
      return if value.is_a?(Integer) && value.between?(Elements::Z_INDEX_MIN, Elements::Z_INDEX_MAX)

      @errors << "#{tag} has an invalid z_index"
    end

    def validate_visibility(element, tag)
      return unless element.key?('visible')

      @errors << "#{tag} has an invalid visible flag" unless [true, false].include?(element['visible'])
    end

    def validate_styles(element, tag)
      styles = element['styles']
      return if styles.nil?

      unless styles.is_a?(Hash)
        @errors << "#{tag} has invalid styles"
        return
      end

      styles.each { |key, value| validate_style_property(key, value, tag) }
    end

    def validate_style_property(key, value, tag)
      rule = Elements::STYLE_WHITELIST[key]
      unless rule
        @errors << "#{tag} has a disallowed style property (#{key})"
        return
      end

      case rule[:type]
      when :numeric
        unless value.is_a?(Numeric) && value.between?(rule[:min], rule[:max])
          @errors << "#{tag} has an out-of-range #{key}"
        end
      when :enum
        @errors << "#{tag} has an invalid #{key}" unless rule[:values].include?(value)
      end
    end

    def validate_variable(element, tag)
      key = element['variable_key']
      unless key.is_a?(String) && @variables_class.scalar_keys.include?(key)
        @errors << "#{tag} has an unknown variable_key (#{key.inspect})"
      end

      validate_optional_string(element, 'fallback', Elements::FALLBACK_MAX_LENGTH, tag)
      validate_optional_string(element, 'prefix', Elements::PREFIX_MAX_LENGTH, tag)
      validate_optional_string(element, 'suffix', Elements::SUFFIX_MAX_LENGTH, tag)
    end

    def validate_optional_string(element, key, max_length, tag)
      return unless element.key?(key)

      value = element[key]
      @errors << "#{tag} has an invalid #{key}" unless value.is_a?(String) && value.length <= max_length
    end

    def validate_text(element, tag)
      text = element['text']
      return if text.is_a?(String) && text.present? && text.length <= Elements::TEXT_MAX_LENGTH

      @errors << "#{tag} has a missing or too-long text value"
    end

    def validate_order_lines(element, tag)
      config = element['config']
      unless config.is_a?(Hash)
        @errors << "#{tag} is missing its order_lines config"
        return
      end

      if config.key?('show_header') && ![true, false].include?(config['show_header'])
        @errors << "#{tag} has an invalid show_header"
      end

      validate_row_spacing(config, tag)
      validate_order_lines_font_size(config, tag)
      validate_order_line_columns(config['columns'], tag)
    end

    def validate_row_spacing(config, tag)
      return unless config.key?('row_spacing_mm')

      value = config['row_spacing_mm']
      in_range = value.is_a?(Numeric) &&
                 value.between?(Elements::ROW_SPACING_MIN_MM, Elements::ROW_SPACING_MAX_MM)
      @errors << "#{tag} has an out-of-range row_spacing_mm" unless in_range
    end

    def validate_order_lines_font_size(config, tag)
      return unless config.key?('font_size_pt')

      rule = Elements::STYLE_WHITELIST['font_size_pt']
      value = config['font_size_pt']
      return if value.is_a?(Numeric) && value.between?(rule[:min], rule[:max])

      @errors << "#{tag} has an out-of-range font_size_pt"
    end

    # Only a lower bound is checked. Every key must be one of the host's declared collection
    # columns and duplicates are rejected below, so the column count cannot exceed the host's
    # own vocabulary — capping it here would reject a legitimately wider host.
    def validate_order_line_columns(columns, tag)
      unless columns.is_a?(Array) && columns.size >= Elements::MIN_ORDER_LINE_COLUMNS
        @errors << "#{tag} must have at least #{Elements::MIN_ORDER_LINE_COLUMNS} order_lines column"
        return
      end

      seen_keys = Set.new
      columns.each_with_index { |column, index| validate_order_line_column(column, index, tag, seen_keys) }
    end

    def validate_order_line_column(column, index, tag, seen_keys)
      col_tag = "#{tag} column ##{index + 1}"

      unless column.is_a?(Hash)
        @errors << "#{col_tag} must be an object"
        return
      end

      validate_order_line_column_key(column, col_tag, seen_keys)
      validate_order_line_column_label(column, col_tag)
      validate_order_line_column_geometry(column, col_tag)
    end

    def validate_order_line_column_label(column, col_tag)
      label = column['label']
      return if label.is_a?(String) && label.present? && label.length <= Elements::COLUMN_LABEL_MAX_LENGTH

      @errors << "#{col_tag} has an invalid label"
    end

    def validate_order_line_column_geometry(column, col_tag)
      width_mm = column['width_mm']
      @errors << "#{col_tag} has an invalid width_mm" unless width_mm.is_a?(Numeric) && width_mm.positive?

      @errors << "#{col_tag} has an invalid align" unless Elements::TEXT_ALIGNS.include?(column['align'])
    end

    def validate_order_line_column_key(column, col_tag, seen_keys)
      key = column['key']
      allowed = @variables_class.collection_definition&.column_keys || []

      if !key.is_a?(String) || !allowed.include?(key)
        @errors << "#{col_tag} has an unknown key (#{key.inspect})"
      elsif seen_keys.include?(key)
        @errors << "#{col_tag} duplicates column key #{key}"
      else
        seen_keys << key
      end
    end
  end
end

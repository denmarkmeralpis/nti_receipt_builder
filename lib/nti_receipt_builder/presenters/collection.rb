# frozen_string_literal: true

require 'action_view'

module NtiReceiptBuilder
  module Presenters
    # Presents one `order_lines` layout element: whitelisted columns, per-row formatted cells,
    # and the dynamically computed content height that drives overflow detection. An empty
    # collection renders a single muted "no line items" row rather than collapsing to nothing.
    #
    # `columns`, `rows` and `total_column_width_mm` are memoised per instance so cell rendering
    # stays O(rows x columns) rather than recomputing the width sum once per cell. Instances are
    # short-lived — one per render — so nothing here outlives the response.
    class Collection
      include ActionView::Helpers::NumberHelper

      DEFAULT_ROW_SPACING_MM = 1.0
      DEFAULT_FONT_SIZE_PT = 9
      MM_PER_PT = 0.3528
      # Tight leading — receipt rows sit directly under one another. Anything near 1.6
      # double-spaces the table and pushes the line items apart.
      LINE_HEIGHT_FACTOR = 1.25

      def initialize(element, rows, definition: nil)
        @element = element
        @collection_rows = rows || []
        @definition = definition
      end

      def id = element['id']
      def type = 'order_lines'
      def x_mm = element['x_mm'].to_f
      def y_mm = element['y_mm'].to_f
      def width_mm = element['width_mm'].to_f
      def z_index = element['z_index'] || 0

      def columns
        @columns ||= (config['columns'] || []).map { |column| build_column(column) }
      end

      # Configured column widths are treated as ratios, not absolutes: normalising them to
      # percentages lets `table-layout: fixed` fill the row edge-to-edge whatever the mm happen
      # to sum to. Falls back to even columns when the template configures no widths at all.
      def column_width_pct(column)
        return (100.0 / columns.size).round(4) unless total_column_width_mm.positive?

        (column['width_mm'] / total_column_width_mm * 100).round(4)
      end

      def show_header? = config.fetch('show_header', true)
      def row_spacing_mm = config['row_spacing_mm'] || DEFAULT_ROW_SPACING_MM
      def font_size_pt = config['font_size_pt'] || DEFAULT_FONT_SIZE_PT

      # The line box for one row of text. Cells render at exactly this line-height with
      # row_spacing_mm as padding below, so a row's drawn height always equals row_height_mm
      # and content_height_mm stays honest for overflow detection.
      def text_line_height_mm
        (font_size_pt * MM_PER_PT * LINE_HEIGHT_FACTOR).round(4)
      end

      def row_height_mm = text_line_height_mm + row_spacing_mm

      # The header is just a bold row — same typography, same height.
      def header_height_mm = show_header? ? row_height_mm : 0.0

      def empty? = collection_rows.blank?

      def rows
        @rows ||= build_rows
      end

      def content_height_mm
        header_height_mm + (rows.size * row_height_mm)
      end

      private

      attr_reader :element, :collection_rows, :definition

      def config
        @config ||= element['config'].is_a?(Hash) ? element['config'] : {}
      end

      def total_column_width_mm
        @total_column_width_mm ||= columns.sum { |column| column['width_mm'] }
      end

      def build_column(column)
        {
          'key' => column['key'],
          'label' => column['label'],
          'width_mm' => column['width_mm'].to_f,
          'align' => column['align']
        }
      end

      def build_rows
        return [] if empty?

        collection_rows.map do |row|
          columns.each_with_object({}) do |column, cells|
            key = column['key']
            cells[key] = format_cell(key, row[key])
          end
        end
      end

      # The declared column type wins; otherwise the value's class decides. The gem does not
      # know what "unit_price" means — the host's variables class does.
      def format_cell(key, value)
        case definition&.column_type(key) || TypeInference.call(value)
        when :currency then format_currency(value)
        else value.to_s
        end
      end

      def format_currency(value)
        return '' if value.nil?

        number_to_currency(value, unit: NtiReceiptBuilder.config.currency_unit)
      rescue StandardError
        value.to_s
      end
    end
  end
end

# frozen_string_literal: true

module NtiReceiptBuilder
  module Presenters
    # Presents one `variable` or `text` layout element: a whitelisted inline style string and
    # a plain (un-escaped-by-us) display string. ERB's default auto-escaping in the render
    # partials is what actually escapes the text — this presenter never marks anything
    # html_safe.
    class Element
      def initialize(element, resolved_variables)
        @element = element
        @resolved_variables = resolved_variables
      end

      def id = element['id']
      def type = element['type']
      def x_mm = element['x_mm'].to_f
      def y_mm = element['y_mm'].to_f
      def width_mm = element['width_mm'].to_f
      def height_mm = element['height_mm'].to_f
      def z_index = element['z_index'] || 0

      def css_style
        declarations = [
          'position: absolute',
          "left: #{x_mm}mm",
          "top: #{y_mm}mm",
          "width: #{width_mm}mm",
          "height: #{height_mm}mm",
          "z-index: #{z_index}"
        ]
        declarations.concat(style_declarations).join('; ')
      end

      def display_text
        case type
        when 'variable' then variable_display_text
        when 'text' then element['text'].to_s
        end
      end

      private

      attr_reader :element, :resolved_variables

      def style_declarations
        styles = element['styles']
        return [] unless styles.is_a?(Hash)

        styles.filter_map do |key, value|
          case key
          when 'font_size_pt' then "font-size: #{value}pt"
          when 'font_weight' then "font-weight: #{value}"
          when 'text_align' then "text-align: #{value}"
          when 'line_height' then "line-height: #{value}"
          end
        end
      end

      def variable_display_text
        value = resolved_variables[element['variable_key']]
        value = element['fallback'] if value.blank?

        "#{element['prefix']}#{value}#{element['suffix']}"
      end
    end
  end
end

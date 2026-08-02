# frozen_string_literal: true

module NtiReceiptBuilder
  # The single entry point that assembles a template's visible layout elements into
  # presenters. The designer preview and the printed receipt both call this — never two
  # divergent render code paths.
  #
  # Pass a receipt_object for real data; omit it and the configured variables class supplies
  # samples, without calling any mapping method.
  class Renderer
    def initialize(template:, receipt_object: nil, variables_class: NtiReceiptBuilder.variables_class)
      @template = template
      @receipt_object = receipt_object
      @variables_class = variables_class
    end

    def call
      data = resolve_data
      resolved_variables = VariableResolver.new(data, definitions: variables_class.definitions).call
      collection_rows = collection_key ? data[collection_key] || [] : []

      presenters = visible_elements
                   .map { |element| build_presenter(element, resolved_variables, collection_rows) }
                   .sort_by(&:z_index)

      RenderResult.new(
        elements: presenters,
        overflow: overflow?(presenters),
        content_height_mm: content_height_mm(presenters)
      )
    end

    private

    attr_reader :template, :receipt_object, :variables_class

    def resolve_data
      return variables_class.sample_data if receipt_object.nil?

      variables_class.new(receipt_object).resolve
    end

    def collection_key = variables_class.collection_key

    def visible_elements
      (template.layout || []).select { |element| element.fetch('visible', true) }
    end

    def build_presenter(element, resolved_variables, collection_rows)
      if element['type'] == 'order_lines'
        Presenters::Collection.new(element, collection_rows, definition: variables_class.collection_definition)
      else
        Presenters::Element.new(element, resolved_variables)
      end
    end

    def bottom_edge_mm(presenter)
      if presenter.is_a?(Presenters::Collection)
        presenter.y_mm + presenter.content_height_mm
      else
        presenter.y_mm + presenter.height_mm
      end
    end

    def content_height_mm(presenters)
      return 0.0 if presenters.empty?

      presenters.map { |presenter| bottom_edge_mm(presenter) }.max
    end

    def overflow?(presenters)
      return false if template.content_layout?

      available_height_mm = template.paper_height_mm.to_f - template.margin_bottom_mm.to_f
      content_height_mm(presenters) > available_height_mm
    end
  end
end

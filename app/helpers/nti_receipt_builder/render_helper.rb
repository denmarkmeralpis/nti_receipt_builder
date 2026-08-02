# frozen_string_literal: true

module NtiReceiptBuilder
  # View helpers for the shared render partials. These are rendered from more than one host
  # controller — the designer's preview/print and a printed receipt — so they live here rather
  # than in a controller-scoped helper.
  module RenderHelper
    # The paper element's inline size: fixed to the declared dimensions, except in "content"
    # height mode where it grows to fit whatever the renderer computed so nothing gets clipped.
    def paper_style(receipt_template, render_result)
      height_mm = if receipt_template.content_layout?
                    [receipt_template.paper_height_mm.to_f,
                     render_result.content_height_mm + receipt_template.margin_bottom_mm.to_f].max
                  else
                    receipt_template.paper_height_mm.to_f
                  end

      "width: #{receipt_template.paper_width_mm.to_f}mm; height: #{height_mm}mm;"
    end
  end
end

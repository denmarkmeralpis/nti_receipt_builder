# frozen_string_literal: true

require 'active_model'
require 'json'

module NtiReceiptBuilder
  # Validates and coerces submitted template params.
  #
  # `layout` arrives as a JSON string from the builder's hidden field. Unparseable JSON is
  # rejected rather than silently dropped — a designer whose layout failed to serialise must
  # see an error, not a blank receipt.
  class TemplateForm
    include ActiveModel::Model

    ATTRIBUTES = %i[name paper_size_key paper_width_mm paper_height_mm orientation height_mode
                    margin_top_mm margin_right_mm margin_bottom_mm margin_left_mm layout
                    lock_version].freeze

    attr_accessor(*ATTRIBUTES)

    validates :name, :paper_size_key, :orientation, :height_mode, presence: true
    validates :paper_width_mm, :paper_height_mm, presence: true
    validate :layout_must_be_valid_json

    def attributes
      {
        name: name,
        paper_size_key: paper_size_key,
        paper_width_mm: paper_width_mm,
        paper_height_mm: paper_height_mm,
        orientation: orientation,
        height_mode: height_mode,
        margin_top_mm: margin_top_mm.presence || 0,
        margin_right_mm: margin_right_mm.presence || 0,
        margin_bottom_mm: margin_bottom_mm.presence || 0,
        margin_left_mm: margin_left_mm.presence || 0,
        layout: parsed_layout
      }.tap { |attrs| attrs[:lock_version] = lock_version if lock_version.present? }
    end

    def parsed_layout
      return [] if layout.blank?
      return layout if layout.is_a?(Array)

      JSON.parse(layout)
    rescue JSON::ParserError
      []
    end

    private

    def layout_must_be_valid_json
      return if layout.blank? || layout.is_a?(Array)

      JSON.parse(layout)
    rescue JSON::ParserError
      errors.add(:layout, 'must be valid JSON')
    end
  end
end

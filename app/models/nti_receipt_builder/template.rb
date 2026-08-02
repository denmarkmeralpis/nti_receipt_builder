# frozen_string_literal: true

module NtiReceiptBuilder
  # A receipt template: paper geometry plus a jsonb layout of positioned elements.
  #
  # Hosts may subclass this to attach their own concerns — audit trail, archivable status,
  # tenancy — and point `config.template_class` at the subclass so the gem's own queries
  # return host instances. `inheritance_column = nil` keeps the subclass sharing this table
  # with no STI type condition and no `type` column to maintain.
  class Template < ActiveRecord::Base
    self.table_name = 'nti_receipt_templates'
    self.inheritance_column = nil

    belongs_to :owner, polymorphic: true

    ORIENTATIONS = %w[portrait landscape].freeze
    HEIGHT_MODES = %w[fixed content].freeze

    MIN_PAPER_DIMENSION_MM = 10.0
    MAX_PAPER_DIMENSION_MM = 1000.0
    MIN_MARGIN_MM = 0.0
    MAX_MARGIN_MM = 100.0

    PAPER_PRESETS = {
      'roll_58mm' => { label: '58mm Roll', width_mm: 58.0, height_mm: 297.0, orientation: 'portrait' },
      'roll_80mm' => { label: '80mm Roll', width_mm: 80.0, height_mm: 297.0, orientation: 'portrait' },
      'a4' => { label: 'A4', width_mm: 210.0, height_mm: 297.0, orientation: 'portrait' },
      'letter' => { label: 'Letter', width_mm: 215.9, height_mm: 279.4, orientation: 'portrait' },
      'custom' => { label: 'Custom', width_mm: 80.0, height_mm: 200.0, orientation: 'portrait' }
    }.freeze

    validates :name, presence: true, length: { maximum: 120 }
    validates :paper_size_key, presence: true, inclusion: { in: PAPER_PRESETS.keys }
    validates :orientation, presence: true, inclusion: { in: ORIENTATIONS }
    validates :height_mode, presence: true, inclusion: { in: HEIGHT_MODES }
    validates :paper_width_mm, :paper_height_mm,
              presence: true,
              numericality: { greater_than_or_equal_to: MIN_PAPER_DIMENSION_MM,
                              less_than_or_equal_to: MAX_PAPER_DIMENSION_MM }
    validates :margin_top_mm, :margin_right_mm, :margin_bottom_mm, :margin_left_mm,
              presence: true,
              numericality: { greater_than_or_equal_to: MIN_MARGIN_MM,
                              less_than_or_equal_to: MAX_MARGIN_MM }
    validate :margins_fit_within_paper
    validate :layout_structure

    def content_layout? = height_mode == 'content'

    private

    def margins_fit_within_paper
      return if paper_width_mm.blank? || paper_height_mm.blank?

      if margin_left_mm.to_f + margin_right_mm.to_f >= paper_width_mm.to_f
        errors.add(:base, 'Left and right margins together exceed the paper width')
      end

      return if content_layout?
      return if margin_top_mm.to_f + margin_bottom_mm.to_f < paper_height_mm.to_f

      errors.add(:base, 'Top and bottom margins together exceed the paper height')
    end

    def layout_structure
      return if layout.blank?

      LayoutValidator.new(
        layout: layout,
        paper_width_mm: paper_width_mm.to_f,
        paper_height_mm: paper_height_mm.to_f,
        margin_top_mm: margin_top_mm.to_f,
        margin_right_mm: margin_right_mm.to_f,
        margin_bottom_mm: margin_bottom_mm.to_f,
        margin_left_mm: margin_left_mm.to_f,
        height_mode: height_mode
      ).call.each { |message| errors.add(:layout, message) }
    end
  end
end

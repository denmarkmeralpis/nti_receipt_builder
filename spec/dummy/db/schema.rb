# frozen_string_literal: true

ActiveRecord::Schema[8.0].define(version: 1) do
  enable_extension 'plpgsql'

  create_table :owners, force: :cascade do |t|
    t.string :name
    t.timestamps
  end

  create_table :nti_receipt_templates, force: :cascade do |t|
    t.string :owner_type, null: false
    t.bigint :owner_id, null: false
    t.string :name, null: false
    t.string :paper_size_key, default: 'custom', null: false
    t.string :orientation, default: 'portrait', null: false
    t.string :height_mode, default: 'fixed', null: false
    t.decimal :paper_width_mm, precision: 8, scale: 2, null: false
    t.decimal :paper_height_mm, precision: 8, scale: 2, null: false
    t.decimal :margin_top_mm, precision: 6, scale: 2, default: '0.0', null: false
    t.decimal :margin_right_mm, precision: 6, scale: 2, default: '0.0', null: false
    t.decimal :margin_bottom_mm, precision: 6, scale: 2, default: '0.0', null: false
    t.decimal :margin_left_mm, precision: 6, scale: 2, default: '0.0', null: false
    t.jsonb :layout, default: [], null: false
    t.boolean :is_default, default: false, null: false
    t.integer :lock_version, default: 0, null: false
    t.timestamps
    t.index %i[owner_type owner_id], name: 'index_nti_receipt_templates_on_owner'
  end
end

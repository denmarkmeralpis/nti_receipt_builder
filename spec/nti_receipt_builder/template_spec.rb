# frozen_string_literal: true

RSpec.describe NtiReceiptBuilder::Template do
  subject(:template) { described_class.new(attributes) }

  let(:owner) { Owner.create!(name: 'Acme') }
  let(:attributes) do
    { owner: owner, name: 'Receipt', paper_size_key: 'roll_80mm', orientation: 'portrait',
      height_mode: 'fixed', paper_width_mm: 80, paper_height_mm: 200,
      margin_top_mm: 2, margin_right_mm: 2, margin_bottom_mm: 2, margin_left_mm: 2, layout: [] }
  end

  before { NtiReceiptBuilder.configure { |c| c.variables_class = TestVariables } }

  it { is_expected.to be_valid }

  it 'persists' do
    expect { template.save! }.to change(described_class, :count).by(1)
  end

  describe 'validations' do
    it 'requires a name' do
      template.name = nil

      expect(template).not_to be_valid
    end

    it 'caps the name length' do
      template.name = 'x' * 121

      expect(template).not_to be_valid
    end

    it 'rejects an unknown paper size key' do
      template.paper_size_key = 'papyrus'

      expect(template).not_to be_valid
    end

    it 'rejects an unknown orientation' do
      template.orientation = 'diagonal'

      expect(template).not_to be_valid
    end

    it 'rejects an unknown height mode' do
      template.height_mode = 'elastic'

      expect(template).not_to be_valid
    end

    it 'rejects paper smaller than the minimum' do
      template.paper_width_mm = 1

      expect(template).not_to be_valid
    end

    it 'rejects margins wider than the paper' do
      template.assign_attributes(margin_left_mm: 50, margin_right_mm: 50)

      expect(template).not_to be_valid
      expect(template.errors[:base]).to include(a_string_matching(/exceed the paper width/))
    end

    it 'rejects margins taller than the paper in fixed mode' do
      template.assign_attributes(paper_height_mm: 20, margin_top_mm: 15, margin_bottom_mm: 15)

      expect(template).not_to be_valid
      expect(template.errors[:base]).to include(a_string_matching(/exceed the paper height/))
    end

    it 'skips the height check in content mode' do
      template.assign_attributes(height_mode: 'content', paper_height_mm: 20,
                                 margin_top_mm: 15, margin_bottom_mm: 15)
      template.valid?

      expect(template.errors[:base]).not_to include(a_string_matching(/paper height/))
    end
  end

  describe 'layout validation' do
    it 'delegates element errors to LayoutValidator' do
      template.layout = [{ 'id' => 'a', 'type' => 'nope', 'x_mm' => 1, 'y_mm' => 1,
                           'width_mm' => 5, 'height_mm' => 5 }]

      expect(template).not_to be_valid
      expect(template.errors[:layout]).to include(a_string_matching(/unknown type/))
    end

    it 'accepts a layout bound to a declared variable key' do
      template.layout = [{ 'id' => 'a', 'type' => 'variable', 'variable_key' => 'CUSTOMER_NAME',
                           'x_mm' => 1, 'y_mm' => 1, 'width_mm' => 5, 'height_mm' => 5 }]

      expect(template).to be_valid
    end

    it 'skips validation for a blank layout' do
      template.layout = []

      expect(template).to be_valid
    end
  end

  describe 'paper presets' do
    it 'exposes the five presets' do
      expect(described_class::PAPER_PRESETS.keys)
        .to eq(%w[roll_58mm roll_80mm a4 letter custom])
    end
  end

  describe 'content_layout?' do
    it 'is true in content mode' do
      template.height_mode = 'content'

      expect(template).to be_content_layout
    end

    it 'is false in fixed mode' do
      expect(template).not_to be_content_layout
    end
  end

  describe 'host subclassing' do
    let(:subclass) { Class.new(described_class) { def self.name = 'HostTemplate' } }

    it 'declares no inheritance column' do
      expect(described_class.inheritance_column).to be_blank
    end

    it 'adds no type condition to subclass queries' do
      expect(subclass.all.to_sql).not_to include('type')
    end

    it 'lets a subclass share the table' do
      expect(subclass.table_name).to eq('nti_receipt_templates')
    end

    it 'lets a subclass read rows written through the parent' do
      template.save!

      expect(subclass.where(id: template.id)).to exist
    end
  end

  describe 'optimistic locking' do
    it 'raises on a stale write' do
      template.save!
      stale = described_class.find(template.id)
      template.update!(name: 'Fresh')

      expect { stale.update!(name: 'Stale') }.to raise_error(ActiveRecord::StaleObjectError)
    end
  end
end

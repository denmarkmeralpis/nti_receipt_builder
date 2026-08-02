# frozen_string_literal: true

RSpec.describe NtiReceiptBuilder::TemplateForm do
  subject(:form) { described_class.new(params) }

  let(:params) do
    { name: 'Receipt', paper_size_key: 'roll_80mm', orientation: 'portrait',
      height_mode: 'content', paper_width_mm: 80, paper_height_mm: 200, layout: '[]' }
  end

  it { is_expected.to be_valid }

  describe 'presence requirements' do
    %i[name paper_size_key orientation height_mode paper_width_mm paper_height_mm].each do |field|
      it "requires #{field}" do
        form = described_class.new(params.merge(field => nil))

        expect(form).not_to be_valid
      end
    end
  end

  describe 'layout parsing' do
    it 'parses a JSON string into an array' do
      form = described_class.new(params.merge(layout: '[{"id":"a"}]'))

      expect(form.attributes[:layout]).to eq([{ 'id' => 'a' }])
    end

    it 'accepts an array unchanged' do
      form = described_class.new(params.merge(layout: [{ 'id' => 'a' }]))

      expect(form.attributes[:layout]).to eq([{ 'id' => 'a' }])
    end

    it 'treats a blank layout as empty' do
      form = described_class.new(params.merge(layout: ''))

      expect(form.attributes[:layout]).to eq([])
    end

    # A designer whose layout failed to serialise must see an error, not a blank receipt.
    it 'rejects unparseable JSON rather than dropping it' do
      form = described_class.new(params.merge(layout: 'not json'))

      expect(form).not_to be_valid
      expect(form.errors[:layout]).to include('must be valid JSON')
    end
  end

  describe 'margins' do
    it 'defaults blank margins to zero' do
      expect(form.attributes.values_at(:margin_top_mm, :margin_right_mm,
                                       :margin_bottom_mm, :margin_left_mm)).to all(eq(0))
    end

    it 'keeps supplied margins' do
      form = described_class.new(params.merge(margin_top_mm: 3))

      expect(form.attributes[:margin_top_mm]).to eq(3)
    end
  end

  describe 'lock_version' do
    it 'is omitted when absent so a create does not force one' do
      expect(form.attributes).not_to have_key(:lock_version)
    end

    it 'is included when supplied' do
      form = described_class.new(params.merge(lock_version: 4))

      expect(form.attributes[:lock_version]).to eq(4)
    end
  end
end

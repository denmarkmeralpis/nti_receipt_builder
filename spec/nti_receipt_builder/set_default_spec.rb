# frozen_string_literal: true

RSpec.describe NtiReceiptBuilder::SetDefault do
  let(:owner) { Owner.create!(name: 'Acme') }
  let(:other_owner) { Owner.create!(name: 'Other') }

  before { NtiReceiptBuilder.configure { |c| c.variables_class = TestVariables } }

  def template(for_owner, name:, is_default: false)
    NtiReceiptBuilder::Template.create!(
      owner: for_owner, name: name, paper_size_key: 'roll_80mm', orientation: 'portrait',
      height_mode: 'content', paper_width_mm: 80, paper_height_mm: 200,
      margin_top_mm: 2, margin_right_mm: 2, margin_bottom_mm: 2, margin_left_mm: 2,
      layout: [], is_default: is_default
    )
  end

  it 'marks the template as default' do
    subject = template(owner, name: 'B')

    described_class.new(template: subject).call

    expect(subject.reload).to be_is_default
  end

  it 'clears the previous default for the same owner' do
    previous = template(owner, name: 'A', is_default: true)
    subject = template(owner, name: 'B')

    described_class.new(template: subject).call

    expect(previous.reload).not_to be_is_default
  end

  it 'leaves another owner\'s default alone' do
    foreign = template(other_owner, name: 'Theirs', is_default: true)
    subject = template(owner, name: 'B')

    described_class.new(template: subject).call

    expect(foreign.reload).to be_is_default
  end

  it 'is idempotent for a template that is already default' do
    subject = template(owner, name: 'A', is_default: true)

    expect { described_class.new(template: subject).call }.not_to raise_error
    expect(subject.reload).to be_is_default
  end

  it 'clears previous defaults in a single UPDATE rather than loading them' do
    template(owner, name: 'A', is_default: true)
    subject = template(owner, name: 'B')

    queries = []
    subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
      queries << payload[:sql] if payload[:sql].start_with?('UPDATE')
    end
    described_class.new(template: subject).call
    ActiveSupport::Notifications.unsubscribe(subscriber)

    expect(queries.count { |sql| sql.include?('is_default') }).to eq(2)
  end
end

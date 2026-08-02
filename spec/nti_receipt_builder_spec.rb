# frozen_string_literal: true

RSpec.describe NtiReceiptBuilder do
  it 'has a version number' do
    expect(NtiReceiptBuilder::VERSION).not_to be_nil
  end

  it 'boots the dummy application' do
    expect(Rails.application).to be_initialized
  end

  it 'connects to a database that supports jsonb' do
    expect(ActiveRecord::Base.connection.adapter_name).to eq('PostgreSQL')
  end
end

# frozen_string_literal: true

RSpec.describe PrawnHtml::Tags::B do
  subject(:b) { described_class.new(:b, 'style' => 'color: ffbb11') }

  it { expect(described_class).to be < PrawnHtml::Tags::Base }

  context 'without attributes' do
    it 'returns the expected extra_attrs for b tag' do
      expect(b.extra_attrs).to eq('font-weight' => 'bold')
    end
  end
end
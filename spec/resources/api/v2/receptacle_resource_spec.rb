# frozen_string_literal: true

require 'rails_helper'
require './app/resources/api/v2/receptacle_resource'

RSpec.describe Api::V2::ReceptacleResource, type: :resource do
  subject(:resource) { described_class.new(resource_model, {}) }

  let(:resource_model) { create :receptacle }

  # Test attributes
  it 'works', :aggregate_failures do
    expect(subject).to have_attribute :uuid
    expect(subject).to have_attribute :name
    expect(subject).not_to have_updatable_field(:id)
    expect(subject).not_to have_updatable_field(:uuid)
    expect(subject).not_to have_updatable_field(:name)
    expect(subject).to have_many(:samples).with_class_name('Sample')
    expect(subject).to have_many(:projects).with_class_name('Project')
    expect(subject).to have_many(:studies).with_class_name('Study')
  end

  # Custom method tests
  # Add tests for any custom methods you've added.
  # describe '#labware_barcode' do
  #   subject { resource.labware_barcode }
  #   it { is_expected.to eq('ean13_barcode' => '', 'human_barcode' => '') }
  # end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SampleManifestExcel::Upload::Rows, type: :model, sample_manifest_excel: true do
  before(:all) do
    SampleManifestExcel.configure do |config|
      config.folder = File.join('spec', 'data', 'sample_manifest_excel')
      config.load!
    end
  end

  let(:test_file_name) { 'test_file.xlsx' }
  let(:test_file) { Rack::Test::UploadedFile.new(Rails.root.join(test_file_name), '') }
  let(:columns) { SampleManifestExcel.configuration.columns.tube_library_with_tag_sequences.dup }

  after(:all) do
    SampleManifestExcel.reset!
  end

  after do
    File.delete(test_file_name) if File.exist?(test_file_name)
  end

  it 'is not valid without some data' do
    expect(SampleManifestExcel::Upload::Rows.new(nil, columns)).not_to be_valid
  end

  it 'is not valid without some columns' do
    download = build(:test_download_tubes, columns: columns)
    download.save(test_file_name)
    expect(SampleManifestExcel::Upload::Rows.new(SampleManifestExcel::Upload::Data.new(test_file, 9), nil)).not_to be_valid
  end

  it 'is not valid unless all of the rows are valid' do
    download = build(:test_download_tubes, columns: columns, validation_errors: [:insert_size_from])
    download.save(test_file_name)
    expect(SampleManifestExcel::Upload::Rows.new(SampleManifestExcel::Upload::Data.new(test_file, 9), columns)).not_to be_valid
  end

  it 'is valid if some rows are empty' do
    download = build(:test_download_tubes_partial, columns: columns)
    download.save(test_file_name)
    expect(SampleManifestExcel::Upload::Rows.new(SampleManifestExcel::Upload::Data.new(test_file, 9), columns)).to be_valid
  end

  it 'creates the row number relative to the start row' do
    download = build(:test_download_tubes, columns: columns, validation_errors: [:insert_size_from])
    download.save(test_file_name)
    rows = SampleManifestExcel::Upload::Rows.new(SampleManifestExcel::Upload::Data.new(test_file, 9), columns)
    expect(rows.first.number).to eq(10)
  end

  it 'knows values for all rows at particular column' do
    download = build(:test_download_tubes, columns: columns, validation_errors: [:insert_size_from])
    download.save(test_file_name)
    rows = SampleManifestExcel::Upload::Rows.new(SampleManifestExcel::Upload::Data.new(test_file, 9), columns)
    # column 7 is insert_size_from
    expect(rows.data_at(7)).to eq [nil, '200', '200', '200', '200', '200']
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SampleManifestExcel::Upload::Row, type: :model, sample_manifest_excel: true do
  setup do
    create(:library_type, name: 'My New Library Type')
    create(:reference_genome, name: 'My reference genome')
  end

  let(:configuration) do
    SampleManifestExcel::Configuration.new do |config|
      config.folder = File.join('spec', 'data', 'sample_manifest_excel')
      config.load!
    end
  end

  let(:columns)          { configuration.columns.tube_library_with_tag_sequences.dup }
  let(:sample_manifest)  { create(:tube_sample_manifest_with_tubes_and_manifest_assets) }
  let(:tube)             { sample_manifest.labware.first }
  let(:tag_group)        { create(:tag_group) }
  let(:data) do
    [tube.human_barcode, sample_manifest.sample_manifest_assets.first.sanger_sample_id,
     'AA', '', 'My reference genome', 'My New Library Type', 200, 1500, 'SCG--1222_A01', '', 1, 1, 'Unknown', '', '', '',
     'Cell Line', 'Nov-16', 'Nov-16', '', 'No', '', 'OTHER', '', '', '', '', '', 'SCG--1222_A01',
     9606, 'Homo sapiens', '', '', '', '', 11, 'Unknown']
  end
  let(:data_with_spaces) do
    [tube.human_barcode, sample_manifest.sample_manifest_assets.first.sanger_sample_id,
     ' ATTACTCG ', '', 'My reference genome', 'My New Library Type', 200, 1500, 'SCG--1222_A01', '', 1, 1, 'Unknown', '', '', '',
     'Cell Line', 'Nov-16', 'Nov-16', '', 'No', '', 'OTHER', '', '', '', '', '', 'SCG--1222_A01',
     9606, 'Homo sapiens', '', '', '', '', 11, 'Unknown']
  end

  it 'is not valid without row number' do
    expect(SampleManifestExcel::Upload::Row.new(number: 'one', data: data, columns: columns)).not_to be_valid
    expect(SampleManifestExcel::Upload::Row.new(data: data, columns: columns)).not_to be_valid
  end

  it 'is not valid without some data' do
    expect(SampleManifestExcel::Upload::Row.new(number: 1, columns: columns)).not_to be_valid
  end

  it 'is not valid without some columns' do
    expect(SampleManifestExcel::Upload::Row.new(number: 1, data: data)).not_to be_valid
  end

  it '#value returns value for specified key' do
    expect(SampleManifestExcel::Upload::Row.new(number: 1, data: data, columns: columns).value(:sanger_sample_id)).to eq(sample_manifest.labware.first.sample_manifest_assets.first.sanger_sample_id)
  end

  it '#at returns value at specified index (offset by 1)' do
    expect(SampleManifestExcel::Upload::Row.new(number: 1, data: data, columns: columns).at(3)).to eq('AA')
  end

  it '#at strips down spaces including non-breaking ones (\u00A0)' do
    row = SampleManifestExcel::Upload::Row.new(number: 1, data: data_with_spaces, columns: columns)
    tag_cell_content = data_with_spaces[2]
    tag_cell_content_retrieved = row.at(3)
    expect(tag_cell_content.bytes[0]).to eq(32)
    expect(tag_cell_content.bytes[10]).to eq(160)
    expect(tag_cell_content_retrieved).to eq('ATTACTCG')
  end

  it '#at strips down spaces' do
    row = SampleManifestExcel::Upload::Row.new(number: 1, data: data_with_spaces, columns: columns)
    reference_genome_cell_content = data_with_spaces[4]
    reference_genome_cell_content_retrieved = row.at(5)
    volume_cell_content = data_with_spaces[6]
    volume_cell_content_retrieved = row.at(7)
    empty_cell_content = data_with_spaces[3]
    empty_cell_content_retrieved = row.at(4)
    expect(reference_genome_cell_content_retrieved).to eq(reference_genome_cell_content)
    expect(volume_cell_content_retrieved).to eq(volume_cell_content)
    expect(empty_cell_content_retrieved).to eq(empty_cell_content)
  end

  it '#first? is true if this is the first row' do
    expect(SampleManifestExcel::Upload::Row.new(number: 1, data: data, columns: columns)).to be_first
  end

  it 'is not valid without a primary receptacle or sample' do
    data[1] = 2
    expect(SampleManifestExcel::Upload::Row.new(number: 1, data: data, columns: columns)).not_to be_valid
    data[1] = 999999
    row = SampleManifestExcel::Upload::Row.new(number: 1, data: data, columns: columns)
    expect(row).not_to be_valid
    expect(row.errors.full_messages).to include('Row 1 - Sample can\'t be blank.')
  end

  it 'is not valid unless all specialised fields are valid' do
    expect(SampleManifestExcel::Upload::Row.new(number: 1, data: data, columns: columns)).to be_valid
    data[5] = 'Dodgy library type'
    expect(SampleManifestExcel::Upload::Row.new(number: 1, data: data, columns: columns)).not_to be_valid
    data[5] = 'My New Library Type'
    data[6] = 'one'
    expect(SampleManifestExcel::Upload::Row.new(number: 1, data: data, columns: columns)).not_to be_valid
  end

  it 'is not valid unless metadata is valid' do
    SampleManifestExcel::Upload::Row.new(number: 1, data: data, columns: columns)
    expect(SampleManifestExcel::Upload::Row.new(number: 1, data: data, columns: columns)).to be_valid
    data[16] = 'Cell-line'
    expect(SampleManifestExcel::Upload::Row.new(number: 1, data: data, columns: columns)).not_to be_valid
  end

  it 'updates the aliquot with the specialised fields' do
    sample_count = Sample.count
    row = SampleManifestExcel::Upload::Row.new(number: 1, data: data, columns: columns)
    row.update_specialised_fields(tag_group)
    aliquot = row.aliquot
    expect(Sample.count - sample_count).to eq(1)
    expect(aliquot.tag.oligo).to eq('AA')
    expect(aliquot.tag2).to be nil
    expect(aliquot.insert_size_from).to eq(200)
    expect(aliquot.insert_size_to).to eq(1500)
  end

  it 'updates the sample metadata' do
    row = SampleManifestExcel::Upload::Row.new(number: 1, data: data, columns: columns)
    row.update_metadata_fields
    expect(row.metadata).to have_attributes(
      concentration: '1',
      gender: 'Unknown',
      dna_source: 'Cell Line',
      date_of_sample_collection: 'Nov-16',
      date_of_sample_extraction: 'Nov-16',
      sample_purified: 'No',
      concentration_determined_by: 'OTHER',
      sample_public_name: 'SCG--1222_A01',
      sample_taxon_id: 9606,
      sample_common_name: 'Homo sapiens',
      donor_id: '11',
      phenotype: 'Unknown'
    )
  end

  it 'updates the sample' do
    row = SampleManifestExcel::Upload::Row.new(number: 1, data: data, columns: columns)
    row.update_sample(tag_group, false)
    row.metadata
    expect(row).to be_sample_updated
  end

  it 'knows if it is empty' do
    empty_data = [sample_manifest.labware.first.human_barcode, sample_manifest.labware.first.sample_manifest_assets.first.sanger_sample_id,
                  '', '', '', '', '', '', '', '', '', '', '', '', '',
                  '', '', '', '', '', '', '', '', '', '', '', '', '', '', '',
                  '', '', '', '', '', '', '', sample_manifest.labware.first.sample_manifest_assets.first.sanger_sample_id, '']
    row = SampleManifestExcel::Upload::Row.new(number: 1, data: data, columns: columns)
    empty_row = SampleManifestExcel::Upload::Row.new(number: 1, data: empty_data, columns: columns)
    expect(row.empty?).to be false
    expect(empty_row.empty?).to be true
  end

  context 'aliquot transfer on multiplex library tubes' do
    attr_reader :rows

    let(:library_tubes) { create_list(:library_tube_with_barcode, 5) }
    let(:mx_library_tube) { create(:multiplexed_library_tube) }
    let(:tags) { SampleManifestExcel::Tags::ExampleData.new.take(0, 4) }
    let(:manifest) { create :sample_manifest }

    before do
      @rows = []
      library_tubes.each_with_index do |tube, i|
        create(:sample_manifest_asset, sample_manifest: manifest, asset: tube, sanger_sample_id: tube.samples.first.sanger_sample_id)
        create(:external_multiplexed_library_tube_creation_request, asset: tube, target_asset: mx_library_tube)
        row_data = data.dup
        row_data[0] = tube.human_barcode
        row_data[1] = tube.samples.first.sanger_sample_id
        row_data[2] = tags[i][:i7]
        row_data[3] = tags[i][:i5]
        rows << SampleManifestExcel::Upload::Row.new(number: i + 1, data: row_data, columns: columns)
      end
    end

    it 'transfers stuff' do
      rows.each do |row|
        expect(row).to be_valid
        row.update_sample(tag_group, false)
        row.transfer_aliquot
      end
      expect(rows).to be_all(&:aliquot_transferred?)
      expect(rows).not_to be_all(&:reuploaded?)
      mx_library_tube.samples.each_with_index do |sample, i|
        expect(sample.aliquots.first.tag.oligo).to eq(tags[i][:i7])
        expect(sample.aliquots.first.tag2.oligo).to eq(tags[i][:i5])
        sample.primary_receptacle.requests.each do |request|
          expect(request.state).to eq('passed')
        end
      end
    end
  end

  context 'previously transferred aliquot on multiplex library tubes' do
    attr_reader :rows

    let!(:library_tubes) { create_list(:tagged_library_tube, 5) }
    let!(:mx_library_tube) { create(:multiplexed_library_tube) }
    let(:tags) { SampleManifestExcel::Tags::ExampleData.new.take(0, 4) }
    let(:manifest) { create :sample_manifest }

    before do
      @rows = []
      library_tubes.each_with_index do |tube, i|
        create(:sample_manifest_asset, sample_manifest: manifest, asset: tube, sanger_sample_id: tube.samples.first.sanger_sample_id)
        rq = create(:external_multiplexed_library_tube_creation_request, asset: tube, target_asset: mx_library_tube)
        rq.manifest_processed!
        row_data = data.dup
        row_data[0] = tube.samples.first.primary_receptacle.human_barcode
        row_data[1] = tube.samples.first.sanger_sample_id
        row_data[2] = tags[i][:i7]
        row_data[3] = tags[i][:i5]
        rows << SampleManifestExcel::Upload::Row.new(number: i + 1, data: row_data, columns: columns)
      end
    end

    it 'transfers stuff' do
      rows.each do |row|
        row.update_sample(tag_group, false)
        row.transfer_aliquot
      end
      expect(rows).to be_all(&:aliquot_transferred?)
      expect(rows).to be_all(&:reuploaded?)
      mx_library_tube.samples.each_with_index do |sample, i|
        expect(sample.aliquots.first.tag.oligo).to eq(tags[i][:i7])
        expect(sample.aliquots.first.tag2.oligo).to eq(tags[i][:i5])
        sample.primary_receptacle.requests.each do |request|
          expect(request.state).to eq('passed')
        end
      end
    end
  end
end

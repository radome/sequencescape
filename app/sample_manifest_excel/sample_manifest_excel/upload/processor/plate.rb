# frozen_string_literal: true

require_dependency 'sample_manifest_excel/upload/processor/base'
module SampleManifestExcel
  module Upload
    module Processor
      # TODO: had to explicitly specify the namespace for Base here otherwise it picks up Upload::Base
      ##
      # Processor to handle plate manifest uploads.
      class Plate < SampleManifestExcel::Upload::Processor::Base
        # For plate manifests the barcodes (sanger plate id column) should be the same for each well from the same
        # plate, and different for each plate.
        # Uniqueness of foreign barcodes in the database is checked in the specialised field sanger_plate_id.
        def check_for_barcodes_unique
          return unless any_duplicate_barcodes?

          errors.add(:base, 'Duplicate barcodes detected, the barcode must be unique for each plate.')
        end

        def any_duplicate_barcodes?
          return false unless upload.respond_to?('rows')

          unique_bcs = {}
          upload.rows.each do |row|
            next if row.columns.blank? || row.data.blank?

            plate_barcode = row.value('sanger_plate_id')
            sample_id = row.value('sanger_sample_id')
            next if plate_barcode.nil? || sample_id.nil?

            plate_id_for_sample = find_plate_id_for_sample_id(sample_id)
            next if plate_id_for_sample.nil?

            if unique_bcs.key?(plate_barcode)
              # check if duplicate
              return true unless unique_bcs[plate_barcode] == plate_id_for_sample
            else
              # new plate not seen before
              unique_bcs[plate_barcode] = plate_id_for_sample
            end
          end
          false
        end

        def find_plate_id_for_sample_id(sample_id)
          sample_manifest_asset = SampleManifestAsset.find_by(sanger_sample_id: sample_id)
          sample_manifest_asset.labware&.id
        end
      end
    end
  end
end

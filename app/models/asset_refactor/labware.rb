# frozen_string_literal: true

module AssetRefactor
  # Labware reflects a physical piece of plastic which can move round the
  # lab.
  module Labware
    # Labware specific methods
    module Methods
      extend ActiveSupport::Concern

      included do
        include SharedBehaviour::Named
        has_many :asset_audits, foreign_key: :asset_id, dependent: :destroy, inverse_of: :asset
        has_many :volume_updates, foreign_key: :target_id, dependent: :destroy, inverse_of: :target
        has_many :state_changes, foreign_key: :target_id, dependent: :destroy, inverse_of: :target
        has_one :custom_metadatum_collection, foreign_key: :asset_id, dependent: :destroy, inverse_of: :asset
        belongs_to :labware_type, class_name: 'PlateType', optional: true

        delegate :metadata, to: :custom_metadatum_collection, allow_nil: true

        scope :with_purpose, ->(*purposes) { where(plate_purpose_id: purposes.flatten) }
        scope :include_scanned_into_lab_event, -> { includes(:scanned_into_lab_event) }
      end

      attr_reader :storage_location_service

      def labwhere_location
        @labwhere_location ||= lookup_labwhere_location
      end

      # Labware reflects the physical piece of plastic corresponding to an asset
      def labware
        self
      end

      def storage_location
        @storage_location ||= obtain_storage_location
      end

      def scanned_in_date
        scanned_into_lab_event.try(:content) || ''
      end

      private

      def obtain_storage_location
        if labwhere_location.present?
          @storage_location_service = 'LabWhere'
          labwhere_location
        else
          @storage_location_service = 'None'
          'LabWhere location not set. Could this be in ETS?'
        end
      end

      def lookup_labwhere_location
        lookup_labwhere(machine_barcode) || lookup_labwhere(human_barcode)
      end

      def lookup_labwhere(barcode)
        begin
          info_from_labwhere = LabWhereClient::Labware.find_by_barcode(barcode)
        rescue LabWhereClient::LabwhereException => e
          return "Not found (#{e.message})"
        end
        return info_from_labwhere.location.location_info if info_from_labwhere.present? && info_from_labwhere.location.present?
      end
    end
  end
end

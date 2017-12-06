class Plate::Creator::PurposeRelationship < ApplicationRecord
    self.table_name = ('plate_creator_purposes')

    belongs_to :plate_purpose
    belongs_to :plate_creator, class_name: 'Plate::Creator'
end
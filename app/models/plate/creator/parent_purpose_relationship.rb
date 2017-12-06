class Plate::Creator::ParentPurposeRelationship < ApplicationRecord
    self.table_name = ('plate_creator_parent_purposes')

    belongs_to :plate_purpose, class_name: 'Purpose'
end
# Rails migration
class EliminateRedundantPlatePurposeClasses < ActiveRecord::Migration
  class Purpose < ApplicationRecord
    self.table_name = 'plate_purposes'
    self.inheritance_column = nil
  end

  def up
    ActiveRecord::Base.transaction do
      each_name_and_old_class do |name, _old_class|
        purpose = Purpose.find_by(name: name)
        next if purpose.nil?

        say "Migrating #{purpose.name}"
        purpose.update!(type: 'PlatePurpose')
      end
    end
  end

  def down
    ActiveRecord::Base.transaction do
      each_name_and_old_class do |name, old_class|
        purpose = Purpose.find_by(name: name)
        next if purpose.nil?

        say "Migrating #{purpose.name}"
        purpose.update!(type: old_class)
      end
    end
  end

  def each_name_and_old_class(&block)
    [
      ['Pico Assay A', 'PicoAssayPlatePurpose'],
      ['Pico Assay Plates', 'PicoAssayPlatePurpose'],
      ['Pico Assay B', 'PicoAssayPlatePurpose'],
      ['Pulldown Aliquot', 'PulldownAliquotPlatePurpose'],
      ['EnRichment 4', 'PulldownEnrichmentFourPlatePurpose'],
      ['EnRichment 1', 'PulldownEnrichmentOnePlatePurpose'],
      ['EnRichment 3', 'PulldownEnrichmentThreePlatePurpose'],
      ['EnRichment 2', 'PulldownEnrichmentTwoPlatePurpose'],
      ['Pulldown PCR', 'PulldownPcrPlatePurpose'],
      %w[Pulldown PulldownPlatePurpose],
      ['Pulldown qPCR', 'PulldownQpcrPlatePurpose'],
      ['Run of Robot', 'PulldownRunOfRobotPlatePurpose'],
      ['Sequence Capture', 'PulldownSequenceCapturePlatePurpose'],
      %w[Sonication PulldownSonicationPlatePurpose],
      %w[Sequenom QcPlatePurpose],
      ['Gel Dilution', 'WorkingDilutionPlatePurpose'],
      ['Gel Dilution Plates', 'WorkingDilutionPlatePurpose']
    ].each(&block)
  end
end

# frozen_string_literal: true

namespace :plate_types do
  desc 'Add Plate Types for bed verification (GPL-118)'
  task add: [:environment] do
    puts 'Adding Plate Types...'
    PlateType.create!(name: 'EppendorfTwin.Tec', maximum_volume: 180)
  end
end

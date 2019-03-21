# frozen_string_literal: true

FactoryBot.define do
  factory :asset_shape do
    sequence(:name) { |i| "Shape #{i}" }
    horizontal_ratio { 3 }
    vertical_ratio { 2 }
    description_strategy { 'Map::Coordinate' }

    factory :fluidigm_96_shape do
      horizontal_ratio { 3 }
      vertical_ratio { 8 }
      description_strategy { 'Map::Sequential' }
      after(:create) do |shape|
        shape.generate_map(96)
      end
    end

    factory :fluidigm_192_shape do
      horizontal_ratio { 3 }
      vertical_ratio { 4 }
      description_strategy { 'Map::Sequential' }
      after(:create) do |shape|
        shape.generate_map(192)
      end
    end
  end
end

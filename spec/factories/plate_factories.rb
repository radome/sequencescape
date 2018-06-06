# frozen_string_literal: true

# Please note: This is a new file to help improve factory organization.
# Some plate factories may exist elsewhere, especially in the domain
# files, such as pipelines and in the catch all factory folder.
# Create all new plate factories here, and move others as you find them,
# especially if you change them, otherwise merges could get messy.

# The factories in here, at time of writing could do with a bit of TLC.
FactoryBot.define do
  # Allows a plate to automatically generate wells. Invluded in most plate factories already
  # If you inherit from the standard plate, you do not need to include this.
  trait :with_wells do
    transient do
      sample_count { 0 } # The number of wells to create [LEGACY: use well_count instead]
      well_count { sample_count } # The number of wells to create
      well_factory :well # THe factory to use for wells
      studies { build_list(:study, 1) } # A list of studies to apply to wells.
      projects { build_list(:project, 1) } # A list of projects to apply to wells
      well_order :column_order # The order of wells on the plate. Almost always column_order
      # HELPERS: Generally you shouldn't need to use these transients
      studies_cycle { studies.cycle } # Allow us to rotate through listed studies when building out wells
      projects_cycle { projects.cycle } # Allow us to rotate through listed studies when building out wells
      well_locations { maps.where(well_order => (0...well_count)) }
    end

    after(:build) do |plate, evaluator|
      plate.wells = evaluator.well_locations.map do |map|
        build(evaluator.well_factory, map: map, study: evaluator.studies_cycle.next, project: evaluator.projects_cycle.next)
      end
    end
  end

  trait :with_submissions do
    transient do
      submission_count { 1 }
      submissions { create_list :submission, submission_count }
      submission_cycle { submissions.cycle }
    end
    after(:create) do |plate, evaluator|
      plate.wells.each do |well|
        well.transfer_requests_as_target << create(:transfer_request, target_asset: well, submission: evaluator.submission_cycle.next)
      end
    end
  end

  trait :plate_barcode do
    transient do
      barcode { generate :barcode_number }
      prefix 'DN'
    end
    sanger_barcode { { prefix: prefix, number: barcode } }
  end

  factory :plate, traits: [:plate_barcode, :with_wells] do
    plate_purpose
    size 96

    factory :input_plate do
      association(:plate_purpose, factory: :input_plate_purpose)
    end

    factory :target_plate do
      transient do
        parent { build :input_plate }
        submission { build :submission }
      end

      after(:build) do |plate, evaluator|
        well_hash = evaluator.parent.wells.index_by(&:map_description)
        plate.wells.each do |well|
          well.stock_well_links << build(:stock_well_link, target_well: well, source_well: well_hash[well.map_description])
          create :transfer_request, asset: well_hash[well.map_description], target_asset: well, submission: evaluator.submission
        end
      end
    end

    factory :plate_with_untagged_wells do
      transient do
        sample_count 8
        well_factory :untagged_well
      end
    end

    factory :plate_with_tagged_wells do
      transient do
        sample_count 8
        well_factory :tagged_well
      end
    end

    factory :plate_with_empty_wells do
      transient { well_count 8 }
    end

    factory :source_plate do
      plate_purpose { |pp| pp.association(:source_plate_purpose) }
    end

    factory :child_plate do
      transient do
        parent { create(:source_plate) }
      end

      plate_purpose { |pp| pp.association(:plate_purpose, source_purpose: parent.purpose) }

      after(:create) do |child_plate, evaluator|
        child_plate.parents << evaluator.parent
        child_plate.purpose.source_purpose = evaluator.parent.purpose
      end
    end

    factory :plate_with_wells_for_specified_studies do
      transient do
        studies { create_list(:study, 2) }
        project nil

        occupied_map_locations do
          Map.where_plate_size(size).where_plate_shape(AssetShape.default).where(well_order => (0...studies.size))
        end
        well_order :column_order
      end

      after(:create) do |plate, evaluator|
        plate.wells = evaluator.occupied_map_locations.map.with_index do |map, i|
          create(:well_for_location_report, map: map, study: evaluator.studies[i], project: nil)
        end
      end
    end

    factory :plate_with_fluidigm_barcode do
      transient do
        sample_count 8
        well_factory :tagged_well
      end
      sequence(:fluidigm_barcode) { |i| (1000000000 + i).to_s }
      size 192
    end
  end

  factory(:full_plate, class: Plate, traits: [:plate_barcode, :with_wells]) do
    size 96
    plate_purpose

    transient do
      well_count 96
    end

    # A plate that has exactly the right number of wells!
    factory :pooling_plate do
      plate_purpose { create :pooling_plate_purpose }
      transient do
        well_count 6
        well_factory :tagged_well
      end
    end

    factory :non_stock_pooling_plate do
      plate_purpose

      transient do
        well_count 6
        well_factory :empty_well
      end
    end

    factory :input_plate_for_pooling do
      association(:plate_purpose, factory: :input_plate_purpose)
      transient do
        well_count 6
        well_factory :tagged_well
      end
    end

    factory(:full_stock_plate) do
      plate_purpose { PlatePurpose.stock_plate_purpose }

      factory(:partial_plate) do
        transient { well_count 48 }
      end

      factory(:plate_for_strip_tubes) do
        transient do
          well_count 8
          well_factory :tagged_well
        end
      end

      factory(:two_column_plate) do
        transient { well_count 16 }
      end
    end

    factory(:full_plate_with_samples) do
      transient { well_factory :tagged_well }
    end
  end

  factory :control_plate, traits: [:plate_barcode, :with_wells] do
    plate_purpose # { PlatePurpose.find_by(name: 'Stock plate') }
    name 'Control Plate name'
  end

  # factory :dilution_plate, traits: [:plate_barcode, :with_wells] do
  #   plate_purpose { PlatePurpose.find_by!(name: 'Stock plate') }
  #   size 96
  # end
  # factory :gel_dilution_plate, traits: [:plate_barcode, :with_wells] do
  #   plate_purpose { PlatePurpose.find_by!(name: 'Gel Dilution') }
  #   size 96
  # end
  factory :pico_assay_plate, traits: [:plate_barcode, :with_wells] do
    plate_purpose # { PlatePurpose.find_by!(name: 'Stock plate') }
    size 96

    factory :pico_assay_a_plate, traits: [:plate_barcode, :with_wells] do
      plate_purpose # { PlatePurpose.find_by!(name: 'Pico Assay A') }
      size 96
    end
    factory :pico_assay_b_plate, traits: [:plate_barcode, :with_wells] do
      plate_purpose # { PlatePurpose.find_by!(name: 'Pico Assay B') }
      size 96
    end
  end
  factory :pico_dilution_plate, traits: [:plate_barcode, :with_wells] do
    plate_purpose # { PlatePurpose.find_by!(name: 'Pico Dilution') }
    size 96
  end
  factory :sequenom_qc_plate, traits: [:plate_barcode, :with_wells] do
    sequence(:name) { |i| "Sequenom #{i}" }
    plate_purpose # { PlatePurpose.find_by!(name: 'Sequenom') }
    size 96
  end
  factory :working_dilution_plate, traits: [:plate_barcode, :with_wells] do
    plate_purpose # { PlatePurpose.find_by!(name: 'Working Dilution') }
    size 96
  end

  # StripTubes are effectively thin plates
  factory :strip_tube do
    name               'Strip_tube'
    size               8
    plate_purpose      { create :strip_tube_purpose }
    after(:create) do |st|
      st.wells = st.maps.map { |map| create(:well, map: map) }
    end
  end
end

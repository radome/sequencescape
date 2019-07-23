# Generates warehouse messages describing a PacBio run.
# PacBio runs are approximated by {Batch batches}
class Api::Messages::PacBioRunIO < Api::Base
  renders_model(::Batch)

  map_attribute_to_json_attribute(:id, 'pac_bio_run_id')
  map_attribute_to_json_attribute(:uuid, 'pac_bio_run_uuid')

  map_attribute_to_json_attribute(:updated_at)

  with_association(:first_output_plate) do
    map_attribute_to_json_attribute(:human_barcode, 'plate_barcode')
    map_attribute_to_json_attribute(:uuid, 'plate_uuid_lims')

    with_nested_has_many_association(:wells) do
      map_attribute_to_json_attribute(:map_description, 'well_label')
      map_attribute_to_json_attribute(:uuid, 'well_uuid_lims')

      with_nested_has_many_association(:requests_as_target, as: 'samples') do
        with_association(:initial_project) do
          map_attribute_to_json_attribute(:project_cost_code_for_uwh, 'cost_code')
        end

        with_association(:initial_study) do
          map_attribute_to_json_attribute(:uuid, 'study_uuid')
        end

        with_association(:asset) do
          map_attribute_to_json_attribute(:external_identifier, 'pac_bio_library_tube_id_lims')
          map_attribute_to_json_attribute(:uuid, 'pac_bio_library_tube_uuid')

          with_association(:labware) do
            map_attribute_to_json_attribute(:name, 'pac_bio_library_tube_name')
          end

          map_attribute_to_json_attribute(:id, 'pac_bio_library_tube_legacy_id')

          with_association(:primary_aliquot) do
            with_association(:sample) do
              map_attribute_to_json_attribute(:uuid, 'sample_uuid')
            end

            with_association(:tag) do
              map_attribute_to_json_attribute(:oligo, 'tag_sequence')
              map_attribute_to_json_attribute(:tag_group_id, 'tag_set_id_lims')
              map_attribute_to_json_attribute(:map_id, 'tag_identifier')

              with_association(:tag_group) do
                map_attribute_to_json_attribute(:name, 'tag_set_name')
              end
            end
          end
        end
      end
    end
  end
end

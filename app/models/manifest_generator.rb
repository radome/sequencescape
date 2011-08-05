class ManifestGenerator

  QUOTE_CHAR = "!"
  DEFAULT_VOLUME = 13
  DEFAULT_CONCENTRATION = 50
  DEFAULT_SPECIES = "Homo sapiens"
  DEFAULT_IS_CONTROL = 0

  def self.generate_manifests(batch,study)
    generate_manifest_for_plate_ids(batch.plate_ids_in_study(study),study)
  end

  def self.generate_manifest_for_plate_ids(plate_ids,study)
    csv_string = FasterCSV.generate(:row_sep => "\n", :quote_char => "#{QUOTE_CHAR}") do |csv|
      create_header(csv,study)
      row = 1
      plate_ids.each do |plate_id|
        plate = Plate.find(plate_id)
        plate_label = institute_plate_label(plate)
        plate.wells_sorted_by(&:id).each do |well|
          csv << self.generate_manifest_row(well,plate.barcode,plate_label).unshift(row)
          row = row +1
        end
      end
    end
    csv_string = remove_empty_quotes(csv_string)

    csv_string
  end

  def self.generate_manifest_row(well,plate_barcode,plate_label)
    comments          = ""
    extraction_method = "-"
    wga_method        = ""
    dna_mass          = 0
    replicates        = ""
    tissue_source     = "-"

    [ "#{plate_label}",
      well_map_description(well),
      well_sample_is_control(well),
      construct_sample_label(plate_barcode, well),
      well_sample_species(well),
      well_sample_gender(well),
      "#{comments}",
      well_volume(well),
      well_concentration(well),
      "#{extraction_method}",
      "#{wga_method}",
      "#{dna_mass}",
      well_sample_parent(well, 'mother'),
      well_sample_parent(well, 'father'),
      "#{replicates}",
      "#{tissue_source}"
    ]
  end

  private
  def self.check_well_sample_exists(well)
    raise StandardError, "Sample not found for well #{well.id}" if well.primary_aliquot.nil?
  end

  def self.institute_plate_label(plate)
    plate.infinium_barcode
  end

  def self.well_map_description(well)
    description = well.map_description
    if description && description.size == 2
      return "#{description[0].chr}0#{description[1].chr}"
    end

    description || ""
  end

  def self.well_sample_parent(well, parent)
    check_well_sample_exists(well)
    well.primary_aliquot.sample.sample_metadata[parent].try(:to_i)
  end

  def self.well_sample_gender(well)
    check_well_sample_exists(well)
    gender = well.primary_aliquot.sample.sample_metadata.gender
    gender = "male" if gender == "M"
    gender = "female" if gender == "F"
    gender = "Unknown" if ! ["Male","Female", "male","female"].include?(gender)
    gender.downcase
  end

  def self.well_sample_is_control(well)
    check_well_sample_exists(well)
    control_value = well.primary_aliquot.sample.try(:control)
    if control_value == true
      1
    elsif control_value == false
      0
    else
      DEFAULT_IS_CONTROL
    end
  end

  def self.well_sample_species(well)
    check_well_sample_exists(well)
    well.primary_aliquot.sample.sample_metadata.sample_common_name || DEFAULT_SPECIES
  end

  def self.well_volume(well)
    volume = well.get_requested_volume.to_i
    volume = DEFAULT_VOLUME if volume == 0 || volume.nil?

    volume
  end

  def self.well_concentration(well)
    concentration = well.get_concentration.to_i
    concentration = DEFAULT_CONCENTRATION if concentration == 0 || concentration.nil?

    concentration
  end

  def self.construct_sample_label(plate_barcode, well)
    check_well_sample_exists(well)
    plate_barcode + "_" + well_map_description(well) + "_" + well.primary_aliquot.sample.sanger_sample_id
  end

  def self.create_header(csv_obj,study)
    now = Time.new
    csv_obj << ["Institute Name:", "WTSI","","","","","","","","","","","","","","","",""]
    csv_obj << ["Date:", "#{now.year}-#{now.month}-#{now.day}"]
    csv_obj << ["Comments:", "#{study.abbreviation}"]
    csv_obj << ["Row", "Institute Plate Label", "Well", "Is Control", "Institute Sample Label", "Species", "Sex", "Comments", "Volume (ul)", "Conc (ng/ul)", "Extraction Method", "WGA Method (if Applicable)", "Mass of DNA used in WGA", "Parent 1", "Parent 2", "Replicate(s)", "Tissue Source"]
  end

  def self.remove_empty_quotes(csv_string)
    csv_string.gsub!("#{QUOTE_CHAR}#{QUOTE_CHAR}", "")
  end

end

# Handles submission of {Study} information to the EGA or ENA
# A study gathers together multiple {Accessionable::Sample samples} and essentially
# describes why they are being sequenced. It should have a 1 to 1 mapping with Sequencescape
# {Study studies}.
# A study can either be open (ENA) or managed (EGA) which determines which {AccessionService} it
# uses.
module Accessionable
  class Study < Base
    attr_reader :study_title, :description, :center_study_name, :study_abstract, :existing_study_type, :tags
    def initialize(study)
      @study = study
      data = {}

      study_title = study.study_metadata.study_study_title
      @name = study_title.blank? ? '' : study_title.gsub(/[^a-z\d]/i, '_')

      study_type = study.study_metadata.study_type.name
      @existing_study_type = study_type # the study type if validated is exactly the one submission need

      @study_title = @name
      @center_study_name = @study_title

      pid = study.study_metadata.study_project_id
      @study_id = pid.presence || '0'

      study_abstract = study.study_metadata.study_abstract
      @study_abstract = study_abstract unless study_abstract.blank?

      study_desc = study.study_metadata.study_description
      @description = study_desc unless study_desc.blank?

      @tags = []
      @tags << Tag.new(label_scope, 'ArrayExpress', nil) if study.for_array_express?
      super(study.study_metadata.study_ebi_accession_number)
    end

    def errors
      error_list = []
    end

    def xml
      xml = Builder::XmlMarkup.new
      xml.instruct!
      xml.STUDY_SET('xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance') {
        xml.STUDY(alias: self.alias, accession: accession_number) {
          xml.DESCRIPTOR {
            xml.STUDY_TITLE         study_title
            xml.STUDY_DESCRIPTION   description
            xml.CENTER_PROJECT_NAME center_study_name
            xml.CENTER_NAME         center_name
            xml.STUDY_ABSTRACT      study_abstract

            xml.PROJECT_ID(accessionable_id || '0')
            study_type = existing_study_type
            if StudyType.include?(study_type)
              xml.STUDY_TYPE(existing_study_type: study_type)
            else
              xml.STUDY_TYPE(existing_study_type: ::Study::Other_type, new_study_type: study_type)
            end
          }
          xml.STUDY_ATTRIBUTES {
            tags.each do |tag|
              xml.STUDY_ATTRIBUTE {
                tag.build(xml)
              }
            end
          } unless tags.blank?
        }
      }
      xml.target!
    end

    def accessionable_id
      @study.id
    end

    def protect?(service)
      service.study_visibility(@study) == AccessionService::Protect
    end

    def update_accession_number!(user, accession_number)
      @accession_number = accession_number
      add_updated_event(user, "Study #{@study.id}", @study) if @accession_number
      @study.study_metadata.study_ebi_accession_number = accession_number
      @study.save!
    end

    def update_array_express_accession_number!(number)
      @study.study_metadata.array_express_accession_number = number
      @study.save!
    end
  end
end

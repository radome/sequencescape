# An aliquot can be considered to be an amount of a material in a liquid.  The material could be the DNA
# of a sample, or it might be a library (a combination of the DNA sample and a {Tag tag}).

# A note on tags:
# Aliquots can have up to two tags attached, the i7 (tag) and the i5(tag2)
# Tags are short DNA sequences which can be used to track samples following pooling.
# If two samples with the same tags are pooled together it becomes impossible to
# distinguish between them.
# To avoid this we have an index which ensures unique tags are maintained per pool.
# (Limitation: This restriction assumes that each oligo sequence is represented only once
# in the database. This is not the case, so additional slower checks are required where cross
# tag group pools are possible)
# MySQL indexes treat NULL values as non identical, so -1 (UNASSIGNED_TAG) is used to represent
# an untagged well.
# We have some performance optimizations in place to avoid trying to look up tag -1
# @see Tag
class Aliquot < ApplicationRecord
  include Uuid::Uuidable
  include Api::Messages::FlowcellIO::AliquotExtensions
  include Api::Messages::QcResultIO::AliquotExtensions
  include AliquotIndexer::AliquotScopes
  include Api::AliquotIO::Extensions
  include DataForSubstitution

  self.lazy_uuid_generation = true

  TagClash = Class.new(ActiveRecord::RecordInvalid)

  # An aliquot can represent a library, which is a processed sample that has been fragmented.  In which case it
  # has a receptacle that held the library aliquot and has an insert size describing the fragment positions.
  class InsertSize < Range
    alias_method :from, :first
    alias_method :to,   :last
  end

  TAG_COUNT_NAMES = %w[Untagged Single Dual]
  # It may have a tag but not necessarily.  If it does, however, that tag needs to be unique within the receptacle.
  # To ensure that there can only be one untagged aliquot present in a receptacle we use a special value for tag_id,
  # rather than NULL which does not work in MySQL.  It also works because the unassigned tag ID never gets matched
  # for a Tag and so the result is nil!
  UNASSIGNED_TAG = -1

  # An aliquot is held within a receptacle
  belongs_to :receptacle, inverse_of: :aliquots

  belongs_to :tag
  belongs_to :tag2, class_name: 'Tag'

  # An aliquot can belong to a study and a project.
  belongs_to :study
  belongs_to :project

  # An aliquot is an amount of a sample
  belongs_to :sample

  # It may have a bait library but not necessarily.
  belongs_to :bait_library, optional: true
  belongs_to :primer_panel

  # It can belong to a library asset
  belongs_to :library, class_name: 'Receptacle', optional: true

  belongs_to :request

  composed_of :insert_size, mapping: [%w{insert_size_from from}, %w{insert_size_to to}], class_name: 'Aliquot::InsertSize', allow_nil: true

  has_one :aliquot_index, dependent: :destroy

  convert_labware_to_receptacle_for :library, :receptacle

  before_validation { |record| record.tag_id ||= UNASSIGNED_TAG unless tag }
  before_validation { |record| record.tag2_id ||= UNASSIGNED_TAG unless tag2 }

  broadcast_via_warren

  scope :include_summary, -> { includes([:sample, { tag: :tag_group }, { tag2: :tag_group }]) }
  scope :in_tag_order, -> {
    joins(
      'LEFT OUTER JOIN tags AS tag1s ON tag1s.id = aliquots.tag_id,
       LEFT OUTER JOIN tags AS tag2s ON tag2s.id = aliquots.tag2_id'
    ).order('tag1s.map_id ASC, tag2s.map_id ASC')
  }
  scope :untagged, -> { where(tag_id: UNASSIGNED_TAG, tag2_id: UNASSIGNED_TAG) }
  scope :any_tags, -> { where.not(tag_id: UNASSIGNED_TAG, tag2_id: UNASSIGNED_TAG) }

  delegate :library_name, to: :library, allow_nil: true

  # returns a hash, where keys are cost_codes and values are number of aliquots related to particular cost code
  # {'cost_code_1' => 20, 'cost_code_2' => 3, 'cost_code_3' => 8 }
  # this one does not work, as project is not always there: joins(project: :project_metadata).group("project_metadata.project_cost_code").count
  def self.count_by_project_cost_code
    joins('LEFT JOIN projects ON aliquots.project_id = projects.id')
      .joins('LEFT JOIN project_metadata ON project_metadata.project_id = projects.id')
      .group('project_metadata.project_cost_code')
      .count
  end

  def aliquot_index_value
    aliquot_index.try(:aliquot_index)
  end

  def created_with_request_options
    {
      fragment_size_required_from: insert_size_from,
      fragment_size_required_to: insert_size_to,
      library_type: library_type
    }
  end

  # Validating the uniqueness of tags in rails was causing issues, as it was resulting the in the preform_transfer_of_contents
  # in transfer request to fail, without any visible sign that something had gone wrong. This essentially meant that tag clashes
  # would result in sample dropouts. (presumably because << triggers save not save!)
  def no_tag1?
    tag_id == UNASSIGNED_TAG || tag.nil?
  end

  def tag1?
    !no_tag1?
  end

  def no_tag2?
    tag2_id == UNASSIGNED_TAG || tag2.nil?
  end

  def tag2?
    !no_tag2?
  end

  def tags?
    !no_tags?
  end

  def no_tags?
    no_tag1? && no_tag2?
  end

  def tags_combination
    [tag.try(:oligo), tag2.try(:oligo)]
  end

  def tag_count_name
    TAG_COUNT_NAMES[tag_count]
  end

  # Optimization: Avoids us hitting the database for untagged aliquots
  def tag
    super unless tag_id == UNASSIGNED_TAG
  end

  def set_library
    self.library = receptacle
  end

  # Cloning an aliquot should unset the receptacle ID because otherwise it won't get reassigned.  We should
  # also reset the timestamp information as this is a new aliquot really.
  # Any options passed in as parameters will override the aliquot defaults
  def dup(params = {})
    super().tap do |cloned_aliquot|
      cloned_aliquot.assign_attributes(params)
    end
  end

  def update_quality(suboptimal_quality)
    self.suboptimal = suboptimal_quality
    save!
  end

  def matches?(object)
    # Note: This function is directional, and assumes that the downstream aliquot
    # is checking the upstream aliquot
    case
    when sample_id != object.sample_id                                                   then false # The samples don't match
    when object.library_id.present?      && (library_id      != object.library_id)       then false # Our librarys don't match.
    when object.bait_library_id.present? && (bait_library_id != object.bait_library_id)  then false # We have different bait libraries
    when (no_tag1? && object.tag1?) || (no_tag2? && object.tag2?)                        then raise StandardError, 'Tag missing from downstream aliquot' # The downstream aliquot is untagged, but is tagged upstream. Something is wrong!
    when object.no_tags? then true # The upstream aliquot was untagged, we don't need to check tags
    else (object.no_tag1? || (tag_id == object.tag_id)) && (object.no_tag2? || (tag2_id == object.tag2_id)) # Both aliquots are tagged, we need to check if they match
    end
  end

  # Unlike the above methods, which allow untagged to match with tagged, this looks for exact matches only
  # only id, timestamps and receptacles are excluded
  def equivalent?(other)
    %i[
      sample_id tag_id tag2_id library_id bait_library_id
      insert_size_from insert_size_to library_type project_id study_id
    ].all? do |attrib|
      send(attrib) == other.send(attrib)
    end
  end

  private

  def tag_count
    # Find the most highly tagged aliquot
    return 2 if tag2?
    return 1 if tag1?

    0
  end
end

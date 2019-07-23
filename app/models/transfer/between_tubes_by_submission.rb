class Transfer::BetweenTubesBySubmission < Transfer
  include TransfersToKnownDestination

  after_create :build_asset_links

  belongs_to :source, class_name: 'Tube'

  before_validation :ensure_destination_setup

  private

  def ensure_destination_setup
    self.destination = source.submission&.multiplexed_labware
    errors.add(:destination, 'could not be found.') if destination.nil?
  end

  after_create :update_destination_tube_name
  def update_destination_tube_name
    destination.update!(name: source.name_for_child_tube)
  end

  def each_transfer
    yield(source, destination)
  end

  def build_asset_links
    AssetLink::Job.create(source, [destination])
  end
end

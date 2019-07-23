class Submission::PresenterSkeleton
  class_attribute :attributes, instance_writer: false
  self.attributes = Array.new

  delegate :not_ready_samples_names, to: :submission

  def initialize(user, submission_attributes = {})
    submission_attributes = {} if submission_attributes.blank?

    @user = user

    attributes.each do |attribute|
      send("#{attribute}=", submission_attributes[attribute])
    end
  end

  # id accessors need to be explicitly defined...
  attr_reader :id

  attr_writer :id

  def lanes_of_sequencing
    return lanes_from_request_options if %{building pending}.include?(submission.state)

    lanes_from_request_counting
  end

  def cross_compatible?
  end

  def each_submission_warning(&block)
    submission.each_submission_warning(&block)
  end

  protected

  def method_missing(name, *args, &block)
    name_without_assignment = name.to_s.sub(/=$/, '').to_sym
    return super unless attributes.include?(name_without_assignment)

    instance_variable_name = :"@#{name_without_assignment}"
    return instance_variable_get(instance_variable_name) if name_without_assignment == name.to_sym

    instance_variable_set(instance_variable_name, args.first)
  end

  private

  def lanes_from_request_options
    return order.request_options.fetch(:multiplier, {}).values.last || 1 if order.request_types[-2].nil?

    sequencing_request = RequestType.find(order.request_types.last)
    multiplier_hash = order.request_options.fetch(:multiplier, {})
    sequencing_multiplier = (multiplier_hash[sequencing_request.id.to_s] || multiplier_hash.fetch(sequencing_request.id, 1)).to_i

    if order.multiplexed?
      sequencing_multiplier
    else
      order.assets.count * sequencing_multiplier
    end
  end

  def lanes_from_request_counting
    submission.requests.where_is_a(SequencingRequest).count
  end
end

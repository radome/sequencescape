module Batch::PipelineBehaviour
  def self.included(base)
    base.class_eval do
      # The associations with the pipeline
      belongs_to :pipeline
      delegate :workflow, :item_limit, :multiplexed?, to: :pipeline
      delegate :tasks, to: :workflow

      # The validations that the pipeline & batch are correct
      validates_presence_of :pipeline

      # Validation of some of the batch information is left to the pipeline that it belongs to
      validate do |record|
        record.pipeline.validation_of_batch(record) if record.pipeline.present?
      end

      # The batch requires positions on it's requests if the pipeline does
      delegate :requires_position?, to: :pipeline

      # Ensure that the batch is valid to be marked as completed
      validate(if: :completed?) do |record|
        record.pipeline.validation_of_batch_for_completion(record)
      end
    end
  end

  def show_actions?
    return true if pipeline.is_a?(CherrypickForPulldownPipeline)

    !released?
  end

  def has_item_limit?
    item_limit.present?
  end
  alias_method(:has_limit?, :has_item_limit?)

  def last_completed_task
    pipeline.workflow.tasks.order(:sorted).where(id: completed_task_ids).last unless complete_events.empty?
  end

  private

  def complete_events
    @efct ||= if lab_events.loaded
                lab_events.select { |le| le.description == 'Complete' }
              else
                lab_events.where(description: 'Complete')
              end
  end

  def completed_task_ids
    complete_events.map do |lab_event|
      lab_event.descriptor_hash['task_id']
    end.compact
  end
end

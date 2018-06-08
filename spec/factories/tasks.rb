# frozen_string_literal: true
FactoryBot.define do
  factory :task do
    name        'New task'
    association(:workflow, factory: :lab_workflow)
    sorted      nil
    batched     nil
    location    ''
    interactive nil
  end

  factory :cherrypick_task do
    sequence(:name)      { |n| "CherryPickTask #{n}" }
    pipeline_workflow_id { |workflow| workflow.association(:lab_workflow) }
    sorted                nil
    location              ''
    batched               true
    interactive           nil
    lab_activity          true
  end

  factory :fluidigm_template_task do
    sequence(:name)      { |n| "FluidigmTemplateTask #{n}" }
    pipeline_workflow_id { |workflow| workflow.association(:lab_workflow) }
    sorted                nil
    location              ''
    batched               true
    interactive           nil
    lab_activity          true
  end

  factory :plate_template_task do
    sequence(:name)      { |n| "PlateTemplateTask #{n}" }
    pipeline_workflow_id { |workflow| workflow.association(:lab_workflow) }
    sorted                nil
    location              ''
    batched               true
    interactive           nil
    lab_activity          true
  end
end

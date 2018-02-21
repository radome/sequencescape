# frozen_string_literal: true

# This file is part of SEQUENCESCAPE is distributed under the terms of GNU General Public License version 1 or later;
# Please refer to the LICENSE and README files for information on licensing and
# authorship of this file.
# Copyright (C) 2011,2012 Genome Research Ltd.
FactoryGirl.define do
  factory :submission__ do
    user
    factory :submission_without_order
  end

  factory :submission do
    user  { |user| user.association(:user) }
  end

  factory :submission_template do
    submission_class_name LinearSubmission.name
    name                  'my_template'

    transient do
      request_type_ids_list []
    end
    submission_parameters { { request_type_ids_list: request_type_ids_list } }
    product_catalogue { |pc| pc.association(:single_product_catalogue) }

    factory :limber_wgs_submission_template do
      transient do
        request_types { [create(:library_request_type)] }
      end
      sequence(:name) { |i| "Template #{i}" }
      submission_parameters do
        {
          request_type_ids_list: request_types.map { |rt| [rt.id] }
        }
      end
    end
  end

  factory :order do
    transient do
      request_types_list { create_list(:request_type, 1) }
    end
    study
    project
    user
    item_options          {}
    request_options       {}
    assets                { create_list(:sample_tube, 1) }
    request_types         { request_types_list.map { |rt| rt.id } }

    factory :order_with_submission do
      after(:build) { |o| o.create_submission(user_id: o.user_id) }
    end

    factory :library_order do
      transient do
        library_type { request_types_list.first.library_types.first.name }
      end
      request_options { { fragment_size_required_from: 100, fragment_size_required_to: 200, library_type: library_type } }
    end
  end

  # Builds a submission on the provided assets suitable for processing through
  # an external library pipeline such as Limber
  # Note: Not yet complete. (Just in case something crops up before I finish this!)
  factory :library_submission, class: Submission do
    transient do
      assets { [create(:well)] }
      request_types { [create(:library_request_type), create(:multiplex_request_type)] }
    end

    user
    after(:build) do |submission, evaluator|
      submission.orders << build(:library_order, assets: evaluator.assets, request_types_list: evaluator.request_types)
    end
  end
end

class FactoryHelp
  def self.submission(options)
    submission_options = {}
    [:message, :state].each do |option|
      value = options.delete(option)
      submission_options[option] = value if value
    end
    submission = FactoryGirl.create(:order_with_submission, options).submission
    # trying to skip StateMachine
    submission.update_attributes!(submission_options) if submission_options.present?
    submission.reload
  end
end

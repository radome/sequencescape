# frozen_string_literal: true

Then /^every sample in study "([^"]*)" should be accessible via a request$/ do |study_name|
  study = Study.find_by(name: study_name)
  request_samples = study.requests.map(&:asset).map(&:sample)
  assert_equal request_samples.sort, study.samples.sort
end

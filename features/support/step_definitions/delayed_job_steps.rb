# frozen_string_literal: true

Given '{int} pending delayed jobs are processed' do |count|
  Delayed::Worker.new(quiet: ENV['LOUD_DELAYED_JOBS'].nil?).work_off(count)
  errors = Delayed::Job.all.map { |j| j.run_at? && j.last_error }.reject(&:blank?)
  raise StandardError, "Delayed jobs have failed #{errors.to_yaml}" if errors.present?
  raise StandardError, "There are #{Delayed::Job.count} jobs left to process" unless Delayed::Job.count.zero?
end

Given /^all pending delayed jobs (?:are|have been) processed$/ do
  count = Delayed::Job.count
  raise StandardError, 'There are no delayed jobs to process!' if count.zero?

  step("#{count} pending delayed jobs are processed")
end

Then /^the last delayed job should have a priority of (\d+)$/ do |priority|
  assert_equal(priority.to_i, Delayed::Job.last.priority)
end

Then /^there should be no delayed jobs to be processed$/ do
  assert_equal(0, Delayed::Job.count, 'there are delayed jobs to be processed')
end

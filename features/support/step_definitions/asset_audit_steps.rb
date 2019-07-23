# frozen_string_literal: true

Given /^asset audit with ID (\d+) is for plate with ID (\d+)$/ do |asset_audit_id, plate_id|
  AssetAudit.find(asset_audit_id).update!(asset: Plate.find(plate_id))
end

Given /^the barcode for plate (\d+) is "([^"]*)"$/ do |plate_id, barcode|
  Plate.find(plate_id).primary_barcode.update!(barcode: barcode)
end

Then /^the activity logging table should be:$/ do |expected_results_table|
  expected_results_table.diff!(table(fetch_table('table#asset_audits')))
end

# frozen_string_literal: true

# Autogenerated migration to convert request_types_extended_validators to utf8mb4
class MigrateRequestTypesExtendedValidatorsToUtf8mb4 < ActiveRecord::Migration[5.1]
  include MigrationExtensions::EncodingChanges

  def change
    change_encoding('request_types_extended_validators', from: 'utf8', to: 'utf8mb4')
  end
end

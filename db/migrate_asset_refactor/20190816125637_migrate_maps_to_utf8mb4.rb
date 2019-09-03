# frozen_string_literal: true

# Autogenerated migration to convert maps to utf8mb4
class MigrateMapsToUtf8mb4 < ActiveRecord::Migration[5.1]
  include MigrationExtensions::EncodingChanges

  def change
    change_encoding('maps', from: 'latin1', to: 'utf8mb4')
  end
end

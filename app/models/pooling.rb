# frozen_string_literal: true

# Used by {PoolingsController} to take multiple scanned {Tube} barcodes containing
# one or more {Aliquot aliquots} and use them to generate a new {MultiplexedLibraryTube}
class Pooling
  include ActiveModel::Model

  attr_writer :barcodes, :source_assets
  attr_accessor :stock_mx_tube_required, :stock_mx_tube, :standard_mx_tube, :barcode_printer, :count

  validates :source_assets, presence: { message: 'were not scanned or were not found in Sequencescape' }
  validate :all_source_assets_are_in_sqsc, if: :source_assets?
  validate :source_assets_can_be_pooled, if: :source_assets?
  validate :expected_numbers_found, if: :source_assets?

  def execute
    return false unless valid?

    @stock_mx_tube = Tube::Purpose.stock_mx_tube.create!(name: '(s)') if stock_mx_tube_required?
    @standard_mx_tube = Tube::Purpose.standard_mx_tube.create!
    transfer
    execute_print_job
    true
  end

  def transfer
    target_assets.each do |target_asset|
      source_assets.each do |source_asset|
        TransferRequest.create!(asset: source_asset, target_asset: target_asset)
      end
    end
    message[:notice] = (message[:notice] || '') + success
  end

  def source_assets
    @source_assets ||= find_source_assets
  end

  def target_assets
    @target_assets ||= [stock_mx_tube, standard_mx_tube].compact
  end

  def barcodes
    @barcodes || []
  end

  def stock_mx_tube_required?
    stock_mx_tube_required.present?
  end

  def print_job_required?
    barcode_printer.present?
  end

  def print_job
    @print_job ||= LabelPrinter::PrintJob.new(barcode_printer,
                                              LabelPrinter::Label::MultiplexedTube,
                                              assets: target_assets, count: count)
  end

  def message
    @message ||= {}
  end

  def tag_clash_report
    @tag_clash_report ||= Pooling::TagClashReport.new(self)
  end

  private

  def tag_clash?
    tag_clash_report.tag_clash?
  end

  def source_assets?
    source_assets.present?
  end

  def find_source_assets
    Labware.includes(aliquots: %i[tag tag2 library]).with_barcode(barcodes)
  end

  # Returns a list of scanned barcodes which could not be found in Sequencescape
  # This allows ANY asset barcode to match, either via human or machine readable formats
  # =~ is a fuzzy matcher
  def assets_not_in_sqsc
    @assets_not_in_sqsc ||= barcodes.reject do |barcode|
      found_barcodes.detect { |found_barcode| found_barcode =~ barcode }
    end
  end

  def found_barcodes
    source_assets.flat_map(&:barcodes)
  end

  def all_source_assets_are_in_sqsc
    errors.add(:source_assets, "with barcode(s) #{assets_not_in_sqsc.join(', ')} were not found in Sequencescape") if assets_not_in_sqsc.present?
  end

  def expected_numbers_found
    errors.add(:source_assets, "found #{source_assets.length} assets, but #{barcodes.length} barcodes were scanned.") if source_assets.length != barcodes.length
  end

  def source_assets_can_be_pooled
    assets_with_no_aliquot = []
    source_assets.each do |asset|
      assets_with_no_aliquot << asset.machine_barcode if asset.aliquots.empty?
    end
    errors.add(:source_assets, "with barcode(s) #{assets_with_no_aliquot.join(', ')} do not have any aliquots") if assets_with_no_aliquot.present?
    errors.add(:tags_combinations, 'are not compatible and result in a tag clash') if tag_clash?
  end

  def execute_print_job
    return unless print_job_required?

    if print_job.execute
      message[:notice] = (message[:notice] || '') + print_job.success
    else
      message[:error] = (message[:error] || '') + print_job.errors.full_messages.join('; ')
    end
  end

  def success
    "Samples were transferred successfully to standard_mx_tube #{standard_mx_tube.human_barcode} " +
      ("and stock_mx_tube #{stock_mx_tube.human_barcode} " if stock_mx_tube.present?).to_s
  end
end

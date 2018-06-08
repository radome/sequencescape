# Base class for the all tube purposes
class Tube::Purpose < ::Purpose
  self.default_prefix = 'NT'
  # TODO: change to purpose_id
  has_many :tubes, foreign_key: :plate_purpose_id

  # We use a lambda here as most tube subclasses won't be loaded at the point of evaluation. We'll
  # be performing this check so rarely that the performance hit is negligable.
  validates :target_type, presence: true, inclusion: { in: ->(_) { Tube.descendants.map(&:name) << 'Tube' } }
  before_validation :set_default_printer_type
  # Tubes of the general types have no stock plate!
  def stock_plate(_)
    nil
  end

  def library_source_plates(_)
    []
  end

  def create!(*args, &block)
    options = args.extract_options!
    options[:purpose] = self
    options[:barcode_prefix] ||= barcode_prefix
    target_class.create_with_barcode!(*args, options, &block).tap { |t| tubes << t }
  end

  def sibling_tubes(_tube)
    nil
  end

  def self.standard_library_tube
    name = 'Standard library'
    create_with(
      name: name,
      target_type: 'LibraryTube',
      prefix: 'NT'
    ).find_or_create_by(name: name)
  end

  def self.standard_sample_tube
    name = 'Standard sample'
    create_with(
      name: name,
      target_type: 'SampleTube',
      prefix: 'NT'
    ).find_or_create_by(name: name)
  end

  def self.standard_mx_tube
    name = 'Standard MX'
    Tube::StandardMx.create_with(
      name: name,
      target_type: 'MultiplexedLibraryTube',
      prefix: 'NT'
    ).find_or_create_by(name: name)
  end

  def self.stock_library_tube
    name = 'Stock library'
    create_with(
      name: name,
      target_type: 'StockLibraryTube',
      prefix: 'NT'
    ).find_or_create_by(name: name)
  end

  def self.stock_mx_tube
    name = 'Stock MX'
    Tube::StockMx.create_with(
      name: name,
      target_type: 'StockMultiplexedLibraryTube',
      prefix: 'NT'
    ).find_or_create_by(name: name)
  end

  private

  def set_default_printer_type
    self.barcode_printer_type ||= BarcodePrinterType1DTube.first
  end
end

require_dependency 'qcable_tube_purpose'
require_dependency 'illumina_c/qc_pool_purpose'
require_dependency 'illumina_htp/mx_tube_purpose'
require_dependency 'illumina_htp/stock_tube_purpose'
require_dependency 'tube/standard_mx'
require_dependency 'tube/stock_mx'

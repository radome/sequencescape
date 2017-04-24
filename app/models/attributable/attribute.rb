module Attributable
    class Attribute
    attr_reader :name
    attr_reader :default

    alias_method :assignable_attribute_name, :name

    def initialize(owner, name, options = {})
      @owner, @name, @options = owner, name.to_sym, options
      @default  = options.delete(:default)
      @required = options.delete(:required).present?
      @validator = options.delete(:validator).present?
    end

    def from(record)
      record[name]
    end

    def default_from(origin = nil)
      return nil if origin.nil?
      return origin.validator_for(name).default if validator?
    end

    def validator?
      @validator
    end

    def required?
      @required
    end

    def optional?
      not required?
    end

    def integer?
      @options.fetch(:integer, false)
    end

    def float?
      @options.fetch(:positive_float, false)
    end

    def boolean?
      @options.key?(:boolean)
    end

    def fixed_selection?
      @options.key?(:in)
    end

    def selection?
      fixed_selection? || @options.key?(:selection)
    end

    def minimum
      @options.fetch(:minimum, 0)
    end

    def selection_values
      @options[:in]
    end

    def valid_format
      @options[:with]
    end

    def valid_format?
      valid_format
    end

    def configure(model)
      conditions = @options.slice(:if)
      save_blank_value = @options.delete(:save_blank)
      allow_blank = save_blank_value

      model.with_options(conditions) do |object|
        # false.blank? == true, so we exclude booleans here, they handle themselves further down.
        object.validates_presence_of(name) if required? && !boolean?
        object.with_options(allow_nil: optional?, allow_blank: allow_blank) do |required|
          required.validates_inclusion_of(name, in: [true, false]) if boolean?
          required.validates_numericality_of(name, only_integer: true, greater_than: minimum) if integer?
          required.validates_numericality_of(name, greater_than: 0) if float?
          required.validates_inclusion_of(name, in: selection_values, allow_false: true) if fixed_selection?
          required.validates_format_of(name, with: valid_format) if valid_format?
          required.validates name, custom: true if validator?
        end
      end

      unless save_blank_value
        model.class_eval("
          before_validation do |record|
            value = record.#{name}
            record.#{name}= nil if value and value.blank?
          end
        ")
      end

      unless (condition = conditions[:if]).nil?
        model.class_eval("
          before_validation do |record|
            record.#{name}= nil unless record.#{condition}
          end
        ")
      end
    end

    def self.find_display_name(klass, name)
      translation = I18n.t("metadata.#{klass.name.underscore.tr('/', '.')}.#{name}")
      if translation.is_a?(Hash) # translation found, we return the label
        return translation[:label]
      else
        superclass = klass.superclass
        if superclass != ActiveRecord::Base # a subclass , try the superclass name scope
          return find_display_name(superclass, name)
        else # translation not found
          return translation # shoulb be an error message, so that's ok
        end
      end
    end

    def display_name
      Attribute::find_display_name(@owner, name)
    end

    def find_default(object = nil, metadata = nil)
      default_from(metadata) || object.try(name) || default
    end

    def kind
      return FieldInfo::SELECTION if selection?
      return FieldInfo::BOOLEAN if boolean?
      return FieldInfo::NUMERIC if integer? || float?
      FieldInfo::TEXT
    end

    def selection_from_metadata(metadata)
      return nil unless metadata.present?
      return metadata.validator_for(name).valid_options.to_a if validator?
    end

    def selection_options(metadata)
      selection_values || selection_from_metadata(metadata) || []
    end

    def to_field_info(object = nil, metadata = nil)
      options = {
        # TODO[xxx]: currently only working for metadata, the only place attributes are used
        display_name: display_name,
        key: assignable_attribute_name,
        default_value: find_default(object, metadata),
        kind: kind,
        required: required?
      }
      options.update(selection: selection_options(metadata)) if selection?
      options.update(step: 1, min: minimum) if integer?
      options.update(step: 0.1, min: 0) if float?
      FieldInfo.new(options)
    end
  end
end

require 'set'

module SettingsManagement
  extend ActiveSupport::Concern

  included do
    serialize :settings

    class << self
      attr_accessor :setter_columns
    end

    self.setter_columns = Set.new

    before_save :set_default_settings
    before_save :index_settings_columns
  end

  # A way for providing a configuration mechanism for
  # generating getters / setters which get delegated to
  # the serialized column.
  module ClassMethods
    def setters *columns
      options       = columns.extract_options!
      default_value = options.fetch(:default, nil)
      settings      = options.fetch(:column,:settings)

      columns.each do |column|
        self.setter_columns << column

        define_method("#{ column }".to_sym) do
          send(settings).fetch(column, default_value)
        end

        define_method("#{ column }=".to_sym) do |value|
          send(settings).send(:[]=, column, value)
        end
      end
    end
  end

  def index_settings_columns
    true
  end

  def set_default_settings
    self.settings ||= {}
  end

end

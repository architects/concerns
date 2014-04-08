require 'set'

module DataColumn
  extend ActiveSupport::Concern

  included do
    serialize :data, Hashie::Mash

    class << self
      attr_accessor :data_setter_columns
    end

    self.data_setter_columns = Set.new

    before_save :set_default_data
    before_save :index_data_columns
  end

  # A way for providing a configuration mechanism for
  # generating getters / setters which get delegated to
  # the serialized column.
  module ClassMethods
    def data_setters *columns
      options       = columns.extract_options!
      default_value = options.fetch(:default, nil)
      data          = options.fetch(:column,:data)

      columns.each do |column|
        self.data_setter_columns << column

        define_method("#{ column }".to_sym) do
          send(data).fetch(column, default_value)
        end

        define_method("#{ column }=".to_sym) do |value|
          send(data).send(:[]=, column, value)
        end
      end
    end
  end

  def index_data_columns
    true
  end

  def set_default_data
    self.data ||= {}
  end

end

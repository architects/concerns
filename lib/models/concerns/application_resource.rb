# The `ApplicationResource` helper is where I put common patterns found
# in ActiveRecord::Base model classes, usually based on column naming conventions
#
# It also makes the FilterContext and ApplicationCommand classes provided by the datapimp gem
# available through naming conventions as well.
module ApplicationResource
  extend ActiveSupport::Concern

  included do
    cols = column_names

    include Datapimp if defined?(Datapimp)
    include Stateflow if defined?(Stateflow) && cols.include?("state")

    include ReferenceUris if cols.include?("reference_uris")
    include SettingsManagement if cols.include?("settings")
    include DataColumn if cols.include?("data")

    before_validation :set_defaults

    # Creates a convenience alias for self. Brief => brief, Blueprint => blueprint, User => user
    define_method(table_name.singularize.downcase) do
      self
    end
  end

  def set_defaults
    true
  end
end

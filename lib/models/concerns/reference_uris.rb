# Provides syntactic sugar and other helpful methods for models which
# reference other things by a URI (web, file or otherwise)
module ReferenceUris
  extend ActiveSupport::Concern

  included do
    serialize :reference_uris, JSON

    before_validation do |obj|
      obj.reference_uris ||= {}
    end
  end

  def links
    @links ||= Hashie::Mash.new(reference_uris)
  end

  module ClassMethods
    def references_urls *list
      list.each do |meth|
        define_method("#{ meth }_path=") do |value|
          value = value.to_s
          self.reference_uris ||= {}
          value = "file://#{ value }" unless value.match(/^file/)
          self.send("#{ meth }_url=", value)
        end

        define_method("#{ meth }_path") do
          self.send("#{ meth }_uri").try(:path)
        end

        define_method("#{ meth }_uri") do
          url = self.send("#{ meth }_url")
          URI.parse(url)
        end

        define_method("#{ meth }_url") do
          reference_uris.fetch(meth.to_s, nil)
        end

        define_method("#{ meth }_url=") do |value|
          self.reference_uris ||= {}
          reference_uris[meth] = value
        end
      end
    end
  end
end

# Localizes attribute names for error.full_message WITHOUT i18n. Each including
# model defines a HUMAN_ATTRS hash (attribute string => Spanish label); unmapped
# attributes fall back to the Rails default humanization.
module SpanishAttributeNames
  extend ActiveSupport::Concern

  class_methods do
    def human_attribute_name(attribute, options = {})
      self::HUMAN_ATTRS.fetch(attribute.to_s) { super }
    end
  end
end

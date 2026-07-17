# Classifies flat error strings from SaleCreationService (and Sale model
# validations) into contextual buckets so the form can render them inline
# beside the relevant field/section instead of as a flat global list.
#
# Strategy: Spanish keyword matching within the service's error domain.
# "cliente" → :cliente, "almacén" → :almacen, "cuota"/"monto"/"suma" → :cuotas,
# everything else → :general.
module SaleErrorHelper
  CUOTAS_KEYWORDS = %w[cuota monto suma].freeze

  # Returns a hash of symbol-keyed arrays:
  #   { cliente: [...], almacen: [...], cuotas: [...], general: [...] }
  def self.classify(errors, sale)
    groups = { cliente: [], almacen: [], cuotas: [], general: [] }

    flat = Array(errors).map(&:to_s)

    flat.each do |message|
      key = classify_one(message)
      groups[key] << message
    end

    # Fold in Sale model validation errors (ActiveModel errors with Spanish messages)
    Array(sale&.errors&.full_messages).each do |msg|
      key = classify_one(msg)
      # Avoid duplicating the same message
      groups[key] << msg unless groups[key].include?(msg)
    end

    groups
  end

  def self.classify_one(message)
    lower = message.downcase

    return :cliente if lower.include?("cliente")
    return :almacen if lower.include?("almacén") || lower.include?("almacen")

    CUOTAS_KEYWORDS.each do |kw|
      return :cuotas if lower.include?(kw)
    end

    :general
  end

  private_class_method :classify_one
end

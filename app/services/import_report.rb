# ImportReport — collects per-row outcomes from a bulk import operation.
#
# Usage:
#   report = ImportReport.new
#   report.add_created(fila: 1)
#   report.add_duplicate(fila: 2, razon: 'SKU duplicado')
#   report.add_invalid(fila: 3, errores: ['Nombre no puede estar en blanco'])
#   report.created_count  # => 1
#   report.error_count    # => 2
#   report.rows           # => [{ fila:, status:, errores: }, ...]
class ImportReport
  attr_reader :created_count, :error_count, :rows

  def initialize
    @created_count = 0
    @error_count   = 0
    @rows          = []
  end

  def add_created(fila:)
    @created_count += 1
    @rows << { fila: fila, status: :created, errores: [] }
  end

  def add_duplicate(fila:, razon:)
    @error_count += 1
    @rows << { fila: fila, status: :duplicate, errores: [ razon ] }
  end

  def add_invalid(fila:, errores:)
    @error_count += 1
    @rows << { fila: fila, status: :invalid, errores: Array(errores) }
  end
end

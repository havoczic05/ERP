# Importers::BaseImporter — shared read/report loop for CSV/XLSX importers.
#
# Subclasses must implement:
#   #process_row(hash, fila, report)
#     hash   — header→value Hash for this data row (strings trimmed, numerics preserved)
#     fila   — 1-based data-row number (header excluded)
#     report — ImportReport instance; call report.add_created/add_duplicate/add_invalid
#
# Returns a Result PORO:
#   result.success? => true  — result.record is an ImportReport
#   result.success? => false — result.errors contains the rejection reason (file-level error)
module Importers
  class BaseImporter
    def self.call(path, content_type:)
      new(path, content_type: content_type).call
    end

    def initialize(path, content_type:)
      @path         = path
      @content_type = content_type
    end

    def call
      report = ImportReport.new

      reader_result = SpreadsheetReader.call(@path, content_type: @content_type) do |hash, fila|
        begin
          process_row(hash, fila, report)
        rescue => e
          # An unexpected error in process_row must not abort the whole import.
          # Record the row as invalid so the error is visible in the report, then
          # continue with the next row (per-row partial-save contract).
          report.add_invalid(fila: fila, errores: [ "Error inesperado al procesar la fila: #{e.message}" ])
        end
      end

      return reader_result unless reader_result.success?

      Result.success(report)
    end

    private

    # Subclasses override this to implement per-entity mapping and persistence.
    def process_row(hash, fila, report)
      raise NotImplementedError, "#{self.class}#process_row must be implemented"
    end
  end
end

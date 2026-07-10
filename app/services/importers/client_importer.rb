# Importers::ClientImporter — maps CSV/XLSX rows to Client records.
#
# Expected CSV/XLSX headers (must match ClientsController::CSV_HEADERS):
#   Nombre completo, Tipo de documento, Número de documento,
#   Teléfono, Dirección, Distrito, Provincia, Departamento
#
# Per-row behavior:
#   - document_type free-text ("RUC"/"DNI", case-insensitive) → enum value.
#     Unrecognized value → row error (Spanish).
#   - Duplicate check by document_number against Client.kept.
#   - Validates via Client model; invalid attrs → row error with Spanish messages.
#   - Partial save: each row is saved independently (no file-level transaction).
module Importers
  class ClientImporter < BaseImporter
    # Accepted document_type strings → enum values (Client model uses lowercase)
    DOCUMENT_TYPE_MAP = {
      "ruc" => "ruc",
      "dni" => "dni"
    }.freeze

    # Error messages (Spanish, hardcoded)
    MSG_DUPLICATE      = "Número de documento duplicado".freeze
    MSG_UNKNOWN_TYPE   = "Tipo de documento no reconocido".freeze

    private

    def process_row(hash, fila, report)
      document_number = hash["Número de documento"].to_s.strip
      raw_type        = hash["Tipo de documento"].to_s.strip.downcase
      document_type   = DOCUMENT_TYPE_MAP[raw_type]

      # Unknown document_type — reject before any DB check
      unless document_type
        report.add_invalid(fila: fila, errores: [ MSG_UNKNOWN_TYPE ])
        return
      end

      # Duplicate check — by document_number among kept clients
      if Client.kept.where(document_number: document_number).exists?
        report.add_duplicate(fila: fila, razon: MSG_DUPLICATE)
        return
      end

      # Build and attempt to save
      client = Client.new(
        full_name:       hash["Nombre completo"].to_s.strip,
        document_type:   document_type,
        document_number: document_number,
        phone:           hash["Teléfono"].to_s.strip,
        direccion:       hash["Dirección"].to_s.strip,
        distrito:        hash["Distrito"].to_s.strip,
        provincia:       hash["Provincia"].to_s.strip,
        departamento:    hash["Departamento"].to_s.strip
      )

      if client.save
        report.add_created(fila: fila)
      else
        report.add_invalid(fila: fila, errores: client.errors.full_messages)
      end
    end
  end
end

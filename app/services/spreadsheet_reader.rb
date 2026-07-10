# SpreadsheetReader — opens a CSV or XLSX file with roo and yields each data
# row as a header→value hash plus a 1-based row number (fila).
#
# Usage:
#   result = SpreadsheetReader.call(path, content_type: uploaded_file.content_type) do |hash, fila|
#     # hash  — { "SKU" => "ABC001", "Stock" => 10, ... } (strings trimmed)
#     # fila  — 1-based data-row number (header row excluded)
#   end
#   result.success?  # => true / false
#   result.errors    # => ["El archivo debe ser CSV (.csv) o Excel (.xlsx)."] on rejection
#
# Validations applied before yielding any row:
#   1. Extension must be .csv or .xlsx.
#   2. Content-type must be one of the accepted MIME types for the detected format.
#   3. File must not contain more than 500 data rows.
require "roo"

class SpreadsheetReader
  MAX_ROWS = 500

  ACCEPTED_EXTENSIONS = %w[.csv .xlsx].freeze

  ACCEPTED_CONTENT_TYPES = {
    ".csv"  => %w[text/csv text/plain application/csv].freeze,
    ".xlsx" => %w[application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
                  application/vnd.ms-excel].freeze
  }.freeze

  # Error messages (Spanish, hardcoded — no i18n per project convention)
  MSG_INVALID_FORMAT = "El archivo debe ser CSV (.csv) o Excel (.xlsx).".freeze
  MSG_OVER_CAP       = "El archivo supera el límite de #{MAX_ROWS} filas. Divídalo en archivos más pequeños.".freeze
  MSG_EMPTY_FILE     = "El archivo está vacío.".freeze

  def self.call(path, content_type:, &block)
    new(path, content_type: content_type).call(&block)
  end

  def initialize(path, content_type:)
    @path         = path
    @content_type = content_type.to_s.split(";").first.to_s.strip.downcase
    @ext          = File.extname(path.to_s).downcase
  end

  def call
    unless valid_format?
      return Result.failure(nil, [ MSG_INVALID_FORMAT ])
    end

    sheet = open_sheet

    # Guard: roo returns nil for last_row on a truly empty sheet (e.g. empty XLSX),
    # or 1 with all-nil row(1) values for a 0-byte CSV. Both cases are empty files.
    if sheet.last_row.nil? || sheet.row(1).all?(&:nil?)
      return Result.failure(nil, [ MSG_EMPTY_FILE ])
    end

    data_row_count = sheet.last_row - 1  # subtract header row

    if data_row_count > MAX_ROWS
      return Result.failure(nil, [ MSG_OVER_CAP ])
    end

    headers = sheet.row(1).map { |h| h.to_s.strip }

    (2..sheet.last_row).each do |row_num|
      raw_row = sheet.row(row_num)
      hash    = build_hash(headers, raw_row)
      fila    = row_num - 1  # 1-based data-row number
      yield hash, fila
    end

    Result.success(nil)
  end

  private

  def valid_format?
    return false unless ACCEPTED_EXTENSIONS.include?(@ext)

    accepted = ACCEPTED_CONTENT_TYPES.fetch(@ext, [])
    accepted.include?(@content_type)
  end

  def open_sheet
    ext_sym = @ext.delete(".").to_sym  # :csv or :xlsx
    Roo::Spreadsheet.open(@path, extension: ext_sym)
  end

  # Build header→value hash with string coercion + trim for text cells,
  # numeric values preserved as-is for typed cells (XLSX).
  def build_hash(headers, raw_row)
    headers.each_with_index.with_object({}) do |(header, i), hash|
      val = raw_row[i]
      hash[header] = coerce_cell(val)
    end
  end

  def coerce_cell(val)
    case val
    when Numeric
      val  # preserve numeric type (XLSX typed cells)
    when String
      val.strip
    when NilClass
      nil
    else
      val.to_s.strip
    end
  end
end

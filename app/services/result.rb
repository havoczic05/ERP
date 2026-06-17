# Lightweight Result PORO returned by service objects.
#
# Primary interface:
#   Result.success(record)          → result.record, result.success? == true
#   Result.failure(record, errors)  → result.record, result.errors, result.failure? == true
#
# Backward-compatible alias:
#   result.sale  →  same as result.record  (Sales callers unchanged)
class Result
  attr_reader :record, :errors

  # Accept both record: and sale: keywords so any direct Result.new call keeps working.
  # record: wins when both are supplied.
  def initialize(success:, record: nil, sale: nil, errors: [])
    @success = success
    @record  = record.nil? ? sale : record
    @errors  = Array(errors)
  end

  # Backward-compatible alias kept so Sales callers need zero changes.
  def sale
    @record
  end

  def success?
    @success
  end

  def failure?
    !@success
  end

  def self.success(record)
    new(success: true, record: record, errors: [])
  end

  def self.failure(record = nil, errors = [])
    new(success: false, record: record, errors: Array(errors))
  end
end

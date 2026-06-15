# Lightweight Result PORO returned by service objects.
# Usage:
#   Result.success(sale)          → result.success? == true
#   Result.failure(sale, errors)  → result.success? == false
class Result
  attr_reader :sale, :errors

  def initialize(success:, sale: nil, errors: [])
    @success = success
    @sale    = sale
    @errors  = Array(errors)
  end

  def success?
    @success
  end

  def failure?
    !@success
  end

  def self.success(sale)
    new(success: true, sale: sale, errors: [])
  end

  def self.failure(sale = nil, errors = [])
    new(success: false, sale: sale, errors: Array(errors))
  end
end

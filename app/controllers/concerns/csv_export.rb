# Reusable CSV export for index actions. Builds a CSV from headers + rows and
# sends it inline (opens in a new tab via the export_link helper). No new gem
# beyond Ruby's own `csv`.
module CsvExport
  extend ActiveSupport::Concern

  private

  def send_csv(name, headers, rows)
    csv = CSV.generate(headers: true) do |out|
      out << headers
      rows.each { |row| out << row }
    end

    send_data csv,
              filename: "#{name}-#{Date.current.iso8601}.csv",
              type: "text/csv", disposition: "inline"
  end
end

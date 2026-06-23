# Reusable date-range filter. Maps a preset key (today/week/month) or a specific
# day to a Range, for filtering any date/datetime column. Usable from controllers
# (to build a where clause) and views (OPTIONS for the select). No i18n.
class DateRange
  # [label, value] pairs for a preset <select>.
  OPTIONS = [
    [ "Todas las fechas", "" ],
    [ "Hoy",          "today" ],
    [ "Esta semana",  "week" ],
    [ "Este mes",     "month" ]
  ].freeze

  # [label, value] pairs for a "vence dentro de N días" <select>.
  DUE_OPTIONS = [
    [ "Cualquier vencimiento", "" ],
    [ "Próximo día",      "1" ],
    [ "Próximos 3 días",  "3" ],
    [ "Próximos 5 días",  "5" ]
  ].freeze

  # Range for a preset key, or nil when blank/unknown.
  def self.for(preset)
    case preset.to_s
    when "today" then Date.current.all_day
    when "week"  then Date.current.all_week
    when "month" then Date.current.all_month
    end
  end

  # Range for a specific ISO day (YYYY-MM-DD), or nil when blank/invalid.
  def self.for_day(day)
    return nil if day.blank?

    Date.iso8601(day.to_s).all_day
  rescue ArgumentError, Date::Error
    nil
  end

  # Range from today through N days ahead, for "due within N days".
  # Returns nil for blank or non-positive input.
  def self.upcoming(days)
    n = days.to_i
    return nil unless n.positive?

    Date.current..(Date.current + n)
  end
end

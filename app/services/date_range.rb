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
end

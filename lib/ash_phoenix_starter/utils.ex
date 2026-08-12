defmodule AshPhoenixStarter.Utils do
  def date_name_format(date, tz \\ "America/Phoenix") do
    today = Timex.now(tz) |> DateTime.to_date()
    tomorrow = today |> Timex.shift(days: 1)
    yesterday = today |> Timex.shift(days: -1)

    case date do
      date when date == yesterday ->
        "Yesterday"

      date when date == today ->
        "Today"

      date when date == tomorrow ->
        "Tomorrow"

      _ ->
        dayname = date |> Timex.weekday() |> Timex.day_name()
        "#{dayname}"
    end
  end

  def date_range_names(number_of_days, tz \\ "America/Phoenix") do
    today = Timex.now(tz) |> DateTime.to_date()
    to = Date.utc_today() |> Timex.shift(days: number_of_days)
    tomorrow = today |> Timex.shift(days: 1)
    yesterday = today |> Timex.shift(days: -1)

    Date.range(today, to)
    |> Enum.to_list()
    |> Enum.map(fn x ->
      dayname = x |> Timex.weekday() |> Timex.day_shortname()

      case x do
        x when x == yesterday -> {"Yesterday", x, Timex.format!(x, "{s}")}
        x when x == today -> {"Today", x, Timex.format!(x, "{s}")}
        x when x == tomorrow -> {"Tomorrow", x, Timex.format!(x, "{s}")}
        _ -> {dayname, x, Timex.format!(x, "{s}")}
      end
    end)
  end

  def convert_date_to_datetime(%DateTime{} = dt), do: dt

  def convert_date_to_datetime(%Date{} = date, tz \\ "Etc/UTC") do
    Timex.to_datetime(date, tz)
  end

  def convert_date_to_end_of_day_datetime(%Date{} = date, tz \\ "Etc/UTC") do
    date
    |> Timex.to_datetime(tz)
    |> Timex.end_of_day()
  end
end

defmodule DateRange do
  defstruct [:first_days, :last_days]

  @moduledoc """
  Defines a range of dates.

  A DateRange implements the `Enumerable` protocol, which means
  functions in the `Enum` module can be used to work with
  ranges:

      iex> range = DateRange.new(~D[2017-01-01], ~D[2017-01-20])
      #DateRange<2017-01-01..2017-01-20>
      iex> Enum.count(range)
      20
      iex> Enum.member?(range, ~D[2017-01-01])
      true
      iex> Enum.member?(range, ~D[2017-01-21])
      false
      iex> Enum.filter(range, &Date.day_of_week(&1) in [1])
      [~D[2017-01-02], ~D[2017-01-09], ~D[2017-01-16]]

  Only ISO calendar is supported.
  """

  @doc """
  Returns a new `DateRange`.

  ## Examples

      iex> DateRange.new(~D[2017-01-01], ~D[2017-01-03]) |> Enum.to_list()
      [~D[2017-01-01], ~D[2017-01-02], ~D[2017-01-03]]

      iex> DateRange.new(~D[2017-12-31], ~D[2017-01-01]) |> Enum.take(3)
      [~D[2017-12-31], ~D[2017-12-30], ~D[2017-12-29]]

  """
  def new(%Date{calendar: Calendar.ISO} = first_date, %Date{calendar: Calendar.ISO} = last_date) do
    %DateRange{first_days: date_to_days(first_date), last_days: date_to_days(last_date)}
  end

  @doc false
  def days_to_date(days) when is_integer(days) do
    days |> :calendar.gregorian_days_to_date() |> Date.from_erl!()
  end

  @doc false
  def date_to_days(%Date{} = date) do
    date |> Date.to_erl() |> :calendar.date_to_gregorian_days()
  end
end

defimpl Enumerable, for: DateRange do
  def reduce(%DateRange{first_days: first_days, last_days: last_days}, acc, fun) do
    reduce(first_days, last_days, acc, &(fun.(DateRange.days_to_date(&1), &2)), first_days <= last_days)
  end

  defp reduce(_x, _y, {:halt, acc}, _fun, _up?) do
    {:halted, acc}
  end

  defp reduce(x, y, {:suspend, acc}, fun, up?) do
    {:suspended, acc, &reduce(x, y, &1, fun, up?)}
  end

  defp reduce(x, y, {:cont, acc}, fun, _up? = true) when x <= y do
    reduce(x + 1, y, fun.(x, acc), fun, _up? = true)
  end

  defp reduce(x, y, {:cont, acc}, fun, _up? = false) when x >= y do
    reduce(x - 1, y, fun.(x, acc), fun, _up? = false)
  end

  defp reduce(_, _, {:cont, acc}, _fun, _up) do
    {:done, acc}
  end

  def member?(%{first_days: first_days, last_days: last_days}, %Date{} = date) do
    days = DateRange.date_to_days(date)
    Enumerable.Range.member?(first_days..last_days, days)
  end

  def count(%{first_days: first_days, last_days: last_days}) do
    {:ok, abs(first_days - last_days) + 1}
  end
end

defimpl Inspect, for: DateRange do
  def inspect(%{first_days: first_days, last_days: last_days}, _opts) do
    first_date = DateRange.days_to_date(first_days)
    last_date = DateRange.days_to_date(last_days)
    "#DateRange<" <> to_string(first_date) <> ".." <> to_string(last_date) <> ">"
  end
end

defmodule Choobio.Station.Platform do
  use GenServer

  alias Choobio.Line.Train
  alias Choobio.Station.Platform.Arrivals
  alias __MODULE__, as: Platform

  defstruct [:station_id, :station_name, :line_id, :arrivals, timestamp: Timex.zero]

  @tfl_api Application.get_env(:choobio, :tfl_api)
  @vsn "0"

  # Client API

  @doc """
  Used to start a supervised process. Gives itself a name which is the result of
  atomising `station_id` and `line_id` separated by an underscore.
  ```
  :"906ULZBLH_northern"
  ```
  Station ID and line ID are both passed to the `init` function.
  """
  def start_link(station_id, station_name, line_id) do
    pname = create_process_name(station_id, line_id)
    GenServer.start_link(__MODULE__, {{station_id, line_id}, station_name}, name: pname)
  end

  @doc """
    Returns arrival lists of trains by fetching data from the TFL API.

    Data is considered 'fresh' up to 60 seconds' lag. This is to avoid hammering
    the TFL API. If the cached timestamp is less than 60 seconds ago, the cached
    data will be returned.

    Otherwise, new data is fetched from TFL, converted to lists of train structs
    and sorted by time of arrival.

    For details on a train struct, see the `Choobio.Line.Train` module.
  """
  def get_arrivals(process_name) do
    GenServer.call(process_name, :get_arrivals)
  end

  # Server callbacks

  def init({{station_id, line_id}, station_name}) do
    IO.puts "Arrivals board is starting up for station #{station_id}"
    tidy_name = tidy_name(station_name)
    initial_state =
      %Platform{station_id: station_id, line_id: line_id, station_name: tidy_name}
    {:ok, initial_state}
  end

  def handle_call(:get_arrivals, _from, %Platform{} = state) do
    result = fetch_arrivals(state)
    {:reply, result, result}
  end

  # Helper functions

  defp create_process_name(station_id, line_id) do
    "#{station_id}_#{line_id}" |> String.to_atom
  end

  defp tidy_name(string) do
    String.replace(string, ~r/ Underground Station/, "")
  end

  # Business Logic

  defp fetch_arrivals(%Platform{} = state) do
    check_time_elapsed(state.timestamp)
    |> return_arrivals(state)
  end

  defp check_time_elapsed(cached_time) do
    diff = Timex.diff(Timex.now, cached_time, :seconds)
    cond do
      diff < 60 ->
        :use_cache
      true ->
        :use_fresh
    end
  end

  defp return_arrivals(:use_cache, %Platform{} = cache), do: cache
  defp return_arrivals(:use_fresh, %Platform{} = cache) do
    attempt_tfl_call(cache)
  end

  defp attempt_tfl_call(%Platform{} = cache) do
    response = @tfl_api.line_arrivals(cache.station_id, cache.line_id)
    case @tfl_api.successful_response?(response) do
      false ->
        cache
      true ->
        @tfl_api.take_body(response) |> create_cache(cache)
    end
  end

  defp create_cache(http_response_body, %Platform{} = cache) do
    http_response_body
    |> Train.create_train_structs
    |> Arrivals.build_arrivals
    |> update_arrivals(cache)
    |> insert_timestamp
  end

  defp update_arrivals(%Arrivals{} = updated_arrivals, %Platform{} = cache) do
    %{cache | arrivals: updated_arrivals}
  end

  defp insert_timestamp(%Platform{} = cache) do
    time = Timex.now
    %{cache | timestamp: time}
  end

end
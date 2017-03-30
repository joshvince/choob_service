defmodule Choobio.Station.Platform do
	require Logger
	use Timex
	use GenServer
  alias __MODULE__, as: Platform

  defstruct [:station_id, :station_name, :line_id, :timestamp,
						 :at_platform, departures: []]

  @doc """
  Used to start a supervised process. Registers the name in the :platform_registry.

	The process will be registered under :"naptanId_lineId" like
	```
  :"906ULZBLH_northern"
  ```
  Station ID and line ID are both passed to the `init` function.
  """
  def start_link(station_id, station_name, line_id) do
    GenServer.start_link(__MODULE__, {{station_id, line_id}, station_name}, name: via_tuple({station_id, line_id}))
  end

	@doc """
	Used to register the process name under its vehicle ID in the registry.
	See `&start_link/1` for more details.
	"""
	def via_tuple({station_id, line_id}) do
		pname = create_process_name(station_id, line_id)
		{:via, Registry, {:platform_registry, pname}}
	end

  defp create_process_name(station_id, line_id) do
    "#{station_id}_#{line_id}" |> String.to_atom
  end

	# Public API

  def get_arrivals({station_id, line_id}) do
    GenServer.call(via_tuple({station_id, line_id}), :get_arrivals)
  end

	def get_departures({station_id, line_id}) do
		GenServer.call(via_tuple({station_id, line_id}), :get_departures)
	end

	def new_arrival({station_id, line_id}, train_data) do
		GenServer.call(via_tuple({station_id, line_id}), {:new_arrival, train_data})
	end

	def departed({station_id, line_id}, train_id) do
		GenServer.cast(via_tuple({station_id, line_id}), {:departed, train_id})
	end


  # Server callbacks

  def init({{station_id, line_id}, station_name}) do
    initial_state =
      %Platform{station_id: station_id, line_id: line_id, station_name: station_name}
    {:ok, initial_state}
  end

  #NOTE: temp while we set the scaffold up.

  def handle_call(:get_arrivals, _from, %Platform{} = state) do
		Logger.info "Arrivals for #{state.station_name}: #{inspect state.arrivals}"
    {:reply, :test, state}
  end

	# if the train is the first arrival at this station... Something went wrong
	def handle_call({:new_arrival, vehicle_id}, _from, %Platform{departures: []} = state) do
		new_state = add_new_arrival(state, vehicle_id)
		{:reply, :first_arrival, new_state}
	end

	def handle_call({:new_arrival, vehicle_id}, _from, %Platform{} = state) do
		[latest | _rest] = state.departures
		new_state = add_new_arrival(state, vehicle_id)
		{:reply, latest, new_state}
	end

	def handle_call(:get_departures, _from, %Platform{departures: list} = state) do
		{:reply, list, state}
	end

	def handle_cast({:departed, _train_id}, %Platform{} = state) do
		new_state = handle_departure(state)
		{:noreply, new_state}
	end

	# Private Functions

	defp add_new_arrival(%Platform{} = state, vehicle) do
		vehicle_map = %{id: vehicle, arrived: Timex.now(), departed: nil}
		Map.put(state, :at_platform, vehicle_map)
	end

	defp handle_departure(%Platform{at_platform: platform_map, departures: dep_list} = state) do
		updated_pmap = %{platform_map | :departed => Timex.now()}
		new_deps = [updated_pmap | dep_list]
		%{state | :at_platform => %{}, :departures => new_deps}
	end

end

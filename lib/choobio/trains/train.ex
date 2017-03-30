defmodule Choobio.Train do
	require Logger
  @moduledoc """
  When started under a supervision tree, like `Choobio.Line.Supervisor`, this module
  creates a genserver representing one train on the network.

  The functionality here is all around holding state about where the train is, and
  how long it has had its doors open for throughout its journey.

  When the process is started, it can send and receive messages to receive
  data from TFL via a `Dispatcher`.
  """
  use GenServer
	use Timex
  alias __MODULE__, as: Train
	alias Choobio.Station.Platform

	defstruct [	:id, :location, :next_station, :time_to_station,
							:direction, :line_id, :expected_arrival,
							at_platform: %{current: nil, modifier: 0, ticks: 0, total_ticks: 0}]

  @doc """
  Starts a train process and registers its name in the registry relating to `line_id`.

  A train that receives `{"001", "northern"}` will be registered in `:northern_registry`
  under the key "001".
  """
	def start_link({vehicle_id, line_id}) do
		initial_data = %{id: vehicle_id}
		name = via_tuple({vehicle_id, line_id})
		{:ok, _} = GenServer.start_link(__MODULE__, initial_data, name: name)
	end

# Public API

  @doc """
  Returns the current location of the train
  """
	def get_location({vehicle_id, line_id}) do
		GenServer.call(via_tuple({vehicle_id, line_id}), :get_location)
	end

  @doc """
  Updates the process state with the new location data, which has presumably
  arrived via `Dispatcher` from TFL.
  """
	def update_location({vehicle_id, line_id}, new_data) do
		GenServer.cast(via_tuple({vehicle_id, line_id}), {:update_location, new_data})
	end

	@doc """
	DOC THIS UP
	"""
	def fetch_last_departure(train_pid, station_id) do
		GenServer.cast(train_pid, {:fetch_last_departure, station_id})
	end

# Genserver

  @doc """
  See `&get_location/1` for details
  """
	def handle_call(:get_location, _from, state) do
		{:reply, state, state}
	end

  @doc """
  See `&update/2` for details
  """
	def handle_cast({:update_location, new_data}, state) do
		new_state = update_location_data(new_data, state)
		handle_location_update(state, new_state)
	end

	@doc """
	See `&fetch_last_departure/2` for details.
	"""
	def handle_cast({:fetch_last_departure, station_id}, state) do
		last_departure =
			Platform.new_arrival({station_id, state.line_id}, state.id)
		new_state = update_platform_map(:add_modifier, last_departure, state)
		{:noreply, new_state}
		# go get the last departure from the station_id in at_platform => current
		# add that data to some new key in the at_platform map that modifies the score.
	end

	@doc """
	Used to register the process name under its vehicle ID in the registry.
	See `&start_link/1` for more details.
	"""
	def via_tuple({vehicle_id, line_id}) do
		registry = get_registry_name(line_id)
		{:via, Registry, {registry, vehicle_id}}
	end

	defp get_registry_name(line_id), do: String.to_atom("#{line_id}_registry")

	@doc """
	Initialises the process with a basic location map.
	"""
	def init(data) do
		state = %Train{id: data.id}
		{:ok, state}
	end

# Private functions

	defp update_location_data(%Choobio.Tfl.Arrival{} = new_data, old_location) do
		%{old_location |
			:next_station => new_data.naptanId, :location => new_data.currentLocation,
			:time_to_station => new_data.timeToStation, :expected_arrival => new_data.expectedArrival,
			:direction => new_data.direction, :line_id => new_data.lineId}
	end

	defp handle_location_update(old_state, new_data) do
		case train_at_platform?(old_state.at_platform) do
			false -> check_for_arrival(old_state, new_data)
			true -> check_for_departure(old_state, new_data)
		end
	end

	defp train_at_platform?(%{current: nil}), do: false
	defp train_at_platform?(_anything), do: true

#train is still at the station
	defp check_for_departure(_old_state, %{location: "At" <> _rest} = new_data) do
		new_state = update_platform_map(:add_tick, new_data)
		{:noreply, new_state}
	end
#train has left the station
	defp check_for_departure(old_state, new_data) do
		Platform.departed({old_state.at_platform.current, old_state.line_id}, old_state.id)
		new_state = update_platform_map(:departed_station, new_data)
		{:noreply, new_state}
	end

#########

	#TODO: sometimes trains receive a 'depart' message then somehow end up back
	# at the same station. Need to be able to handle that somehow

#########

	# handle the case where we've initialised the train. ignore the first tick and keep going
	defp check_for_arrival(%{next_station: nil} = _old_state, new_state) do
		{:noreply, new_state}
	end

	# the train hasn't arrived at a station yet (because the next_station is still the same)
	defp check_for_arrival(%{next_station: same} = _old_state, %{next_station: same} = new_state) do
		{:noreply, new_state}
	end

	# the train has arrived at the station
	defp check_for_arrival(old_state, %{location: "At" <> _rest} = new_data) do
		new_state = update_platform_map(:arrived_at, old_state.next_station, new_data)
		fetch_last_departure(self(), old_state.next_station)
		{:noreply, new_state}
	end

	# the next station has changed, but the train is not at a platform. Revert back and wait
	defp check_for_arrival(old_state, new_data) do
		# if the old next station was nil, we don't want it popped back in.
		new_state =
			case old_state.next_station do
				nil -> new_data
				_ -> %{ new_data | :next_station => old_state.next_station }
			end
		{:noreply, new_state}
	end

	defp update_platform_map(:add_tick, %Train{at_platform: map} = state) do
		new = Map.update(map, :ticks, 1, & &1 + 1)
		%{state | at_platform: new}
	end

	defp update_platform_map(:departed_station, %Train{at_platform: map} = state) do
		new_total = (map.ticks + map.total_ticks)
		pmap = %{:current => nil, :ticks => 0, :total_ticks => new_total}
		%{state | at_platform: pmap}
	end

	defp update_platform_map(:arrived_at, station_id, %Train{at_platform: map} = state) do
		pmap = %{map | :current => station_id, :ticks => 1}
		%{state | :at_platform => pmap}
	end

	defp update_platform_map(:add_modifier, platform_data, %Train{at_platform: map} = state) do
		pmap = %{map | :modifier => calculate_modifier(platform_data)}
		%{state | :at_platform => pmap}
	end

	defp calculate_modifier(:first_arrival), do: 0
	defp calculate_modifier(%{id: _, arrived: _, departed: dep_time}) do
		Timex.Duration.diff(dep_time, :seconds)
	end


end

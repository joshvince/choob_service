defmodule Choobio.Line.Dispatcher do
  @moduledoc """
  Receives messages from TFL about trains and passes the data on to the relevant
  train process, creating a new one if necessary.
  """
  use Supervisor
	@tfl_api Application.get_env(:choobio, :tfl_api)

  # Initialisation

  def start_link(_line_id) do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    children = [worker(Choobio.Train, [])]
    supervise(children, strategy: :simple_one_for_one)
  end

	@doc """
	Calls `&update_all_arrivals/1` every `interval` (30secs by default).

	See doc for `&update_all_arrivals/1` for what this is actually doing.
	"""
	def schedule_arrival_updates(line_id, interval \\ 30_000) do
		:timer.apply_interval(interval, __MODULE__, :update_all_arrivals, [line_id])
	end

	@doc """
	Calls out to TFL for the arrivals on the line, and then dispatches this
	information to the train processes,	using the `vehicleId` as an identifier.

	If no process is registered under the vehicle id, it will create the process
	and initialise it with the data.
	"""
	def update_all_arrivals(line_id) do
		get_arrivals_data(line_id)
		|> dispatch_to_trains(line_id)
	end

	defp dispatch_to_trains(list, line_id) do
		Enum.each(list, fn {id, data} ->
			case find_or_create_train({id, line_id}) do
				{:ok, id} -> update_location(id, line_id, data)
				_ -> :error
			end
		end)
	end

	defp update_location(train_id, line_id, location_data) do
		Choobio.Train.update_location({train_id, line_id}, location_data)
	end

  # Managing Supervised Train Processes

  @doc """
  Used to lookup a train process using its vehicle and line identifiers.

  If the process already exists, returns `{:ok, ID}`.

  If the process doesn't already exist, it creates it with the given `vehicle_id`
  and will register it in the registry.
  """
  def find_or_create_train({vehicle_id, line_id}) do
    if train_process_exists?({vehicle_id, line_id}) do
      {:ok, vehicle_id}
    else
      create_train_process({vehicle_id, line_id})
    end
  end

  defp train_process_exists?({vehicle_id, line_id}) do
    registry = get_registry_name(line_id)
    case Registry.lookup(registry, vehicle_id) do
      [] -> false
      _ -> true
    end
  end

	# create train processes unless they have already been started.
  defp create_train_process({vehicle_id, line_id}) do
    case Supervisor.start_child(__MODULE__, [{vehicle_id, line_id}]) do
      {:ok, _pid} ->
        {:ok, vehicle_id}
      {:error, {:already_started, _pid}} ->
        {:error, :process_already_exists}
      other ->
        {:error, other}
    end
  end

	# Calling out to TFL

	@doc """
	Calls out to TFL and parses the response into a list of vehicle IDs and one
	`%Tfl.Arrival` struct per vehicle.

	[{"001", %Tfl.Arrival{}}, {"002", %Tfl.Arrival{}}]
	"""
	def get_arrivals_data(line_id) do
		@tfl_api.get_all_arrivals(line_id)
		|> vehicle_id_map
		|> next_station_only
	end

	defp vehicle_id_map(list_of_maps) do
		Enum.reduce(list_of_maps, %{}, &assign_to_id/2)
	end

	defp assign_to_id(map, acc) do
		case Map.fetch(acc, map.vehicleId) do
			{:ok, list} -> %{acc | map.vehicleId => [map | list]}
			:error -> Map.put(acc, map.vehicleId, [map])
		end
	end

	defp next_station_only(vehicle_id_map) do
		vehicle_id_map
		|> Enum.map(fn {id, list} ->
			{id, shortest_time_to_station(list)}
		end)
	end

	defp shortest_time_to_station(list) do
		Enum.sort(list, fn (a,b) -> a.timeToStation < b.timeToStation end)
		|> List.first
	end

  # Helper Functions

  @doc """
  Counts number of train processes currently supervised.
  """
  def train_process_count do
    Supervisor.which_children(__MODULE__) |> Enum.count
  end

  defp get_registry_name(line_id) do
    String.to_atom("#{line_id}_registry")
  end

end

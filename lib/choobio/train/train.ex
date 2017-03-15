defmodule Choobio.Train do
  use GenServer
  alias __MODULE__, as: Train
  alias Choobio.Tfl

	def start_link({vehicle_id, line_id}) do
		init_args = {vehicle_id}
		{:ok, _} = GenServer.start_link(__MODULE__, init_args, name: via_tuple({vehicle_id, line_id}))
	end

  def via_tuple({vehicle_id, line_id}) do
    registry = get_registry_name(line_id)
    {:via, Registry, {registry, vehicle_id}}
  end

	def init({vehicle_id}) do
		state = %{id: vehicle_id, location: "init", next_station: "init"}
		{:ok, state}
	end

  defp get_registry_name(line_id) do
    String.to_atom("#{line_id}_registry")
  end

  def whereis({vehicle_id, line_id}) do
    registry = get_registry_name(line_id)
    case Registry.lookup(registry, vehicle_id) do
      [{pid, _}] -> pid
      [] -> nil
    end
  end

	def get_location({vehicle_id, line_id}) do
		GenServer.call(via_tuple({vehicle_id, line_id}), :get_location)
	end

	def update({vehicle_id, line_id}, new_data) do
		GenServer.cast(via_tuple({vehicle_id, line_id}), {:update_location, new_data})
	end

	def handle_call(:get_location, _from, state) do
		{:reply, state, state}
	end

	def handle_cast({:update_location, new_data}, state) do
		new_state = update_location(new_data, state)
		now = DateTime.utc_now()
		IO.puts "\n#{now.hour}:#{now.minute}:#{now.second} :: #{inspect new_state}\n"
		{:noreply, new_state}
	end

	defp update_location(new_data, old_location) do
		new_loc = Map.get(new_data, :location)
		new_stat = Map.get(new_data, :station)
		old_location
		|> Map.put(:next_station, new_stat)
		|> Map.put(:location, new_loc)
	end

end

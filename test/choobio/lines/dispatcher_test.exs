defmodule Choobio.Line.DispatcherTest do
	require Logger
	use ExUnit.Case
	alias Choobio.Line.Dispatcher

	@tfl_api Application.get_env(:choobio, :tfl_api)

	setup do
		# start the registry
		Registry.start_link(:unique, :platform_registry)
		# start all the platforms.
		Choobio.Station.Platform.start_link("940GZZLUGGN", "Golders Green Underground Station", "northern")
		{:ok, %{}}
	end

	test "returns tuples of the id and a struct for that train's next arrival" do
		list = Dispatcher.get_arrivals_data("northern")
		Enum.each(list, fn {id, %Choobio.Tfl.Arrival{} = struct} ->
			assert id == struct.vehicleId
		end)
	end

	test "updates train data based on data supplied" do
		# update the arrivals
		Dispatcher.update_all_arrivals("northern")
		location_data = @tfl_api.get_all_arrivals("northern") |> List.first()
		train = Choobio.Train.get_location({location_data.vehicleId, "northern"})
		assert train.next_station == location_data.naptanId
		assert train.location == location_data.currentLocation
		assert train.time_to_station == location_data.timeToStation
	end

end

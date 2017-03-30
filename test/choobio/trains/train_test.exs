defmodule Choobio.TrainTest do
	use ExUnit.Case
	alias Choobio.{Train}

	setup do
		#start up the tooting bec platform
		Choobio.Station.Platform.start_link("940GZZLUTBC", "Tooting Bec", "northern")
		broadway_arrival =
			%Choobio.Tfl.Arrival{
				currentLocation: "Between Tooting Broadway and Tooting Bec",
				destinationName: "Edgware Underground Station",
				destinationNaptanId: "940GZZLUEGW", direction: "outbound",
				expectedArrival: "2017-03-21T13:04:23Z", lineId: "northern",
				naptanId: "940GZZLUTBC", platformName: "Northbound - Platform 1",
				stationName: "Tooting Bec Underground Station", timeToStation: 85,
				towards: "Edgware via Bank", vehicleId: "025"}
		false_bec_arrival =
			%Choobio.Tfl.Arrival{
				currentLocation: "Approaching Tooting Bec",
				destinationName: "Edgware Underground Station",
				destinationNaptanId: "940GZZLUEGW", direction: "outbound",
				expectedArrival: "2017-03-21T13:04:29Z", lineId: "northern",
				naptanId: "940GZZLUBLM", platformName: "Northbound - Platform 1",
				stationName: "Balham Underground Station", timeToStation: 20,
				towards: "Edgware via Bank", vehicleId: "025"}
		bec_arrival =
			%Choobio.Tfl.Arrival{
				currentLocation: "At Tooting Bec Platform 1",
				destinationName: "Edgware Underground Station",
				destinationNaptanId: "940GZZLUEGW", direction: "outbound",
				expectedArrival: "2017-03-21T13:05:26Z", lineId: "northern",
				naptanId: "940GZZLUBLM", platformName: "Northbound - Platform 1",
				stationName: "Balham Underground Station", timeToStation: 134,
				towards: "Edgware via Bank", vehicleId: "025"}
		bec_departure =
			%Choobio.Tfl.Arrival{
				currentLocation: "Departed Tooting Bec",
				destinationName: "Edgware Underground Station",
				destinationNaptanId: "940GZZLUEGW", direction: "outbound",
				expectedArrival: "2017-03-21T13:07:26Z", lineId: "northern",
				naptanId: "940GZZLUBLM", platformName: "Northbound - Platform 1",
				stationName: "Balham Underground Station", timeToStation: 111,
				towards: "Edgware via Bank", vehicleId: "025"}
		Train.start_link({"025", "northern"})
		# initialise the train between broadway and bec
		Train.update_location({"025", "northern"}, broadway_arrival)

		{:ok, %{broadway_arrival: broadway_arrival, bec_arrival: bec_arrival,
						false_bec_arrival: false_bec_arrival, bec_departure: bec_departure}}
	end

	test "correctly recognises when a train arrives at a platform.", arrivals do
		# update the location to be at tooting bec
		Train.update_location({"025", "northern"}, arrivals.bec_arrival)
		state = Train.get_location({"025", "northern"})
		assert state.at_platform.current == arrivals.broadway_arrival.naptanId
		assert state.next_station == arrivals.bec_arrival.naptanId
	end

	test "correctly recognises when a train is not at a platform", arrivals do
		# update the location to be near bec, but not at the platform
		Train.update_location({"025", "northern"}, arrivals.false_bec_arrival)
		state = Train.get_location({"025", "northern"})
		assert state.next_station == arrivals.broadway_arrival.naptanId
		assert state.at_platform.current == nil
	end

	test "each tick spent at a platform adds one to the count", arrivals do
		# update the location to be at tooting bec
		Train.update_location({"025", "northern"}, arrivals.bec_arrival)
		# sleeping to ensure it finishes its business before sending the next update
		:timer.sleep 100
		# update it to say it is at the platform again
		Train.update_location({"025", "northern"}, arrivals.bec_arrival)
		state = Train.get_location({"025", "northern"})
		assert state.at_platform.ticks == 2

	end

	test "a train that departs a station updates the total ticks appropriately", arrivals do
		# arrive at tooting bec
		Train.update_location({"025", "northern"}, arrivals.bec_arrival)
		# sleep to ensure it's finished its business
		:timer.sleep 100
		# leave tooting bec
		Train.update_location({"025", "northern"}, arrivals.bec_departure)
		state = Train.get_location({"025", "northern"})
		assert %{current: nil, total_ticks: 1, ticks: 0} = state.at_platform
	end

	test "a train leaves a timestamp behind when it departs a platform", arrivals do
		# arrive at tooting bec
		Train.update_location({"025", "northern"}, arrivals.bec_arrival)
		:timer.sleep 100
		# depart tooting bec
		Train.update_location({"025", "northern"}, arrivals.bec_departure)
		:timer.sleep 100
		[dep | _] = Choobio.Station.Platform.get_departures({"940GZZLUTBC", "northern"})
		%{departed: %DateTime{}} = dep
	end

end

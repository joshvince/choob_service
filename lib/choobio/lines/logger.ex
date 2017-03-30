defmodule Choobio.Line.Logger do
	require Logger
	@moduledoc """
	A helper module for printing out the data received from TFL to do with
	trains and their location.

	This module can be used to track one train in realtime and print a CSV log
	of all the messages received with timestamps.
	"""

	@doc """
	Track one train using its vehicle_id and the line ID (you must already know
	that this train is currently running on the line.)

	When the train reaches the station before `termination_id` (which must be a
	valid NaptanId) the logger will stop and print the messages to a CSV file in
	the root directory. The file will be called "vehicle_id_log.csv"
	"""
	def track_one_train(vehicle_id, line_id, termination_id) do
		track(%{}, vehicle_id, line_id, termination_id)
	end

	defp track(acc, vehicle_id, line_id, termination_id) do
		:timer.sleep 10_000
		Choobio.Line.Dispatcher.get_arrivals_data(line_id)
		|> find_tracked_train(vehicle_id)
		|> update_and_loop(acc, vehicle_id, line_id, termination_id)
	end

	defp find_tracked_train(list, vehicle_id) do
		{_id, struct} = Enum.find(list, fn {id, _map} -> id == vehicle_id end)
		struct
	end

	defp update_and_loop(%{naptanId: termination_id}, acc, vehicle_id, _line, termination_id) do
		write_csv_log(acc, vehicle_id)
	end

	defp update_and_loop(new_el, acc, vehicle_id, line_id, termination_id) do
		now = DateTime.utc_now()
		timestamp = format_timestamp([now.hour, now.minute, now.second])
		new_acc = Map.put(acc, timestamp, new_el)
		Logger.info "\n#{timestamp}: #{inspect new_el}\n"
		track(new_acc, vehicle_id, line_id, termination_id)
	end

	defp format_timestamp(input) do
		[hr, min, sec] = Enum.map(input, &add_zeroes &1)
		"#{hr}#{min}#{sec}"
	end

	defp add_zeroes(int) do
		if int < 10 do
			"0#{int}"
		else
			"#{int}"
		end
	end

	defp write_csv_log(map, vehicle_id) do
		{:ok, file} = File.open("#{vehicle_id}_log.csv", [:write])
		convert_to_csv(map)
		|> Enum.each(&IO.write(file, &1))
		File.close(file)
	end

	defp convert_to_csv(map) do
		convert_to_rows(map)
		|> prepend_header_row
		|> CSV.encode
	end

	defp convert_to_rows(map) do
		Enum.map(map, fn {k,v} -> [k | to_csv_row(v)] end)
	end

	defp to_csv_row(struct) do
		Map.from_struct(struct)
		|> Enum.map(fn {_k, v} -> v end)
	end

	defp prepend_header_row(rows) do
		header = get_header()
		[header | rows]
	end

	defp get_header do
		%Choobio.Tfl.Arrival{}
		|> Map.from_struct
		|> Enum.map(fn {k, _v} -> Atom.to_string(k) end)
		|> add_timestamp
	end

	defp add_timestamp(list), do: ["timestamp" | list]

end

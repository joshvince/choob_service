defmodule Commuter.Station.ArrivalsTest do
  use ExUnit.Case
  alias Commuter.Station.Arrivals

  setup do
    trains =
      Commuter.Tfl.Mock.line_arrivals(:test)
      |> Commuter.Train.create_train_structs
    %{trains: trains}
  end

  test "builds an arrivals struct", %{trains: trains} do
    assert Arrivals.build_arrivals(trains).__struct__ == Arrivals
  end

  test "raw lists are just lists of train structs", %{trains: trains} do
    arr = Arrivals.build_arrivals(trains)
    assert Enum.all?(arr.inbound, fn struct ->
      assert struct.__struct__ == Commuter.Train end)
    assert Enum.all?(arr.outbound, fn struct ->
      assert struct.__struct__ == Commuter.Train end)
  end

  test "trains going in both directions are put in the right list", %{trains: trains} do
    arr = Arrivals.build_arrivals(trains)
    Enum.each(arr.inbound, fn struct ->
      assert struct.direction == "inbound" end)
    Enum.each(arr.outbound, fn struct ->
      assert struct.direction == "outbound" end)
  end

  test "trains are ordered chronologically by arrival time", %{trains: trains} do
    list = Arrivals.build_arrivals(trains).outbound
    arrival_times = Enum.map(list, fn map -> map.time_to_station end)
    sorted_arrival_times = Enum.sort(arrival_times)
    assert arrival_times == sorted_arrival_times
  end

  test "intervals are inserted correctly.", %{trains: trains} do
    [one, two] = Arrivals.build_arrivals(trains).outbound |> Enum.take(2)
    assert two.interval == (two.time_to_station - one.time_to_station)
  end

end

defmodule Commuter.Journey.ControllerTest do
  use ExUnit.Case, async: true
  use Plug.Test
  alias Commuter.Journey.Controller

  @opts Commuter.Router.init([])

  setup do
    good_resp =
      conn(:get, "/stops?station=940GZZLUTBC&line=northern")
      |> Commuter.Router.call(@opts)
      |> Controller.get_possible_stops
    bad_resp =
      conn(:get, "/stops?station=FAKE&line=fakeline")
      |> Commuter.Router.call(@opts)
      |> Controller.get_possible_stops
    %{stops: good_resp, bad_stops: bad_resp}
  end

  test "returns a JSON-able string of stations reachable on the line",
  %{stops: resp} do
    {code, _res} = Poison.decode(resp.resp_body)
    assert code == :ok
  end

  test "all objects in the response string have id values",
  %{stops: resp} do
    maps = Poison.decode!(resp.resp_body)
    Enum.each(maps, &(Map.has_key? &1, "id"))
  end

  test "all objects in the response string have name values",
  %{stops: resp} do
    maps = Poison.decode!(resp.resp_body)
    Enum.each(maps, &(Map.has_key? &1, "name"))
  end

  test "handles bad responses elegantly", %{bad_stops: resp} do
    assert resp.status == 404
  end


end

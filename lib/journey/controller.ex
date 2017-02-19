defmodule Commuter.Journey.Controller do
  @moduledoc """
  Handles client requests for data about journeys, such as possible stops on
  any certain line, or the canonical direction between two stops.
  """

  @tfl_api Application.get_env(:commuter, :tfl_api)

  def get_possible_stops(%Plug.Conn{} = conn) do
    %{"station" => originatorId, "line" => lineId} = conn.query_params
    @tfl_api.get_possible_stops(originatorId, lineId)
    |> send_response(conn)
  end

  defp check_for_success("[]"), do: 404
  defp check_for_success(_successful_string), do: 200

  defp send_response(response_body, conn) do
    code = check_for_success(response_body)
    Plug.Conn.resp(conn, code, response_body)
  end


end

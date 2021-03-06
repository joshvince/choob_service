defmodule Commuter.Router do
  use Plug.Router

  require Logger

  alias Commuter.Station.Controller

  plug Corsica, origins: "*"
  plug Plug.Logger
  plug :match
  plug :dispatch

  def start_link do
    {:ok, _} = Plug.Adapters.Cowboy.http(Commuter.Router, [],
                [port: port(System.get_env("PORT"))])
  end

  def init(opts) do
    IO.puts "SYS PORT was #{inspect System.get_env("PORT")}"
    opts
  end

  defp port(nil), do: 4000
  defp port(port_string), do: String.to_integer(port_string)

  get "/" do
    conn
    |> send_resp(200, "OK")
    |> halt
  end

  get "/stations" do
    conn
    |> Controller.get_all_stations
  end

  get "/stations/:station_id/:line_id" do
    conn
    |> Controller.get_arrivals
  end

  match _ do
    IO.inspect(conn.params)
    send_resp(conn, 404, "oops!")
  end

end

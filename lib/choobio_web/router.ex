defmodule ChoobioWeb.Router do
  use ChoobioWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ChoobioWeb do
    pipe_through :browser # Use the default browser stack

    get "/", PageController, :index
  end

  

  # Other scopes may use custom stacks.
  scope "/api", ChoobioWeb do
    pipe_through :api

    resources "/stations", StationController, except: [:new, :delete, :edit]

    scope "/arrivals" do
      get "/:station_id/:line_id", ArrivalsController, :show
    
    end

  end
end

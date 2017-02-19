# Choob
Choob is a service that provides a little extra information about the London Underground.  

This repo covers the backend service, the client-side app is written in React and is accessible [here](https://github.com/joshvince/commuter-web)

## Setting up this Repo locally
Getting this set up is as simple as a few commands, but you need Elixir installed
on to your machine. The Elixir Docs have an
[easy install guide](http://elixir-lang.org/install.html).

Once you've got that installed, just clone the directory and `cd` into it...  

Install dependencies with `mix deps.get`  
Run tests with `mix test`  
Start iex with `iex -S mix`  

## What happens on startup?
When this application is started, two supervisors are spun up:  

### TFL Supervisor
This supervisor currently gets station data from the TFL api.  
On startup, it will get a list of all tube stations and store it to memory.  
Then, this is used to make API calls to TFL.  

*Note: In the `test` env, `Commuter.Tfl.Mock` - a Mock version of the TFL API -
is used. Mix handles this distinction for you.*  

### Station Supervisor
This supervisor will take the list of tube stations grabbed from TFL, and will
spawn and monitor a process for each combination of station/line. These processes
are then available for you to access via endpoints, explained below.  

Because OTP and Elixir are awesome, you don't have to worry about any of these
crashing, as they will be automatically restarted :)

## API

### Information

**GET** `/stations`
Returns a JSON array of station objects containing information needed to make
correct requests to the other endpoints.  

Each station object contains keys of `name`, `id` and `lines`. Name and ID are
self-explanatory and lines is an array containing ids of tube lines served by
that station.  

**GET** `/stops`
Returns a JSON array of stops reachable from the given station on the given line.
This request must contain a query string with `station` and `line` KVs.  

*Query String*
- `station` must only be a valid NaptanId a for Tube Station.
- `line` must be a valid Tube Line id.

*Examples*
`/stops?station=940GZZLUTBC&line=northern`
`/stops?station=940GZZLUTBC&line=waterloo-city`

### Arrivals

**GET** `/stations/:station_id/:line_id/:direction`  
Returns a JSON array of arrivals at the specified station, on the given line, for
the given direction.  

*Options:*
- `station_id` must be a valid `NaptanId` assigned to a TFL stopPoint that is served
by at least one `tube` line.
- `line_id` must be a valid tube id used by TFL. If in doubt, this is a
lowercase string with spaces replaced by dashes, like `northern` or `waterloo-city`
- `direction` is either `"inbound"` or `"outbound"`  

*Examples:*   

`/stations/940GZZLUTBC/northern/inbound` will return a list of Northern Line
trains travelling Southbound from Tooting Bec Station.  
`/stations/940GZZLUWLO/jubilee/outbound` will return a list of Jubilee Line
trains travelling Eastbound from Waterloo Station.

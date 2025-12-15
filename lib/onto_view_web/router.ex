defmodule OntoViewWeb.Router do
  use OntoViewWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {OntoViewWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug OntoViewWeb.Plugs.SetResolver
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :content_negotiation do
    plug :accepts, ["html", "json", "ttl", "rdf"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_secure_browser_headers
    plug OntoViewWeb.Plugs.SetResolver
  end

  scope "/", OntoViewWeb do
    pipe_through :browser

    # Landing page
    get "/", PageController, :home

    # Set browser and version selector
    get "/sets", SetController, :index
    get "/sets/:set_id", SetController, :show

    # Documentation routes (scoped by set and version)
    live "/sets/:set_id/:version/docs", DocsLive.Index, :index
  end

  scope "/", OntoViewWeb do
    pipe_through :content_negotiation

    # IRI resolution endpoint with content negotiation (Task 0.2.5)
    get "/resolve", ResolveController, :resolve
  end

  # Enable LiveDashboard in development
  if Application.compile_env(:onto_view, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: OntoViewWeb.Telemetry
    end
  end
end

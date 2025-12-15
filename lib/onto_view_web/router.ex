defmodule OntoViewWeb.Router do
  use OntoViewWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {OntoViewWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", OntoViewWeb do
    pipe_through :browser

    get "/", PageController, :home
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

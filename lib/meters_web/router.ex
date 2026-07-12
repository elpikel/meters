defmodule MetersWeb.Router do
  use MetersWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MetersWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", MetersWeb do
    pipe_through :browser

    get "/", PageController, :home
    post "/leads", PageController, :create
    get "/polityka-prywatnosci", PageController, :privacy
    get "/sitemap.xml", PageController, :sitemap
  end

  # Analytics proxy to avoid ad blockers (no pipeline: POST /api/event must skip CSRF)
  scope "/", MetersWeb do
    get "/js/stats.js", AnalyticsController, :script
    post "/api/event", AnalyticsController, :event
  end

  # Other scopes may use custom stacks.
  # scope "/api", MetersWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:meters, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: MetersWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end

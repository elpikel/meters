defmodule MetersWeb.PageController do
  use MetersWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end

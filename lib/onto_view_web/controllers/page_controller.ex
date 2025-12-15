defmodule OntoViewWeb.PageController do
  use OntoViewWeb, :controller

  def home(conn, _params) do
    render(conn, :home, layout: false)
  end
end

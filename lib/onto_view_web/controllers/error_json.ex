defmodule OntoViewWeb.ErrorJSON do
  @moduledoc """
  Renders error responses in JSON format.
  """

  def render(template, _assigns) do
    %{errors: %{detail: Phoenix.Controller.status_message_from_template(template)}}
  end
end

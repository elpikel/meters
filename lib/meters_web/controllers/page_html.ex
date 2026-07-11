defmodule MetersWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.

  See the `page_html` directory for all templates available.
  """
  use MetersWeb, :html

  embed_templates "page_html/*"

  @doc """
  Renders translated validation errors for a single form field, styled to
  match the landing page. Renders nothing when the field has no errors.
  """
  attr :field, Phoenix.HTML.FormField, required: true

  def field_error(assigns) do
    ~H"""
    <p :for={msg <- Enum.map(@field.errors, &translate_error/1)} class="field-err">
      {msg}
    </p>
    """
  end
end

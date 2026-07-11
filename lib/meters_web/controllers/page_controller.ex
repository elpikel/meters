defmodule MetersWeb.PageController do
  use MetersWeb, :controller

  import Phoenix.Component, only: [to_form: 1]

  alias Meters.Leads

  @page_title "Sprawdź, czy deweloper doliczył Ci metry pod ścianami"

  def home(conn, params) do
    conn
    |> assign(:page_title, @page_title)
    |> assign(:sent?, params["sent"] == "true")
    |> assign(:form, to_form(Leads.change_lead()))
    |> render(:home)
  end

  def create(conn, %{"lead" => lead_params}) do
    lead_params = Map.put(lead_params, "source", source(conn, lead_params))

    case Leads.create_lead(lead_params) do
      {:ok, _lead} ->
        redirect(conn, to: ~p"/?sent=true#zgloszenie")

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> assign(:page_title, @page_title)
        |> assign(:sent?, false)
        |> assign(:form, to_form(changeset))
        |> render(:home)
    end
  end

  # Prefer the client-supplied source (utm/referrer captured in JS); otherwise
  # fall back to the request referer header or "direct".
  defp source(_conn, %{"source" => source}) when is_binary(source) and source != "", do: source

  defp source(conn, _params) do
    case get_req_header(conn, "referer") do
      [referer | _] -> referer
      [] -> "direct"
    end
  end
end

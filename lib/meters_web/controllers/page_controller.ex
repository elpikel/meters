defmodule MetersWeb.PageController do
  use MetersWeb, :controller

  import Phoenix.Component, only: [to_form: 1]

  alias Meters.Leads

  @page_title "Sprawdź, czy deweloper doliczył Ci metry pod ścianami"
  @meta_description "Deweloperzy doliczali do ceny mieszkania powierzchnię pod ścianami działowymi. Sprawdź w 2 minuty, ile mogłeś nadpłacić — bezpłatna analiza umowy."

  def home(conn, params) do
    conn
    |> assign_seo()
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
        |> assign_seo()
        |> assign(:sent?, false)
        |> assign(:form, to_form(changeset))
        |> render(:home)
    end
  end

  @doc false
  def sitemap(conn, _params) do
    body = """
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
      <url>
        <loc>#{url(~p"/")}</loc>
        <changefreq>weekly</changefreq>
        <priority>1.0</priority>
      </url>
    </urlset>
    """

    conn
    |> put_resp_content_type("application/xml")
    |> send_resp(200, body)
  end

  defp assign_seo(conn) do
    conn
    |> assign(:page_title, @page_title)
    |> assign(:meta_description, @meta_description)
    |> assign(:canonical_url, url(~p"/"))
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

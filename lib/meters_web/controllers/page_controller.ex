defmodule MetersWeb.PageController do
  use MetersWeb, :controller

  import Phoenix.Component, only: [to_form: 1]

  alias Meters.Leads

  @page_title "Sprawdź, czy deweloper doliczył Ci metry pod ścianami"
  @meta_description "Deweloperzy doliczali do ceny mieszkania powierzchnię pod ścianami działowymi. Sprawdź w 2 minuty, ile mogłeś nadpłacić — bezpłatna analiza umowy."

  def home(conn, _params) do
    conn
    |> assign_seo()
    |> assign(:form, to_form(Leads.change_lead()))
    |> render(:home)
  end

  # The form submits via fetch (see landing.js), so this responds with JSON and
  # never redirects — the URL stays on "/" and the success box is toggled in the
  # page. On failure it returns per-field errors for inline display.
  def create(conn, %{"lead" => lead_params}) do
    lead_params = Map.put(lead_params, "source", source(conn, lead_params))

    case Leads.create_lead(lead_params) do
      {:ok, _lead} ->
        json(conn, %{status: "ok"})

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{status: "error", errors: error_map(changeset)})
    end
  end

  # Changeset errors as %{field => [messages]}, translated the same way the
  # inline <.field_error> component renders them.
  defp error_map(changeset) do
    Ecto.Changeset.traverse_errors(changeset, &MetersWeb.CoreComponents.translate_error/1)
  end

  @guide_title "Martwe metry w mieszkaniu — czy deweloper prawidłowo ustalił powierzchnię użytkową lokalu?"
  @guide_description "Martwe metry to powierzchnia pod ścianami działowymi wliczona do metrażu mieszkania. Wyjaśniamy normę PN-ISO 9836, decyzje UOKiK, orzecznictwo sądów i nowe przepisy od 13 lutego 2026 r. — oraz kiedy nabywcy przysługuje zwrot części ceny."

  def guide(conn, _params) do
    conn
    |> assign(:page_title, @guide_title)
    |> assign(:meta_description, @guide_description)
    |> assign(:canonical_url, url(~p"/martwe-metry-w-mieszkaniu"))
    |> assign(:og_type, "article")
    |> render(:guide)
  end

  def privacy(conn, _params) do
    conn
    |> assign(:page_title, "Polityka prywatności")
    |> assign(
      :meta_description,
      "Polityka prywatności i informacja o przetwarzaniu danych osobowych."
    )
    |> assign(:canonical_url, url(~p"/polityka-prywatnosci"))
    |> render(:privacy)
  end

  # Bump when a page's content meaningfully changes so `lastmod` stays honest.
  @sitemap_lastmod "2026-09-29"

  @doc false
  def sitemap(conn, _params) do
    pages = [
      {url(~p"/"), "weekly", "1.0"},
      {url(~p"/martwe-metry-w-mieszkaniu"), "monthly", "0.8"},
      {url(~p"/polityka-prywatnosci"), "yearly", "0.3"}
    ]

    entries =
      Enum.map_join(pages, "\n", fn {loc, changefreq, priority} ->
        """
          <url>
            <loc>#{loc}</loc>
            <lastmod>#{@sitemap_lastmod}</lastmod>
            <changefreq>#{changefreq}</changefreq>
            <priority>#{priority}</priority>
          </url>\
        """
      end)

    body = """
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
    #{entries}
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

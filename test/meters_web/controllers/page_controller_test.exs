defmodule MetersWeb.PageControllerTest do
  use MetersWeb.ConnCase, async: true

  import Swoosh.TestAssertions

  alias Meters.Repo
  alias Meters.Leads.Lead

  @valid_params %{
    "name" => "Anna",
    "phone" => "600 100 200",
    "email" => "anna@example.com",
    "developer" => "XYZ Development",
    "investment" => "Osiedle Zielone Tarasy",
    "purchase_year" => "2021",
    "settlement_area" => "tak",
    "estimated_overpayment" => "27 500 zł",
    "consent_contact" => "true",
    "consent_law_firm" => "true"
  }

  describe "GET /" do
    test "renders the landing page with the lead form", %{conn: conn} do
      conn = get(conn, ~p"/")
      html = html_response(conn, 200)

      assert html =~ "Bezpłatna analiza umowy"
      assert html =~ ~s(id="leadForm")
      assert html =~ ~s(id="calculator")
    end

    test "renders the form and a hidden success box (toggled client-side)", %{conn: conn} do
      html = conn |> get(~p"/") |> html_response(200)

      assert html =~ ~s(id="leadForm")
      assert html =~ ~s(id="successBox")
      # The box starts hidden; JS reveals it after a successful fetch submit.
      assert html =~ ~s(id="successBox" style="display:none")
      assert html =~ "Zgłoszenie wysłane"
    end

    test "includes SEO meta tags and FAQ structured data", %{conn: conn} do
      html = conn |> get(~p"/") |> html_response(200)

      assert html =~ ~s(rel="canonical")
      assert html =~ ~s(property="og:title")
      assert html =~ ~s(name="twitter:card")
      assert html =~ ~s(type="application/ld+json")
      assert html =~ ~s("@type":"FAQPage")
    end

    test "wires up the analytics script and tagged conversion events", %{conn: conn} do
      html = conn |> get(~p"/") |> html_response(200)

      # first-party Plausible proxy script tag
      assert html =~ ~s(src="/js/stats.js")
      # click-tagged events (the programmatic Kalkulator/Scroll events live in landing.js)
      assert html =~ "plausible-event-name=Zgloszenie"
      assert html =~ "plausible-event-name=CTA+Kalkulator"
      assert html =~ "plausible-event-name=FAQ"
    end
  end

  describe "GET /martwe-metry-w-mieszkaniu" do
    test "renders the guide with SEO tags, Article JSON-LD and a kancelaria link", %{conn: conn} do
      html = conn |> get(~p"/martwe-metry-w-mieszkaniu") |> html_response(200)

      assert html =~ "Martwe metry w mieszkaniu"
      assert html =~ ~s(rel="canonical")
      assert html =~ ~s("@type":"Article")
      assert html =~ "PN-ISO 9836"
      # keyword-rich backlink to the kancelaria (SEO for kkadwokat.pl)
      assert html =~ ~s(href="https://kkadwokat.pl")
    end
  end

  describe "GET /polityka-prywatnosci" do
    test "renders the privacy policy page", %{conn: conn} do
      html = conn |> get(~p"/polityka-prywatnosci") |> html_response(200)

      assert html =~ "Polityka prywatności"
      assert html =~ "Administrator danych"
      assert html =~ ~s(rel="canonical")
    end
  end

  describe "GET /sitemap.xml" do
    test "lists every page with lastmod", %{conn: conn} do
      conn = get(conn, ~p"/sitemap.xml")

      assert response_content_type(conn, :xml)
      body = response(conn, 200)
      assert body =~ "<urlset"
      assert body =~ "<loc>"
      assert body =~ "/martwe-metry-w-mieszkaniu</loc>"
      assert body =~ "/polityka-prywatnosci</loc>"
      assert body =~ "<lastmod>"
    end
  end

  describe "POST /leads" do
    test "creates a lead, sends an e-mail and returns ok JSON on valid params", %{conn: conn} do
      conn = post(conn, ~p"/leads", %{"lead" => @valid_params})

      assert json_response(conn, 200) == %{"status" => "ok"}

      assert [%Lead{email: "anna@example.com"}] = Repo.all(Lead)
      assert_email_sent(fn email -> assert email.subject =~ "Anna" end)
    end

    test "returns 422 with per-field Polish errors on invalid params", %{conn: conn} do
      conn = post(conn, ~p"/leads", %{"lead" => %{@valid_params | "email" => "nope"}})

      body = json_response(conn, 422)
      assert body["status"] == "error"
      assert body["errors"]["email"] == ["Podaj poprawny adres e-mail"]
      assert Repo.all(Lead) == []
      assert_no_email_sent()
    end

    test "captures the referer as the lead source when none is supplied", %{conn: conn} do
      conn =
        conn
        |> put_req_header("referer", "https://google.com/")
        |> post(~p"/leads", %{"lead" => Map.delete(@valid_params, "source")})

      assert json_response(conn, 200) == %{"status" => "ok"}
      assert [%Lead{source: "https://google.com/"}] = Repo.all(Lead)
    end
  end
end

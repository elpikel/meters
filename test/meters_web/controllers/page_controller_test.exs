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

    test "shows the success box when redirected with ?sent=true", %{conn: conn} do
      conn = get(conn, ~p"/?sent=true")
      html = html_response(conn, 200)

      assert html =~ ~s(id="successBox")
      assert html =~ "Zgłoszenie wysłane"
      refute html =~ ~s(id="leadForm")
    end

    test "includes SEO meta tags and FAQ structured data", %{conn: conn} do
      html = conn |> get(~p"/") |> html_response(200)

      assert html =~ ~s(rel="canonical")
      assert html =~ ~s(property="og:title")
      assert html =~ ~s(name="twitter:card")
      assert html =~ ~s(type="application/ld+json")
      assert html =~ ~s("@type":"FAQPage")
    end
  end

  describe "GET /sitemap.xml" do
    test "returns an XML sitemap listing the home page", %{conn: conn} do
      conn = get(conn, ~p"/sitemap.xml")

      assert response_content_type(conn, :xml)
      body = response(conn, 200)
      assert body =~ "<urlset"
      assert body =~ "<loc>"
    end
  end

  describe "POST /leads" do
    test "creates a lead, sends an e-mail and redirects on valid params", %{conn: conn} do
      conn = post(conn, ~p"/leads", %{"lead" => @valid_params})

      assert redirected_to(conn) == "/?sent=true#zgloszenie"

      assert [%Lead{email: "anna@example.com"}] = Repo.all(Lead)
      assert_email_sent(fn email -> assert email.subject =~ "Anna" end)
    end

    test "re-renders the form with errors on invalid params", %{conn: conn} do
      conn = post(conn, ~p"/leads", %{"lead" => %{@valid_params | "email" => "nope"}})

      assert html_response(conn, 422) =~ ~s(id="leadForm")
      assert Repo.all(Lead) == []
      assert_no_email_sent()
    end

    test "captures the referer as the lead source when none is supplied", %{conn: conn} do
      conn =
        conn
        |> put_req_header("referer", "https://google.com/")
        |> post(~p"/leads", %{"lead" => Map.delete(@valid_params, "source")})

      assert redirected_to(conn) =~ "sent=true"
      assert [%Lead{source: "https://google.com/"}] = Repo.all(Lead)
    end
  end
end

defmodule Meters.LeadsTest do
  use Meters.DataCase, async: true

  import Swoosh.TestAssertions

  alias Meters.Leads
  alias Meters.Leads.Lead

  @valid_attrs %{
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

  describe "create_lead/1" do
    test "persists a lead with valid attributes" do
      assert {:ok, %Lead{} = lead} = Leads.create_lead(@valid_attrs)
      assert lead.id
      assert lead.name == "Anna"
      assert lead.email == "anna@example.com"
      assert lead.consent_contact
      assert lead.consent_law_firm
    end

    test "sends a notification e-mail on success" do
      assert {:ok, lead} = Leads.create_lead(@valid_attrs)

      assert_email_sent(fn email ->
        assert email.to == [{"", "el.pikel@gmail.com"}]
        assert email.subject =~ lead.name
        assert email.text_body =~ lead.email
        # HTML body styled to match the landing page (inline CSS)
        assert email.html_body =~ lead.name
        assert email.html_body =~ ~s(style=")
        assert email.html_body =~ "Szacowana nadpłata"
      end)
    end

    test "requires the mandatory fields" do
      assert {:error, changeset} = Leads.create_lead(%{})

      errors = errors_on(changeset)
      assert errors.name
      assert errors.phone
      assert errors.email
      assert errors.developer
      assert errors.investment
      assert errors.purchase_year
    end

    test "requires both consents to be accepted" do
      attrs =
        Map.merge(@valid_attrs, %{"consent_contact" => "false", "consent_law_firm" => "false"})

      assert {:error, changeset} = Leads.create_lead(attrs)
      assert errors_on(changeset).consent_contact
      assert errors_on(changeset).consent_law_firm
    end

    test "rejects an invalid e-mail" do
      attrs = Map.put(@valid_attrs, "email", "not-an-email")

      assert {:error, changeset} = Leads.create_lead(attrs)
      assert errors_on(changeset).email
    end

    test "does not send an e-mail when validation fails" do
      assert {:error, _changeset} = Leads.create_lead(%{})
      assert_no_email_sent()
    end
  end
end

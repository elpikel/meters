defmodule Meters.Leads.LeadNotifier do
  @moduledoc """
  Builds and delivers the internal notification e-mail sent when a new lead
  submits the contract-analysis form.
  """
  import Swoosh.Email

  require Logger

  alias Meters.Leads.Lead
  alias Meters.Mailer

  @doc """
  Delivers the "new lead" notification. Returns `{:ok, _}` or `{:error, reason}`
  and logs any delivery failure — callers may safely ignore the result.
  """
  def deliver_new_lead(%Lead{} = lead) do
    lead
    |> build_email()
    |> Mailer.deliver()
    |> case do
      {:ok, _meta} = ok ->
        ok

      {:error, reason} = error ->
        Logger.error("Failed to deliver new lead e-mail for ##{lead.id}: #{inspect(reason)}")
        error
    end
  end

  defp build_email(%Lead{} = lead) do
    config = Application.get_env(:meters, __MODULE__, [])
    to = Keyword.get(config, :to, "leady@example.com")
    from = Keyword.get(config, :from, {"Kalkulator metrów", "noreply@example.com"})

    new()
    |> to(to)
    |> from(from)
    |> reply_to(lead.email)
    |> subject("Nowe zgłoszenie: #{lead.name} — #{lead.developer}")
    |> html_body(html_body(lead))
    |> text_body(text_body(lead))
  end

  # HTML body styled with inline CSS to match the landing page (technical-drawing
  # look). Inline styles are required for reliable rendering across e-mail clients.
  defp html_body(%Lead{} = lead) do
    rows =
      [
        {"Telefon", lead.phone},
        {"E-mail", lead.email},
        {"Rok zakupu", lead.purchase_year},
        {"Pow. rozliczeniowa", lead.settlement_area}
      ]
      |> Enum.map_join("", fn {label, value} -> field_row(label, value) end)

    """
    <!DOCTYPE html>
    <html lang="pl">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
      </head>
      <body style="margin:0;padding:0;background-color:#F6F5F1;">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#F6F5F1;padding:24px 12px;">
          <tr>
            <td align="center">
              <table role="presentation" width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;background-color:#ffffff;border:2px solid #191C21;border-radius:6px;">
                <tr>
                  <td style="background-color:#F2C41D;border-bottom:2px solid #191C21;padding:12px 20px;font-family:'Courier New',monospace;font-size:12px;letter-spacing:0.12em;text-transform:uppercase;color:#191C21;font-weight:bold;">
                    Nowe zgłoszenie &bull; Martwe Metry
                  </td>
                </tr>
                <tr>
                  <td style="padding:20px 20px 4px 20px;">
                    <div style="font-family:Arial,Helvetica,sans-serif;font-weight:800;font-size:22px;color:#191C21;line-height:1.2;">#{esc(lead.name)}</div>
                    <div style="font-family:Arial,Helvetica,sans-serif;font-size:14px;color:#4A4E57;margin-top:4px;">#{esc(lead.developer)} &mdash; #{esc(lead.investment)}</div>
                  </td>
                </tr>
                <tr>
                  <td style="padding:12px 20px 0 20px;">
                    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="border:2px dashed #B9422F;border-radius:6px;background-color:#FDF6F0;">
                      <tr>
                        <td style="padding:14px 18px;text-align:center;">
                          <div style="font-family:'Courier New',monospace;font-size:11px;text-transform:uppercase;letter-spacing:0.08em;color:#4A4E57;">Szacowana nadpłata</div>
                          <div style="font-family:'Courier New',monospace;font-weight:bold;font-size:26px;color:#B9422F;margin-top:4px;">#{esc(lead.estimated_overpayment || "—")}</div>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
                <tr>
                  <td style="padding:16px 20px 4px 20px;">
                    <table role="presentation" width="100%" cellpadding="0" cellspacing="0">#{rows}</table>
                  </td>
                </tr>
                <tr>
                  <td style="padding:6px 20px 18px 20px;font-family:'Courier New',monospace;font-size:12px;color:#4A4E57;">
                    Zgody: kontakt <strong style="color:#2E7D4F;">#{yes_no(lead.consent_contact)}</strong> &bull; kancelaria <strong style="color:#2E7D4F;">#{yes_no(lead.consent_law_firm)}</strong>
                  </td>
                </tr>
                <tr>
                  <td style="background-color:#F6F5F1;border-top:2px solid #191C21;padding:12px 20px;font-family:'Courier New',monospace;font-size:11px;color:#4A4E57;">
                    Źródło: #{esc(lead.source || "—")}<br />
                    Odpowiedz na tego maila, aby skontaktować się ze zgłaszającym.
                  </td>
                </tr>
              </table>
            </td>
          </tr>
        </table>
      </body>
    </html>
    """
  end

  defp field_row(label, value) do
    """
    <tr>
      <td style="padding:8px 0;border-bottom:1px solid #D8D6CE;font-family:'Courier New',monospace;font-size:11px;letter-spacing:0.06em;text-transform:uppercase;color:#4A4E57;white-space:nowrap;vertical-align:top;">#{esc(label)}</td>
      <td style="padding:8px 0 8px 16px;border-bottom:1px solid #D8D6CE;font-family:Arial,Helvetica,sans-serif;font-size:15px;color:#191C21;font-weight:600;">#{esc(value)}</td>
    </tr>
    """
  end

  defp esc(nil), do: "—"
  defp esc(value), do: value |> to_string() |> Plug.HTML.html_escape()

  defp text_body(%Lead{} = lead) do
    """
    Nowe zgłoszenie z formularza analizy umowy.

    Imię:                #{lead.name}
    Telefon:             #{lead.phone}
    E-mail:              #{lead.email}
    Deweloper:           #{lead.developer}
    Inwestycja:          #{lead.investment}
    Rok zakupu:          #{lead.purchase_year}
    Pow. rozliczeniowa:  #{lead.settlement_area}
    Szacunek nadpłaty:   #{lead.estimated_overpayment || "—"}
    Źródło:              #{lead.source || "—"}

    Zgody:
    - kontakt:           #{yes_no(lead.consent_contact)}
    - kancelaria:        #{yes_no(lead.consent_law_firm)}
    """
  end

  defp yes_no(true), do: "tak"
  defp yes_no(_), do: "nie"
end

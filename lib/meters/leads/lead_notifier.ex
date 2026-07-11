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
    |> text_body(text_body(lead))
  end

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

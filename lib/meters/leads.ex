defmodule Meters.Leads do
  @moduledoc """
  The Leads context — creating and managing landing-page lead submissions.
  """

  alias Meters.Leads.Lead
  alias Meters.Leads.LeadNotifier
  alias Meters.Repo

  @doc """
  Returns a changeset for tracking lead form changes (used to render the form).
  """
  def change_lead(%Lead{} = lead \\ %Lead{}, attrs \\ %{}) do
    Lead.changeset(lead, attrs)
  end

  @doc """
  Creates a lead and, on success, sends the internal notification e-mail.

  The e-mail is best-effort: a delivery failure is logged but does not fail
  the submission, since the lead is already safely persisted.
  """
  def create_lead(attrs) do
    with {:ok, lead} <- %Lead{} |> Lead.changeset(attrs) |> Repo.insert() do
      _ = LeadNotifier.deliver_new_lead(lead)
      {:ok, lead}
    end
  end
end

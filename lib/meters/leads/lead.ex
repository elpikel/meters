defmodule Meters.Leads.Lead do
  @moduledoc """
  A prospect who requested a free contract analysis via the landing page form.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @purchase_years ~w(2026 2025 2024 2023 2022 2021 2020 wcześniej)
  @settlement_area_values ~w(tak nie)a |> Enum.map(&to_string/1)

  schema "leads" do
    field :name, :string
    field :phone, :string
    field :email, :string
    field :developer, :string
    field :investment, :string
    field :purchase_year, :string
    field :settlement_area, :string, default: "nie wiem"
    field :estimated_overpayment, :string
    field :source, :string
    field :consent_contact, :boolean, default: false
    field :consent_law_firm, :boolean, default: false

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds a changeset for creating a lead from public form params.
  """
  def changeset(lead, attrs) do
    lead
    |> cast(attrs, [
      :name,
      :phone,
      :email,
      :developer,
      :investment,
      :purchase_year,
      :settlement_area,
      :estimated_overpayment,
      :source,
      :consent_contact,
      :consent_law_firm
    ])
    |> validate_required([:name, :phone, :email, :developer, :investment, :purchase_year])
    |> validate_length(:name, max: 120)
    |> validate_length(:developer, max: 160)
    |> validate_length(:investment, max: 160)
    |> validate_format(:email, ~r/^[^@\s]+@[^@\s]+\.[^@\s]+$/,
      message: "podaj poprawny adres e-mail"
    )
    |> validate_format(:phone, ~r/^[0-9+\s()-]{6,20}$/, message: "podaj poprawny numer telefonu")
    |> validate_inclusion(:purchase_year, @purchase_years)
    |> validate_inclusion(:settlement_area, ["nie wiem" | @settlement_area_values])
    |> validate_acceptance(:consent_contact, message: "zgoda jest wymagana")
    |> validate_acceptance(:consent_law_firm, message: "zgoda jest wymagana")
  end

  @doc "Allowed values for the year-of-purchase select."
  def purchase_years, do: @purchase_years
end

defmodule Meters.Repo.Migrations.CreateLeads do
  use Ecto.Migration

  def change do
    create table(:leads) do
      add :name, :string, null: false
      add :phone, :string, null: false
      add :email, :string, null: false
      add :developer, :string, null: false
      add :investment, :string, null: false
      add :purchase_year, :string, null: false
      add :settlement_area, :string, null: false, default: "nie wiem"
      add :estimated_overpayment, :string
      add :source, :string
      add :consent_contact, :boolean, null: false, default: false
      add :consent_law_firm, :boolean, null: false, default: false

      timestamps(type: :utc_datetime)
    end

    create index(:leads, [:email])
    create index(:leads, [:inserted_at])
  end
end

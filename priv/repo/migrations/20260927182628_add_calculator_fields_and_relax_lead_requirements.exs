defmodule Meters.Repo.Migrations.AddCalculatorFieldsAndRelaxLeadRequirements do
  use Ecto.Migration

  def change do
    alter table(:leads) do
      # Raw calculator inputs the visitor set (display strings, e.g. "11 000 zł",
      # "2,5 m²") — kept alongside the computed estimated_overpayment.
      add :contract_price_per_m2, :string
      add :wall_area_m2, :string
    end

    # developer/investment/purchase_year are now optional on the form, so they
    # may arrive null. Relax the NOT NULL constraints they were created with.
    alter table(:leads) do
      modify :developer, :string, null: true, from: {:string, null: false}
      modify :investment, :string, null: true, from: {:string, null: false}
      modify :purchase_year, :string, null: true, from: {:string, null: false}
    end
  end
end

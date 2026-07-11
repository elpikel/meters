defmodule Meters.Repo do
  use Ecto.Repo,
    otp_app: :meters,
    adapter: Ecto.Adapters.Postgres
end

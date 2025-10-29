defmodule Tuxland.Repo do
  use Ecto.Repo,
    otp_app: :tuxland,
    adapter: Ecto.Adapters.Postgres
end

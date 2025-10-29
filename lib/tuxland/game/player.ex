defmodule Tuxland.Game.Player do
  @moduledoc """
  Represents a player in the Tux Land game.
  """

  @enforce_keys [:id, :name, :tux_variant]
  defstruct [
    :id,
    :name,
    :position,
    :tux_variant,  # :laptop | :terminal | :coffee | :hoodie
    connected: true
  ]

  @type t :: %__MODULE__{
    id: String.t(),
    name: String.t(),
    position: non_neg_integer() | nil,
    tux_variant: atom(),
    connected: boolean()
  }
end

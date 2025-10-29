defmodule Tuxland.Game.Card do
  @moduledoc """
  Represents a card in the Tux Land game.

  Card types:
  - :single - Move to the next space of the specified color
  - :double - Move to the second space of the specified color
  - :location - Move directly to a named location
  """

  @enforce_keys [:type, :color]
  defstruct [
    :type,              # :single | :double | :location
    :color,             # :red | :purple | :yellow | :blue | :orange | :green
    :location_name,     # String, only for location cards
    :location_position  # Integer, only for location cards
  ]

  @type t :: %__MODULE__{
    type: :single | :double | :location,
    color: atom(),
    location_name: String.t() | nil,
    location_position: integer() | nil
  }
end

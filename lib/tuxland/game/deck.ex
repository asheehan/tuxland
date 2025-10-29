defmodule Tuxland.Game.Deck do
  @moduledoc """
  Manages the card deck for Tux Land.
  Total: 90 cards
  - 60 single color cards (10 per color)
  - 24 double color cards (4 per color)
  - 6 named location cards
  """

  alias Tuxland.Game.{Card, BoardLayout}

  @colors [:red, :purple, :yellow, :blue, :orange, :green]
  @single_per_color 10
  @double_per_color 4

  @doc "Generate a full shuffled deck"
  def new_deck do
    (single_cards() ++ double_cards() ++ location_cards())
    |> Enum.shuffle()
  end

  defp single_cards do
    Enum.flat_map(@colors, fn color ->
      for _ <- 1..@single_per_color do
        %Card{type: :single, color: color}
      end
    end)
  end

  defp double_cards do
    Enum.flat_map(@colors, fn color ->
      for _ <- 1..@double_per_color do
        %Card{type: :double, color: color}
      end
    end)
  end

  defp location_cards do
    BoardLayout.named_locations()
    |> Enum.map(fn location ->
      %Card{
        type: :location,
        color: location.color,
        location_name: location.name,
        location_position: location.position
      }
    end)
  end

  @doc "Draw a card from the deck. If empty, shuffle discard pile."
  def draw_card(deck, discard) when deck == [] do
    case discard do
      [] -> {:error, :no_cards}  # Should never happen in normal game
      _ ->
        new_deck = Enum.shuffle(discard)
        [card | remaining] = new_deck
        {:ok, card, remaining, []}
    end
  end

  def draw_card([card | remaining], discard) do
    {:ok, card, remaining, discard}
  end

  @doc "Add a card to the discard pile"
  def discard_card(card, discard) do
    [card | discard]
  end
end

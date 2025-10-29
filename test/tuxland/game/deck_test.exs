defmodule Tuxland.Game.DeckTest do
  use ExUnit.Case, async: true

  alias Tuxland.Game.{Deck, Card}

  describe "new_deck/0" do
    test "creates deck with 90 cards" do
      deck = Deck.new_deck()

      assert length(deck) == 90
    end

    test "includes 60 single color cards (10 per color)" do
      deck = Deck.new_deck()
      single_cards = Enum.filter(deck, fn card -> card.type == :single end)

      assert length(single_cards) == 60

      # Check 10 of each color
      colors = [:red, :purple, :yellow, :blue, :orange, :green]

      for color <- colors do
        count = Enum.count(single_cards, fn card -> card.color == color end)
        assert count == 10, "Expected 10 single #{color} cards, got #{count}"
      end
    end

    test "includes 24 double color cards (4 per color)" do
      deck = Deck.new_deck()
      double_cards = Enum.filter(deck, fn card -> card.type == :double end)

      assert length(double_cards) == 24

      colors = [:red, :purple, :yellow, :blue, :orange, :green]

      for color <- colors do
        count = Enum.count(double_cards, fn card -> card.color == color end)
        assert count == 4, "Expected 4 double #{color} cards, got #{count}"
      end
    end

    test "includes 6 location cards" do
      deck = Deck.new_deck()
      location_cards = Enum.filter(deck, fn card -> card.type == :location end)

      assert length(location_cards) == 6

      location_names = Enum.map(location_cards, fn card -> card.location_name end)

      assert "Kernel Kompile Canyon" in location_names
      assert "Repository Ridge" in location_names
      assert "Package Manager Paradise" in location_names
      assert "Dependency Hell" in location_names
      assert "Server Summit" in location_names
      assert "Boot Loop Bay" in location_names
    end

    test "deck is shuffled (not deterministic order)" do
      deck1 = Deck.new_deck()
      deck2 = Deck.new_deck()

      # It's extremely unlikely two shuffled decks are identical
      # (but technically possible, so we check first few cards)
      first_5_deck1 = Enum.take(deck1, 5)
      first_5_deck2 = Enum.take(deck2, 5)

      # This could theoretically fail, but probability is 1/(90 * 89 * 88 * 87 * 86)
      assert first_5_deck1 != first_5_deck2
    end
  end

  describe "draw_card/2" do
    test "draws top card from deck" do
      deck = [
        %Card{type: :single, color: :red},
        %Card{type: :double, color: :blue}
      ]
      discard = []

      {:ok, card, remaining_deck, new_discard} = Deck.draw_card(deck, discard)

      assert card == %Card{type: :single, color: :red}
      assert length(remaining_deck) == 1
      assert remaining_deck == [%Card{type: :double, color: :blue}]
      assert new_discard == []
    end

    test "reshuffles discard pile when deck is empty" do
      deck = []
      discard = [
        %Card{type: :single, color: :red},
        %Card{type: :double, color: :blue},
        %Card{type: :single, color: :green}
      ]

      {:ok, card, remaining_deck, new_discard} = Deck.draw_card(deck, discard)

      # Card should be one from discard
      assert card in discard
      # Remaining deck should have 2 cards
      assert length(remaining_deck) == 2
      # New discard should be empty
      assert new_discard == []
    end

    test "returns error when both deck and discard are empty" do
      deck = []
      discard = []

      result = Deck.draw_card(deck, discard)

      assert result == {:error, :no_cards}
    end
  end

  describe "discard_card/2" do
    test "adds card to discard pile" do
      card = %Card{type: :single, color: :red}
      discard = [%Card{type: :double, color: :blue}]

      new_discard = Deck.discard_card(card, discard)

      assert length(new_discard) == 2
      assert List.first(new_discard) == card
    end

    test "adds card to empty discard pile" do
      card = %Card{type: :single, color: :red}
      discard = []

      new_discard = Deck.discard_card(card, discard)

      assert new_discard == [card]
    end
  end
end

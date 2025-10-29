defmodule Tuxland.Game.CardTest do
  use ExUnit.Case, async: true

  alias Tuxland.Game.Card

  describe "Card struct" do
    test "creates a single color card" do
      card = %Card{type: :single, color: :red}

      assert card.type == :single
      assert card.color == :red
      assert card.location_name == nil
      assert card.location_position == nil
    end

    test "creates a double color card" do
      card = %Card{type: :double, color: :blue}

      assert card.type == :double
      assert card.color == :blue
    end

    test "creates a location card with position and name" do
      card = %Card{
        type: :location,
        color: :green,
        location_name: "Repository Ridge",
        location_position: 45
      }

      assert card.type == :location
      assert card.color == :green
      assert card.location_name == "Repository Ridge"
      assert card.location_position == 45
    end
  end
end

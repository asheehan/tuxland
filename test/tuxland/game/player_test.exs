defmodule Tuxland.Game.PlayerTest do
  use ExUnit.Case, async: true

  alias Tuxland.Game.Player

  describe "Player struct" do
    test "creates a player with required fields" do
      player = %Player{
        id: "player-123",
        name: "Alice",
        tux_variant: :laptop
      }

      assert player.id == "player-123"
      assert player.name == "Alice"
      assert player.tux_variant == :laptop
      assert player.position == nil
      assert player.connected == true
    end

    test "creates a player with custom position" do
      player = %Player{
        id: "player-456",
        name: "Bob",
        tux_variant: :terminal,
        position: 25
      }

      assert player.position == 25
    end

    test "creates a player with disconnected status" do
      player = %Player{
        id: "player-789",
        name: "Carol",
        tux_variant: :coffee,
        connected: false
      }

      assert player.connected == false
    end

    test "supports all tux variants" do
      variants = [:laptop, :terminal, :coffee, :hoodie]

      for variant <- variants do
        player = %Player{
          id: "test",
          name: "Test",
          tux_variant: variant
        }

        assert player.tux_variant == variant
      end
    end
  end
end

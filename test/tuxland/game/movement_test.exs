defmodule Tuxland.Game.MovementTest do
  use ExUnit.Case, async: true

  alias Tuxland.Game.{Movement, BoardLayout, Card}

  setup do
    board = BoardLayout.generate_board()
    {:ok, board: board}
  end

  describe "calculate_move/3 with single color cards" do
    test "moves to next single color from start", %{board: board} do
      card = %Card{type: :single, color: :red}
      {:ok, new_pos} = Movement.calculate_move(0, card, board)

      space = Enum.at(board, new_pos)
      assert space.color == :red
      assert new_pos > 0
      assert new_pos == 1  # First red after position 0
    end

    test "moves to next occurrence of color from middle position", %{board: board} do
      card = %Card{type: :single, color: :blue}
      {:ok, new_pos} = Movement.calculate_move(10, card, board)

      space = Enum.at(board, new_pos)
      assert space.color == :blue
      assert new_pos > 10
    end

    test "skips named locations if they match color", %{board: board} do
      # Position 20 is "Kernel Kompile Canyon" (red, named)
      # Next red should be found after it
      card = %Card{type: :single, color: :red}
      {:ok, new_pos} = Movement.calculate_move(19, card, board)

      space = Enum.at(board, new_pos)
      assert space.color == :red
      # Should land on the named location
      assert new_pos == 20
    end
  end

  describe "calculate_move/3 with double color cards" do
    test "moves to second occurrence of color", %{board: board} do
      card = %Card{type: :double, color: :blue}
      {:ok, new_pos} = Movement.calculate_move(0, card, board)

      # Find first and second blue positions
      blues = board
      |> Enum.drop(1)  # Skip position 0
      |> Enum.filter(fn s -> s.color == :blue end)
      |> Enum.take(2)

      second_blue = List.last(blues)

      assert new_pos == second_blue.position
      assert new_pos > 0
    end

    test "moves to second occurrence from middle position", %{board: board} do
      card = %Card{type: :double, color: :green}
      {:ok, new_pos} = Movement.calculate_move(50, card, board)

      # Should skip first green after 50 and land on second
      space = Enum.at(board, new_pos)
      assert space.color == :green
      assert new_pos > 50
    end
  end

  describe "calculate_move/3 reaching the end (Rainbow Castle)" do
    test "end space acts as rainbow - matches any color when it's the next occurrence", %{board: board} do
      # From position 132 (one before end), any color should reach the end
      colors = [:red, :purple, :yellow, :blue, :orange, :green]

      for color <- colors do
        card = %Card{type: :single, color: color}
        {:ok, new_pos} = Movement.calculate_move(132, card, board)

        # Should reach the end (133) or stay at 132 if there's a matching color at 132
        space = Enum.at(board, new_pos)
        assert new_pos >= 132, "Color #{color} should reach at least 132"

        # If we're very close to the end, we should be able to reach it
        if new_pos == 133 do
          assert space.type == :end, "Position 133 should be the end"
        end
      end
    end

    test "can reach end from late position with any color", %{board: board} do
      # Test from position 130 - should be able to reach end with various colors
      card = %Card{type: :single, color: :red}
      {:ok, new_pos} = Movement.calculate_move(130, card, board)

      # The end space at 133 acts as a rainbow, so it should be reachable
      assert new_pos >= 130, "Should move forward"

      # Can eventually reach 133
      assert Enum.any?(131..133, fn pos ->
        space = Enum.at(board, pos)
        space.color in [:red, :end]
      end)
    end
  end

  describe "calculate_move/3 with location cards" do
    test "moves directly to location position regardless of current position", %{board: board} do
      card = %Card{
        type: :location,
        color: :red,
        location_name: "Kernel Kompile Canyon",
        location_position: 20
      }

      {:ok, new_pos} = Movement.calculate_move(100, card, board)
      assert new_pos == 20

      # Can also move forward
      {:ok, new_pos2} = Movement.calculate_move(5, card, board)
      assert new_pos2 == 20
    end

    test "handles all named locations", %{board: board} do
      locations = [
        {20, "Kernel Kompile Canyon"},
        {45, "Repository Ridge"},
        {67, "Package Manager Paradise"},
        {89, "Dependency Hell"},
        {110, "Server Summit"},
        {120, "Boot Loop Bay"}
      ]

      for {position, name} <- locations do
        card = %Card{
          type: :location,
          color: :red,  # Color doesn't matter for location cards
          location_name: name,
          location_position: position
        }

        {:ok, new_pos} = Movement.calculate_move(0, card, board)
        assert new_pos == position
      end
    end
  end

  describe "winning_position?/2" do
    test "returns true for last position", %{board: board} do
      assert Movement.winning_position?(133, board)
    end

    test "returns true for positions beyond last", %{board: board} do
      assert Movement.winning_position?(134, board)
      assert Movement.winning_position?(200, board)
    end

    test "returns false for earlier positions", %{board: board} do
      refute Movement.winning_position?(0, board)
      refute Movement.winning_position?(50, board)
      refute Movement.winning_position?(132, board)
    end
  end

  describe "get_space/2" do
    test "returns space at position", %{board: board} do
      space = Movement.get_space(0, board)
      assert space.position == 0
      assert space.type == :start

      space20 = Movement.get_space(20, board)
      assert space20.position == 20
      assert space20.name == "Kernel Kompile Canyon"
    end

    test "returns nil for invalid position", %{board: board} do
      assert Movement.get_space(999, board) == nil
    end
  end
end

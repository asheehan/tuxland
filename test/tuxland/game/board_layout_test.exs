defmodule Tuxland.Game.BoardLayoutTest do
  use ExUnit.Case, async: true

  alias Tuxland.Game.BoardLayout

  describe "generate_board/0" do
    test "generates 134 spaces" do
      board = BoardLayout.generate_board()

      assert length(board) == 134
    end

    test "first space is start position" do
      board = BoardLayout.generate_board()
      first_space = List.first(board)

      assert first_space.position == 0
      assert first_space.type == :start
      assert first_space.name == "Boot Sector"
    end

    test "last space is end position" do
      board = BoardLayout.generate_board()
      last_space = List.last(board)

      assert last_space.position == 133
      assert last_space.type == :end
      assert last_space.name == "Kernel Castle"
    end

    test "contains 6 colors in pattern" do
      board = BoardLayout.generate_board()
      colors = [:red, :purple, :yellow, :blue, :orange, :green]

      # Check that normal spaces use these colors
      normal_spaces = Enum.filter(board, fn s -> s.type == :normal end)

      for space <- normal_spaces do
        assert space.color in colors
      end
    end

    test "named locations are at correct positions" do
      board = BoardLayout.generate_board()

      kernel_kompile = Enum.at(board, 20)
      assert kernel_kompile.type == :named
      assert kernel_kompile.name == "Kernel Kompile Canyon"
      assert kernel_kompile.position == 20

      repository_ridge = Enum.at(board, 45)
      assert repository_ridge.type == :named
      assert repository_ridge.name == "Repository Ridge"
      assert repository_ridge.position == 45

      package_manager = Enum.at(board, 67)
      assert package_manager.type == :named
      assert package_manager.name == "Package Manager Paradise"
      assert package_manager.position == 67

      dependency_hell = Enum.at(board, 89)
      assert dependency_hell.type == :named
      assert dependency_hell.name == "Dependency Hell"
      assert dependency_hell.position == 89

      server_summit = Enum.at(board, 110)
      assert server_summit.type == :named
      assert server_summit.name == "Server Summit"
      assert server_summit.position == 110

      boot_loop = Enum.at(board, 120)
      assert boot_loop.type == :named
      assert boot_loop.name == "Boot Loop Bay"
      assert boot_loop.position == 120
    end

    test "all spaces have required fields" do
      board = BoardLayout.generate_board()

      for space <- board do
        assert Map.has_key?(space, :position)
        assert Map.has_key?(space, :color)
        assert Map.has_key?(space, :type)
        assert Map.has_key?(space, :name)
        assert space.type in [:start, :end, :normal, :named]
      end
    end
  end

  describe "named_locations/0" do
    test "returns all 6 named locations" do
      locations = BoardLayout.named_locations()

      assert length(locations) == 6
    end

    test "each location has name, position, and color" do
      locations = BoardLayout.named_locations()

      for location <- locations do
        assert is_binary(location.name)
        assert is_integer(location.position)
        assert is_atom(location.color)
      end
    end
  end
end

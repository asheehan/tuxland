defmodule Tuxland.Game.BoardLayout do
  @moduledoc """
  Defines the complete board layout for Tux Land.
  134 spaces total with 6 named locations strategically placed.
  """

  # Named location positions (space indices)
  @kernel_kompile_canyon 20    # Early setback
  @repository_ridge 45          # Early-mid forward
  @package_manager_paradise 67  # Mid forward
  @dependency_hell 89           # Mid-late setback
  @server_summit 110            # Late forward
  @boot_loop_bay 120            # Late setback

  @doc """
  Returns the complete board layout as a list of space structs.
  Each space has: position (0-133), color, type (:normal | :named), name (if named)
  """
  def generate_board do
    0..133
    |> Enum.map(&create_space/1)
  end

  defp create_space(0), do: %{position: 0, color: :start, type: :start, name: "Boot Sector"}
  defp create_space(133), do: %{position: 133, color: :end, type: :end, name: "Kernel Castle"}

  defp create_space(@kernel_kompile_canyon), do: %{position: @kernel_kompile_canyon, color: :red, type: :named, name: "Kernel Kompile Canyon"}
  defp create_space(@repository_ridge), do: %{position: @repository_ridge, color: :green, type: :named, name: "Repository Ridge"}
  defp create_space(@package_manager_paradise), do: %{position: @package_manager_paradise, color: :blue, type: :named, name: "Package Manager Paradise"}
  defp create_space(@dependency_hell), do: %{position: @dependency_hell, color: :red, type: :named, name: "Dependency Hell"}
  defp create_space(@server_summit), do: %{position: @server_summit, color: :green, type: :named, name: "Server Summit"}
  defp create_space(@boot_loop_bay), do: %{position: @boot_loop_bay, color: :orange, type: :named, name: "Boot Loop Bay"}

  defp create_space(position) do
    # Calculate color based on position using modulo pattern
    colors = [:red, :purple, :yellow, :blue, :orange, :green]
    color_index = rem(position - 1, 6)

    %{
      position: position,
      color: Enum.at(colors, color_index),
      type: :normal,
      name: nil
    }
  end

  @doc "Get all named locations for card deck generation"
  def named_locations do
    [
      %{name: "Kernel Kompile Canyon", position: @kernel_kompile_canyon, color: :red},
      %{name: "Repository Ridge", position: @repository_ridge, color: :green},
      %{name: "Package Manager Paradise", position: @package_manager_paradise, color: :blue},
      %{name: "Dependency Hell", position: @dependency_hell, color: :red},
      %{name: "Server Summit", position: @server_summit, color: :green},
      %{name: "Boot Loop Bay", position: @boot_loop_bay, color: :orange}
    ]
  end
end

defmodule Tuxland.Game.Movement do
  @moduledoc """
  Handles all player movement logic based on cards drawn.
  """

  alias Tuxland.Game.Card

  @doc """
  Calculate the new position for a player based on the card drawn.

  Returns: {:ok, new_position}
  """
  def calculate_move(current_position, %Card{type: :single, color: color}, board) do
    find_next_color(current_position, color, board, 1)
  end

  def calculate_move(current_position, %Card{type: :double, color: color}, board) do
    find_next_color(current_position, color, board, 2)
  end

  def calculate_move(_current_position, %Card{type: :location, location_position: position}, _board) do
    {:ok, position}
  end

  @doc """
  Find the Nth occurrence of a color after the current position.

  ## Examples
      iex> find_next_color(5, :red, board, 1)
      {:ok, 7}

      iex> find_next_color(5, :red, board, 2)
      {:ok, 13}
  """
  def find_next_color(current_position, color, board, occurrence_count) do
    board
    |> Enum.drop(current_position + 1)  # Start searching after current position
    |> Enum.filter(fn space -> space.color == color end)
    |> Enum.take(occurrence_count)
    |> List.last()
    |> case do
      nil -> {:ok, current_position}  # Stay put if no match found (shouldn't happen)
      space -> {:ok, space.position}
    end
  end

  @doc "Check if a position is the winning position"
  def winning_position?(position, board) do
    position >= length(board) - 1
  end

  @doc "Get space details at a specific position"
  def get_space(position, board) do
    Enum.at(board, position)
  end
end

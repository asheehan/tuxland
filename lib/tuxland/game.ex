defmodule Tuxland.Game do
  @moduledoc """
  Public API for game management.
  This module provides a clean interface for LiveViews to interact with game servers.
  """

  alias Tuxland.Game.Server

  @doc "Create a new game room"
  def create_room(room_code) do
    DynamicSupervisor.start_child(
      Tuxland.GameSupervisor,
      {Server, room_code}
    )
  end

  @doc "Get game state"
  def get_state(room_code) do
    try do
      Server.get_state(room_code)
    catch
      :exit, _ -> {:error, :not_found}
    end
  end

  @doc "Check if a game room exists"
  def room_exists?(room_code) do
    case Registry.lookup(Tuxland.GameRegistry, room_code) do
      [] -> false
      _ -> true
    end
  end

  # Delegate other functions to Server
  defdelegate join_game(room_code, player_name, tux_variant), to: Server
  defdelegate leave_game(room_code, player_id), to: Server
  defdelegate start_game(room_code, host_id), to: Server
  defdelegate draw_card(room_code, player_id), to: Server
  defdelegate reset_game(room_code), to: Server
  defdelegate set_player_connection(room_code, player_id, connected), to: Server
end

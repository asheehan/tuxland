defmodule Tuxland.Game.Server do
  @moduledoc """
  GenServer that manages a single game room's state.
  Handles player management, game flow, and turn-based card drawing.
  """

  use GenServer
  require Logger

  alias Tuxland.Game.{Player, Deck, Movement, BoardLayout}

  # Client API

  @doc "Start a new game server"
  def start_link(room_code) do
    GenServer.start_link(__MODULE__, room_code, name: via_tuple(room_code))
  end

  @doc "Get the current game state"
  def get_state(room_code) do
    GenServer.call(via_tuple(room_code), :get_state)
  end

  @doc "Add a player to the game"
  def join_game(room_code, player_name, tux_variant) do
    GenServer.call(via_tuple(room_code), {:join_game, player_name, tux_variant})
  end

  @doc "Remove a player from the game"
  def leave_game(room_code, player_id) do
    GenServer.call(via_tuple(room_code), {:leave_game, player_id})
  end

  @doc "Start the game (host only)"
  def start_game(room_code, host_id) do
    GenServer.call(via_tuple(room_code), {:start_game, host_id})
  end

  @doc "Draw a card (current player only)"
  def draw_card(room_code, player_id) do
    GenServer.call(via_tuple(room_code), {:draw_card, player_id})
  end

  @doc "Reset game for play again"
  def reset_game(room_code) do
    GenServer.call(via_tuple(room_code), :reset_game)
  end

  @doc "Mark player as connected/disconnected"
  def set_player_connection(room_code, player_id, connected) do
    GenServer.cast(via_tuple(room_code), {:set_connection, player_id, connected})
  end

  # Server Callbacks

  @impl true
  def init(room_code) do
    state = %{
      room_code: room_code,
      players: [],
      current_player_index: 0,
      deck: Deck.new_deck(),
      discard_pile: [],
      board: BoardLayout.generate_board(),
      status: :waiting,  # :waiting | :active | :finished
      winner: nil,
      host_id: nil,
      last_card_drawn: nil,
      created_at: DateTime.utc_now()
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:join_game, player_name, tux_variant}, _from, state) do
    cond do
      state.status != :waiting ->
        {:reply, {:error, :game_already_started}, state}

      length(state.players) >= 4 ->
        {:reply, {:error, :game_full}, state}

      true ->
        player_id = generate_player_id()
        player = %Player{
          id: player_id,
          name: player_name,
          position: 0,
          tux_variant: tux_variant,
          connected: true
        }

        new_state = %{state |
          players: state.players ++ [player],
          host_id: state.host_id || player_id
        }

        broadcast_update(new_state, {:player_joined, player})
        {:reply, {:ok, player_id}, new_state}
    end
  end

  @impl true
  def handle_call({:leave_game, player_id}, _from, state) do
    new_players = Enum.reject(state.players, fn p -> p.id == player_id end)

    new_state = %{state | players: new_players}
    broadcast_update(new_state, {:player_left, player_id})

    # End server if no players left
    if new_players == [] do
      {:stop, :normal, :ok, new_state}
    else
      {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call({:start_game, host_id}, _from, state) do
    cond do
      state.host_id != host_id ->
        {:reply, {:error, :not_host}, state}

      length(state.players) < 1 ->
        {:reply, {:error, :need_more_players}, state}

      state.status != :waiting ->
        {:reply, {:error, :already_started}, state}

      true ->
        new_state = %{state | status: :active}
        broadcast_update(new_state, :game_started)
        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call({:draw_card, player_id}, _from, state) do
    current_player = Enum.at(state.players, state.current_player_index)

    cond do
      state.status != :active ->
        {:reply, {:error, :game_not_active}, state}

      current_player.id != player_id ->
        {:reply, {:error, :not_your_turn}, state}

      true ->
        # Draw card
        case Deck.draw_card(state.deck, state.discard_pile) do
          {:ok, card, new_deck, new_discard} ->
            # Calculate new position
            {:ok, new_position} = Movement.calculate_move(
              current_player.position,
              card,
              state.board
            )

            # Update player position
            updated_players = update_player_position(state.players, player_id, new_position)

            # Check for winner
            winner = if Movement.winning_position?(new_position, state.board) do
              player_id
            else
              nil
            end

            # Next turn
            next_index = rem(state.current_player_index + 1, length(state.players))

            new_state = %{state |
              deck: new_deck,
              discard_pile: Deck.discard_card(card, new_discard),
              players: updated_players,
              current_player_index: next_index,
              last_card_drawn: card,
              winner: winner,
              status: if(winner, do: :finished, else: :active)
            }

            broadcast_update(new_state, {:card_drawn, player_id, card, new_position})

            if winner do
              broadcast_update(new_state, {:game_won, player_id})
            end

            {:reply, {:ok, %{card: card, new_position: new_position}}, new_state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
    end
  end

  @impl true
  def handle_call(:reset_game, _from, state) do
    new_state = %{state |
      players: reset_player_positions(state.players),
      current_player_index: 0,
      deck: Deck.new_deck(),
      discard_pile: [],
      status: :active,
      winner: nil,
      last_card_drawn: nil
    }

    broadcast_update(new_state, :game_reset)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_cast({:set_connection, player_id, connected}, state) do
    updated_players = Enum.map(state.players, fn player ->
      if player.id == player_id do
        %{player | connected: connected}
      else
        player
      end
    end)

    new_state = %{state | players: updated_players}
    broadcast_update(new_state, {:connection_changed, player_id, connected})
    {:noreply, new_state}
  end

  # Helper Functions

  defp via_tuple(room_code) do
    {:via, Registry, {Tuxland.GameRegistry, room_code}}
  end

  defp generate_player_id do
    :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  end

  defp update_player_position(players, player_id, new_position) do
    Enum.map(players, fn player ->
      if player.id == player_id do
        %{player | position: new_position}
      else
        player
      end
    end)
  end

  defp reset_player_positions(players) do
    Enum.map(players, fn player ->
      %{player | position: 0}
    end)
  end

  defp broadcast_update(state, message) do
    Phoenix.PubSub.broadcast(
      Tuxland.PubSub,
      "game:#{state.room_code}",
      {:game_update, message, state}
    )
  end
end

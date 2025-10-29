defmodule TuxlandWeb.GameLive do
  use TuxlandWeb, :live_view

  alias Tuxland.Game

  @impl true
  def mount(%{"room_code" => room_code}, _session, socket) do
    if Game.room_exists?(room_code) do
      game_state = Game.get_state(room_code)

      if connected?(socket) do
        Phoenix.PubSub.subscribe(Tuxland.PubSub, "game:#{room_code}")
      end

      {:ok, assign(socket,
        room_code: room_code,
        player_id: nil,  # Will be set in handle_params
        game_state: game_state,
        card_animation: false,
        last_card: nil
      )}
    else
      {:ok,
        socket
        |> put_flash(:error, "Game not found")
        |> push_navigate(to: ~p"/")}
    end
  end

  @impl true
  def handle_params(%{"player_id" => player_id}, _uri, socket) do
    {:noreply, assign(socket, player_id: player_id)}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("draw_card", _params, socket) do
    require Logger
    Logger.debug("Draw card clicked. Player ID: #{inspect(socket.assigns.player_id)}, Room: #{socket.assigns.room_code}")

    if socket.assigns.player_id == nil do
      {:noreply, put_flash(socket, :error, "Player ID not set. Please rejoin the game.")}
    else
      case Game.draw_card(socket.assigns.room_code, socket.assigns.player_id) do
        {:ok, %{card: card, new_position: _new_position}} ->
          # Trigger card animation
          {:noreply, assign(socket, card_animation: true, last_card: card)}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Cannot draw card: #{inspect(reason)}")}
      end
    end
  end

  @impl true
  def handle_event("play_again", _params, socket) do
    Game.reset_game(socket.assigns.room_code)
    {:noreply, socket}
  end

  @impl true
  def handle_event("leave_game", _params, socket) do
    Game.leave_game(socket.assigns.room_code, socket.assigns.player_id)
    {:noreply, push_navigate(socket, to: ~p"/")}
  end

  @impl true
  def handle_info({:game_update, {:card_drawn, _player_id, card, _new_position}, game_state}, socket) do
    # Update game state and show card animation
    socket = assign(socket,
      game_state: game_state,
      last_card: card,
      card_animation: true
    )

    # Clear animation after delay
    Process.send_after(self(), :clear_card_animation, 2000)

    {:noreply, socket}
  end

  def handle_info({:game_update, {:game_won, _winner_id}, game_state}, socket) do
    {:noreply, assign(socket, game_state: game_state)}
  end

  def handle_info({:game_update, _message, game_state}, socket) do
    {:noreply, assign(socket, game_state: game_state)}
  end

  def handle_info(:clear_card_animation, socket) do
    {:noreply, assign(socket, card_animation: false, last_card: nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-green-100 to-blue-100 p-4">
      <%= if @game_state.status == :finished do %>
        <!-- Victory Screen -->
        <.victory_screen winner={get_winner(@game_state)} room_code={@room_code} />
      <% else %>
        <!-- Game Board -->
        <div class="max-w-7xl mx-auto">
          <div class="text-center mb-6">
            <h1 class="text-4xl font-bold text-gray-800">🐧 Tux Land</h1>
            <p class="text-gray-600">Room: <%= @room_code %></p>
          </div>

          <div class="grid grid-cols-1 lg:grid-cols-4 gap-4">
            <!-- Main Game Board -->
            <div class="lg:col-span-3">
              <div class="bg-white rounded-lg shadow-lg p-6">
                <.simple_board board={@game_state.board} players={@game_state.players} />

                <!-- Card Display -->
                <%= if @card_animation and @last_card do %>
                  <div class="mt-4 p-6 bg-white border-4 border-gray-800 rounded-lg shadow-xl">
                    <p class="text-lg font-semibold text-gray-800 mb-3">Card Drawn:</p>
                    <.card_display_component card={@last_card} />
                  </div>
                <% end %>

                <!-- Draw Button -->
                <%= if is_current_player?(@game_state, @player_id) do %>
                  <div class="mt-4 flex justify-center">
                    <button
                      phx-click="draw_card"
                      class="px-8 py-4 bg-blue-500 text-white rounded-lg text-xl font-bold hover:bg-blue-600 shadow-lg"
                    >
                      Draw Card
                    </button>
                  </div>
                <% else %>
                  <div class="mt-4 text-center text-gray-600">
                    Waiting for <%= current_player(@game_state).name %> to draw...
                  </div>
                <% end %>
              </div>
            </div>

            <!-- Sidebar -->
            <div class="space-y-4">
              <div class="bg-white rounded-lg shadow p-4">
                <h3 class="font-semibold mb-3">Players</h3>
                <%= for {player, index} <- Enum.with_index(@game_state.players) do %>
                  <div class={[
                    "flex items-center gap-2 p-2 rounded mb-2",
                    if(index == @game_state.current_player_index, do: "bg-blue-100", else: "bg-gray-50")
                  ]}>
                    <span class="text-xl"><%= tux_emoji(player.tux_variant) %></span>
                    <div class="flex-1">
                      <div class="font-medium"><%= player.name %></div>
                      <div class="text-xs text-gray-500">Position: <%= player.position %></div>
                    </div>
                    <%= if index == @game_state.current_player_index do %>
                      <span class="text-xs bg-blue-500 text-white px-2 py-1 rounded">Turn</span>
                    <% end %>
                  </div>
                <% end %>
              </div>

              <div class="bg-white rounded-lg shadow p-4">
                <h3 class="font-semibold mb-2">Deck Info</h3>
                <p class="text-sm text-gray-600">Cards: <%= length(@game_state.deck) %></p>
                <p class="text-sm text-gray-600">Discard: <%= length(@game_state.discard_pile) %></p>
              </div>

              <div class="bg-yellow-50 border border-yellow-200 rounded-lg shadow p-4">
                <h3 class="font-semibold mb-2 text-sm">Debug Info</h3>
                <p class="text-xs text-gray-700">Status: <span class="font-mono"><%= @game_state.status %></span></p>
                <p class="text-xs text-gray-700">Your ID: <span class="font-mono text-xs break-all"><%= if @player_id, do: String.slice(@player_id, 0..8) <> "...", else: "NOT SET" %></span></p>
                <p class="text-xs text-gray-700">Current Turn: <%= @game_state.current_player_index + 1 %> / <%= length(@game_state.players) %></p>
                <%= if @player_id do %>
                  <p class="text-xs text-green-700">✓ Ready to play</p>
                <% else %>
                  <p class="text-xs text-red-700">✗ Player ID missing</p>
                <% end %>
              </div>

              <button
                phx-click="leave_game"
                class="w-full px-4 py-2 bg-red-500 text-white rounded-lg hover:bg-red-600"
              >
                Leave Game
              </button>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp victory_screen(assigns) do
    ~H"""
    <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div class="bg-white rounded-lg p-8 max-w-md text-center">
        <h2 class="text-4xl font-bold mb-4">🎉 Victory! 🎉</h2>
        <p class="text-2xl mb-6">
          <%= @winner.name %> wins!
        </p>
        <div class="text-6xl mb-6">
          <%= tux_emoji(@winner.tux_variant) %>
        </div>
        <div class="space-y-3">
          <button
            phx-click="play_again"
            class="w-full px-6 py-3 bg-green-500 text-white rounded-lg font-semibold hover:bg-green-600"
          >
            Play Again
          </button>
          <button
            phx-click="leave_game"
            class="w-full px-6 py-3 bg-gray-500 text-white rounded-lg font-semibold hover:bg-gray-600"
          >
            Return to Lobby
          </button>
        </div>
      </div>
    </div>
    """
  end

  # Simple board visualization - just showing positions
  defp simple_board(assigns) do
    ~H"""
    <div class="mb-4">
      <h2 class="text-xl font-semibold mb-3">Game Board</h2>
      <div class="grid grid-cols-10 gap-1">
        <%= for space <- Enum.take(@board, 40) do %>
          <div class={[
            "aspect-square rounded flex items-center justify-center text-xs font-bold",
            space_color_class(space.color)
          ]}>
            <%= space.position %>
            <%= if players_at_position(space.position, @players) != [] do %>
              <div class="absolute">
                <%= for player <- players_at_position(space.position, @players) do %>
                  <span class="text-lg"><%= tux_emoji(player.tux_variant) %></span>
                <% end %>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
      <p class="text-sm text-gray-500 mt-2">Showing first 40 spaces (of 134 total)</p>
    </div>
    """
  end

  defp players_at_position(position, players) do
    Enum.filter(players, fn p -> p.position == position end)
  end

  defp space_color_class(:start), do: "bg-green-200 border-2 border-green-500"
  defp space_color_class(:end), do: "bg-purple-200 border-2 border-purple-500"
  defp space_color_class(:red), do: "bg-red-200"
  defp space_color_class(:purple), do: "bg-purple-200"
  defp space_color_class(:yellow), do: "bg-yellow-200"
  defp space_color_class(:blue), do: "bg-blue-200"
  defp space_color_class(:orange), do: "bg-orange-200"
  defp space_color_class(:green), do: "bg-green-200"

  # Card display component with color swatch
  defp card_display_component(assigns) do
    ~H"""
    <div class="flex items-center justify-center gap-4">
      <%= if @card.type in [:single, :double] do %>
        <!-- Color Swatch -->
        <div class={[
          "w-24 h-24 rounded-lg border-4 border-gray-800 shadow-lg flex items-center justify-center text-2xl font-bold",
          card_bg_color(@card.color)
        ]}>
          <%= if @card.type == :double, do: "×2", else: "×1" %>
        </div>
      <% end %>

      <!-- Card Text -->
      <div class="text-left">
        <div class={[
          "text-3xl font-bold mb-1",
          card_text_color(@card.color)
        ]}>
          <%= card_type_text(@card.type) %>
        </div>
        <div class={[
          "text-5xl font-black uppercase tracking-wide",
          card_text_color(@card.color)
        ]}>
          <%= if @card.type == :location, do: "📍 #{@card.location_name}", else: color_name(@card.color) %>
        </div>
      </div>
    </div>
    """
  end

  defp card_bg_color(:red), do: "bg-red-500"
  defp card_bg_color(:purple), do: "bg-purple-500"
  defp card_bg_color(:yellow), do: "bg-yellow-400"
  defp card_bg_color(:blue), do: "bg-blue-500"
  defp card_bg_color(:orange), do: "bg-orange-500"
  defp card_bg_color(:green), do: "bg-green-500"

  defp card_text_color(:red), do: "text-red-700"
  defp card_text_color(:purple), do: "text-purple-700"
  defp card_text_color(:yellow), do: "text-yellow-700"
  defp card_text_color(:blue), do: "text-blue-700"
  defp card_text_color(:orange), do: "text-orange-700"
  defp card_text_color(:green), do: "text-green-700"

  defp card_type_text(:single), do: "Single"
  defp card_type_text(:double), do: "Double"
  defp card_type_text(:location), do: "Location"

  defp color_name(color), do: color |> to_string() |> String.upcase()

  # Legacy card_display (kept for backward compatibility)
  defp card_display(%{type: :single, color: color}) do
    "Single #{color |> to_string() |> String.upcase()}"
  end

  defp card_display(%{type: :double, color: color}) do
    "Double #{color |> to_string() |> String.upcase()}"
  end

  defp card_display(%{type: :location, location_name: name}) do
    "📍 #{name}"
  end

  defp current_player(game_state) do
    Enum.at(game_state.players, game_state.current_player_index)
  end

  defp is_current_player?(_game_state, nil), do: false
  defp is_current_player?(game_state, player_id) do
    current_player(game_state).id == player_id
  end

  defp get_winner(game_state) do
    Enum.find(game_state.players, fn p -> p.id == game_state.winner end)
  end

  defp tux_emoji(:laptop), do: "💻🐧"
  defp tux_emoji(:terminal), do: "⌨️🐧"
  defp tux_emoji(:coffee), do: "☕🐧"
  defp tux_emoji(:hoodie), do: "🧥🐧"
end

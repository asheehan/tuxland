defmodule TuxlandWeb.LobbyLive do
  use TuxlandWeb, :live_view

  alias Tuxland.Game

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket,
      room_code: nil,
      player_id: nil,
      game_state: nil,
      selected_tux: :laptop,
      player_name: "",
      join_code: "",
      error: nil
    )}
  end

  @impl true
  def handle_params(%{"room_code" => room_code}, _uri, socket) do
    # Joining an existing game via URL
    if Game.room_exists?(room_code) do
      game_state = Game.get_state(room_code)

      if connected?(socket) do
        Phoenix.PubSub.subscribe(Tuxland.PubSub, "game:#{room_code}")
      end

      {:noreply, assign(socket, room_code: room_code, game_state: game_state)}
    else
      {:noreply,
        socket
        |> put_flash(:error, "Game room not found")
        |> push_navigate(to: ~p"/")}
    end
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("create_game", _params, socket) do
    room_code = generate_room_code()

    case Game.create_room(room_code) do
      {:ok, _pid} ->
        if connected?(socket) do
          Phoenix.PubSub.subscribe(Tuxland.PubSub, "game:#{room_code}")
        end

        {:noreply,
          socket
          |> assign(room_code: room_code)
          |> push_patch(to: ~p"/game/#{room_code}")}

      {:error, reason} ->
        {:noreply, assign(socket, error: "Failed to create game: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("join_game", %{"room_code" => room_code}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/game/#{room_code}")}
  end

  @impl true
  def handle_event("select_tux", %{"variant" => variant}, socket) do
    {:noreply, assign(socket, selected_tux: String.to_atom(variant))}
  end

  @impl true
  def handle_event("join_as_player", %{"name" => name}, socket) do
    case Game.join_game(socket.assigns.room_code, name, socket.assigns.selected_tux) do
      {:ok, player_id} ->
        # Stay in lobby - don't redirect yet
        # Game will redirect everyone when host clicks "Start Game"
        game_state = Game.get_state(socket.assigns.room_code)
        {:noreply, assign(socket, player_id: player_id, game_state: game_state)}

      {:error, reason} ->
        {:noreply, assign(socket, error: "Failed to join: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("start_game", _params, socket) do
    case Game.start_game(socket.assigns.room_code, socket.assigns.player_id) do
      :ok ->
        {:noreply, push_navigate(socket, to: ~p"/game/#{socket.assigns.room_code}/play?player_id=#{socket.assigns.player_id}")}

      {:error, reason} ->
        {:noreply, assign(socket, error: "Failed to start: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_info({:game_update, {:player_joined, _player}, game_state}, socket) do
    {:noreply, assign(socket, game_state: game_state)}
  end

  def handle_info({:game_update, :game_started, game_state}, socket) do
    {:noreply,
      socket
      |> assign(game_state: game_state)
      |> push_navigate(to: ~p"/game/#{socket.assigns.room_code}/play?player_id=#{socket.assigns.player_id}")}
  end

  def handle_info({:game_update, _message, game_state}, socket) do
    {:noreply, assign(socket, game_state: game_state)}
  end

  defp generate_room_code do
    :crypto.strong_rand_bytes(4)
    |> Base.encode16()
    |> String.slice(0, 6)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-blue-500 to-purple-600 flex items-center justify-center p-4">
      <div class="bg-white rounded-lg shadow-2xl p-8 max-w-2xl w-full">
        <h1 class="text-4xl font-bold text-center mb-8 text-gray-800">
          🐧 Tux Land
        </h1>

        <%= if @room_code do %>
          <!-- Lobby View -->
          <div class="space-y-6">
            <div class="bg-blue-50 p-4 rounded-lg">
              <p class="text-sm text-gray-600 mb-2">Room Code:</p>
              <div class="flex items-center gap-2">
                <code class="text-3xl font-mono font-bold text-blue-600"><%= @room_code %></code>
                <button
                  phx-click={JS.dispatch("tuxland:copy", detail: %{text: @room_code})}
                  class="px-3 py-1 bg-blue-500 text-white rounded hover:bg-blue-600"
                >
                  Copy
                </button>
              </div>
            </div>

            <%= if @player_id do %>
              <!-- Already joined -->
              <div class="space-y-4">
                <h2 class="text-2xl font-semibold">Players in Lobby</h2>
                <div class="space-y-2">
                  <%= for player <- @game_state.players do %>
                    <div class="flex items-center gap-3 p-3 bg-gray-50 rounded" data-role="player">
                      <span class="text-2xl"><%= tux_emoji(player.tux_variant) %></span>
                      <span class="font-medium"><%= player.name %></span>
                      <%= if player.id == @game_state.host_id do %>
                        <span class="ml-auto text-xs font-bold bg-blue-600 text-white px-3 py-1 rounded-full shadow">👑 Host</span>
                      <% end %>
                    </div>
                  <% end %>
                </div>

                <%= if @player_id == @game_state.host_id and length(@game_state.players) >= 1 do %>
                  <button
                    phx-click="start_game"
                    class="w-full py-3 bg-green-500 text-white rounded-lg font-semibold hover:bg-green-600"
                  >
                    Start Game <%= if length(@game_state.players) == 1, do: "(Solo Test Mode)" %>
                  </button>
                <% end %>
              </div>
            <% else %>
              <!-- Join as player -->
              <.form for={%{}} phx-submit="join_as_player" class="space-y-4">
                <div>
                  <label class="block text-sm font-medium mb-2">Your Name</label>
                  <input
                    type="text"
                    name="name"
                    required
                    class="w-full px-4 py-2 border rounded-lg text-gray-900"
                    placeholder="Enter your name"
                  />
                </div>

                <div>
                  <label class="block text-sm font-medium mb-2">Choose Your Tux</label>
                  <div class="grid grid-cols-4 gap-3">
                    <%= for variant <- [:laptop, :terminal, :coffee, :hoodie] do %>
                      <button
                        type="button"
                        phx-click="select_tux"
                        phx-value-variant={variant}
                        class={[
                          "p-4 border-2 rounded-lg text-4xl hover:bg-gray-50",
                          if(@selected_tux == variant,
                            do: "border-blue-500 bg-blue-50",
                            else: "border-gray-200"
                          )
                        ]}
                      >
                        <%= tux_emoji(variant) %>
                      </button>
                    <% end %>
                  </div>
                </div>

                <button
                  type="submit"
                  class="w-full py-3 bg-blue-500 text-white rounded-lg font-semibold hover:bg-blue-600"
                >
                  Join Game
                </button>
              </.form>
            <% end %>
          </div>
        <% else %>
          <!-- Home View -->
          <div class="space-y-4">
            <button
              phx-click="create_game"
              class="w-full py-4 bg-blue-500 text-white rounded-lg text-xl font-semibold hover:bg-blue-600"
            >
              Create New Game
            </button>

            <div class="flex items-center gap-3">
              <div class="flex-1 h-px bg-gray-300"></div>
              <span class="text-gray-500">or</span>
              <div class="flex-1 h-px bg-gray-300"></div>
            </div>

            <.form for={%{}} phx-submit="join_game" class="space-y-3">
              <input
                type="text"
                name="room_code"
                required
                class="w-full px-4 py-3 border-2 rounded-lg text-center text-xl font-mono uppercase text-gray-900"
                placeholder="ENTER ROOM CODE"
                maxlength="6"
              />
              <button
                type="submit"
                class="w-full py-3 bg-green-500 text-white rounded-lg font-semibold hover:bg-green-600"
              >
                Join Game
              </button>
            </.form>
          </div>
        <% end %>

        <%= if @error do %>
          <div class="mt-4 p-3 bg-red-50 text-red-700 rounded-lg">
            <%= @error %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp tux_emoji(:laptop), do: "💻🐧"
  defp tux_emoji(:terminal), do: "⌨️🐧"
  defp tux_emoji(:coffee), do: "☕🐧"
  defp tux_emoji(:hoodie), do: "🧥🐧"
end

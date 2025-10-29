defmodule TuxlandWeb.GameLiveTest do
  use TuxlandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  setup do
    room_code = "TEST#{:rand.uniform(999999)}"
    {:ok, _pid} = Tuxland.Game.create_room(room_code)

    # Add two players and start game
    {:ok, player1_id} = Tuxland.Game.join_game(room_code, "Alice", :laptop)
    {:ok, player2_id} = Tuxland.Game.join_game(room_code, "Bob", :terminal)
    :ok = Tuxland.Game.start_game(room_code, player1_id)

    {:ok, room_code: room_code, player1_id: player1_id, player2_id: player2_id}
  end

  describe "game page" do
    test "displays game board", %{conn: conn, room_code: room_code, player1_id: player1_id} do
      {:ok, _view, html} = live(conn, "/game/#{room_code}/play?player_id=#{player1_id}")

      # Should have board elements
      assert html =~ "Tux Land"
    end

    test "shows current player's turn", %{conn: conn, room_code: room_code, player1_id: player1_id} do
      {:ok, view, _html} = live(conn, "/game/#{room_code}/play?player_id=#{player1_id}")

      # First player should see draw button
      assert has_element?(view, "button", "Draw Card")
    end

    test "allows current player to draw card", %{conn: conn, room_code: room_code, player1_id: player1_id} do
      {:ok, view, _html} = live(conn, "/game/#{room_code}/play?player_id=#{player1_id}")

      # Click draw card
      view |> element("button", "Draw Card") |> render_click()

      # Game state should update (player moved)
      state = Tuxland.Game.get_state(room_code)
      player = Enum.find(state.players, fn p -> p.id == player1_id end)
      assert player.position > 0
    end

    test "shows waiting message for non-current player", %{conn: conn, room_code: room_code, player2_id: player2_id} do
      {:ok, _view, html} = live(conn, "/game/#{room_code}/play?player_id=#{player2_id}")

      # Second player should see waiting message
      assert html =~ "Waiting for"
    end

    test "displays all players", %{conn: conn, room_code: room_code, player1_id: player1_id} do
      {:ok, _view, html} = live(conn, "/game/#{room_code}/play?player_id=#{player1_id}")

      assert html =~ "Alice"
      assert html =~ "Bob"
    end

    test "redirects to lobby if game not found", %{conn: conn} do
      result = live(conn, "/game/INVALID/play?player_id=fake-id")

      # Should redirect
      assert {:error, {:live_redirect, %{to: "/"}}} = result
    end
  end

  describe "game updates" do
    test "receives real-time updates when other player draws", %{
      conn: conn,
      room_code: room_code,
      player1_id: player1_id,
      player2_id: player2_id
    } do
      # Player 2 watches
      {:ok, view2, _html} = live(conn, "/game/#{room_code}/play?player_id=#{player2_id}")

      # Player 1 draws
      {:ok, _} = Tuxland.Game.draw_card(room_code, player1_id)

      # Player 2's view should update
      render(view2)
      state = Tuxland.Game.get_state(room_code)

      # Verify the turn advanced
      assert state.current_player_index == 1
    end
  end
end

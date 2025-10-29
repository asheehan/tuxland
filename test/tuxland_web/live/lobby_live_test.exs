defmodule TuxlandWeb.LobbyLiveTest do
  use TuxlandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  describe "home page (:index)" do
    test "renders home page with create and join options", %{conn: conn} do
      {:ok, view, html} = live(conn, "/")

      assert html =~ "Tux Land"
      assert html =~ "Create New Game"
      assert has_element?(view, "button", "Create New Game")
    end

    test "creates new game room when button clicked", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Click create game
      html = view |> element("button", "Create New Game") |> render_click()

      # Should show room code in the page
      assert html =~ "Room Code"
    end
  end

  describe "lobby page (:lobby)" do
    setup do
      room_code = "TEST#{:rand.uniform(999999)}"
      {:ok, _pid} = Tuxland.Game.create_room(room_code)

      {:ok, room_code: room_code}
    end

    test "displays room code", %{conn: conn, room_code: room_code} do
      {:ok, _view, html} = live(conn, "/game/#{room_code}")

      assert html =~ room_code
      assert html =~ "Room Code"
    end

    test "allows player to join game", %{conn: conn, room_code: room_code} do
      {:ok, view, _html} = live(conn, "/game/#{room_code}")

      # Fill in name and select Tux - should stay in lobby
      html = view
      |> form("form", %{name: "Alice"})
      |> render_submit()

      # Should now show player in lobby (not redirect yet)
      assert html =~ "Alice"
      assert html =~ "Start Game"
    end

    test "redirects to home if room doesn't exist", %{conn: conn} do
      # Try to visit non-existent room
      result = live(conn, "/game/INVALID")

      # Should get a redirect error
      assert {:error, {:live_redirect, %{to: "/", flash: %{"error" => "Game room not found"}}}} = result
    end
  end
end

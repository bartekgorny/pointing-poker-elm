defmodule PokerWeb.SessionController do
  use PokerWeb, :controller

  @chars "abcdefghijklmnopqrstuvwxyz0123456789"

  def index(conn, %{"id" => id}) do
    render(conn, "session.html", id: id)
  end

  def new_session(conn, _params) do
    sessionid = generate_random_id()
    conn
        |> redirect(to: Routes.session_path(conn, :index, sessionid))
        |> halt()
  end

  defp generate_random_id() do
    choices = @chars |> String.split("", trim: true)
    (for n <- 1..8, do: Enum.random(choices)) |> Enum.join("")
  end

end

defmodule SessionChannel do

  use PokerWeb, :channel

  def join("session:" <> sessionid, _payload, socket) do
    IO.inspect sessionid
    socket = assign(socket, :nick, nil)
    socket = assign(socket, :sid, sessionid)
    {:ok, socket}
  end

  def handle_in("set_nick", %{"nick" => nick}, socket) do
    socket = assign(socket, :nick, nick)
    sid = socket.assigns.sid
    pid = case PokerSession.get(sid) do
      {:error, :session_not_started} ->
        {:ok, pid} = PokerSession.start(%{user: nick, sid: sid})
        pid
      pid ->
        PokerSession.join(pid, nick)
        pid
    end
    pok = PokerSession.get(pid, :poker)
    IO.inspect pok
    push(socket, "joined", %{})
    push(socket, "session_state", session_state(pok))
    {:noreply, socket}
  end

  def handle_in("voting_action", %{"action" => action} = payload, socket) do
    handle_voting_action(action, payload, socket)
    {:noreply, socket}
  end

  defp handle_voting_action("vote", %{"value" => v}, socket) do
    nick = socket.assigns.nick
    pid = PokerSession.get(socket.assigns.sid)
    :ok = PokerSession.vote(pid, socket.assigns.nick, v)
    broadcast(socket, "new_vote", %{nick: nick, vote: v})
  end
  defp handle_voting_action("showvotes", _payload, socket) do
    pid = PokerSession.get(socket.assigns.sid)
    :ok = PokerSession.showvotes(pid)
    broadcast(socket, "showvotes", %{})
  end
  defp handle_voting_action("reset", _payload, socket) do
    pid = PokerSession.get(socket.assigns.sid)
    :ok = PokerSession.reset(pid)
    pok = PokerSession.get(pid, :poker)
    broadcast(socket, "session_state", session_state(pok))
  end
  defp handle_voting_action("setdesc", %{"desc" => desc}, socket) do
    pid = PokerSession.get(socket.assigns.sid)
    :ok = PokerSession.setdesc(pid, desc)
    pok = PokerSession.get(pid, :poker)
    broadcast(socket, "session_state", session_state(pok))
  end

  defp session_state(pok) do
    %{votes: pok.votes, showvotes: pok.showvotes, owner: pok.owner, description: pok.desc}
  end


end

defmodule PokerTest do
  use ExUnit.Case

  alias Poker

  @moduletag :capture_log

  doctest Poker

  test "session" do
    sess_id = "safasfasdfa"
    user_id = "me"
    assert {:error, :session_not_started} = PokerSession.get(sess_id)
    pid = PokerSession.start(%{user: user_id, sid: sess_id})
    assert {:error, {:already_started, pid}} = PokerSession.start(%{user: user_id, sid: sess_id})
    pok = PokerSession.get(pid, :poker)
    assert "me" = pok.owner
    assert 0 = pok.votes["me"]
    PokerSession.join(pid, "you")
    pok = PokerSession.get(pid, :poker)
    assert 0 = pok.votes["you"]
    PokerSession.vote(pid, "me", 3)
    PokerSession.vote(pid, "you", 5)
    pok = PokerSession.get(pid, :poker)
    assert 3 = pok.votes["me"]
    assert 5 = pok.votes["you"]
    assert !pok.showvotes
    PokerSession.showvotes(pid)
    pok = PokerSession.get(pid, :poker)
    assert pok.showvotes
    PokerSession.reset(pid)
    pok = PokerSession.get(pid, :poker)
    assert !pok.showvotes
    assert 0 = pok.votes["me"]
    assert 0 = pok.votes["you"]
  end
end

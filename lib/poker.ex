defmodule Poker do
  defstruct sid: nil, owner: nil, votes: %{}, showvotes: false, desc: nil
  @type t :: %Poker{sid: String.t, owner: String.t, votes: map, showvotes: bool, desc: String.t}
end

defmodule Meta do
  defstruct a: nil
  @type t :: %Meta{a: String.t}
end

defmodule State do
  defstruct poker: %Poker{}, meta: %Meta{}
  @type t :: %State{poker: Poker.t, meta: Meta.t}
end

defmodule PokerSession do
  @moduledoc """
  Poker keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  use GenServer

  def start(data) do
    GenServer.start(__MODULE__,
                    data,
                    [{:name, String.to_atom data.sid}])
  end

  def init(%{:user => user, :sid => sid}) do
    {:ok, %State{poker: %Poker{sid: sid,
                               owner: user,
                               votes: Map.put(%{}, user, 0)},
                 meta: %Meta{}}}
  end

  @spec get(binary()) :: pid() | {atom(), atom()}
  def get(sid) do
    # TODO: use registry
    case GenServer.whereis(String.to_atom sid) do
      nil -> {:error, :session_not_started}
      pid -> pid
    end
  end

  @spec get(pid(), atom()) :: term()
  def get(pid, what) do
    GenServer.call(pid, {:get, what})
  end

  @spec join(pid(), String.t) :: :ok | {:error, term()}
  def join(pid, nick) do
    GenServer.call(pid, {:join, nick})
  end

  @spec vote(pid(), String.t, integer()) :: :ok | {:error, term()}
  def vote(pid, nick, vote) do
    GenServer.call(pid, {:vote, nick, vote})
  end

  @spec showvotes(pid()) :: :ok | {:error, term()}
  def showvotes(pid) do
    GenServer.call(pid, :showvotes)
  end

  @spec reset(pid()) :: {:ok, Poker.t} | {:error, term()}
  def reset(pid) do
    GenServer.call(pid, :reset)
  end

  @spec setdesc(pid(), String.t) :: {:ok, Poker.t} | {:error, term()}
  def setdesc(pid, desc) do
    GenServer.call(pid, {:setdesc, desc})
  end

  def handle_call({:get, :poker}, _from, state) do
    {:reply, state.poker, state}
  end
  def handle_call({:get, :meta}, _from, state) do
    {:reply, state.meta, state}
  end
  def handle_call({:join, nick}, _from, state) do
    p = state.poker
    case Map.get(p.votes, nick) do
      nil ->
        nvotes = Map.put(p.votes, nick, 0)
        npok = %{p | :votes => nvotes}
        {:reply, :ok, %{state | :poker => npok}}
      _ ->
        {:reply, :ok, state}
    end
  end
  def handle_call({:vote, nick, vote}, _from, state) do
    p = state.poker
    nvotes = %{p.votes | nick => vote}
    npok = %{p | :votes => nvotes}
    {:reply, :ok, %{state | :poker => npok}}
  end
  def handle_call(:showvotes, _from, state) do
    npok = %{state.poker | :showvotes => true}
    {:reply, :ok, %{state | :poker => npok}}
  end
  def handle_call(:reset, _from, state) do
    nvotes = List.foldr (Map.keys state.poker.votes), %{}, fn(i, acc) -> Map.put acc, i, 0 end
    npok = %{state.poker | :votes => nvotes, :showvotes => false, :desc => nil}
    {:reply, {:ok, npok}, %{state | :poker => npok}}
  end
  def handle_call({:setdesc, desc}, _from, state) do
    npok = %{state.poker | :desc => desc}
    {:reply, {:ok, npok}, %{state | :poker => npok}}

  end
  def handle_call(_msg, _from, state) do
    {:reply, :ok, state}
  end

  def handle_cast(_msg, state) do
    {:noreply, state}
  end
end

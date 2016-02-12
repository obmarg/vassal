defmodule Vassal.Queue.Receiver do
  @moduledoc """
  A process that handles ReceiveMessage actions for a queue.

  Currently this is managed by polling the QueueMessages process. This might not
  be the most efficient way of doing things, but it's easiest to implement. Can
  look into other options later.
  """
  use GenServer

  require Logger

  alias Vassal.Queue.QueueMessages

  @poll_interval 200

  defmodule ReceiveRequest do
    @moduledoc """
    Struct that represents a single receive request.
    """
    defstruct action: nil, from: nil, id: nil
  end

  @doc """
  Tell a receiver about a ReceiveMessage request.

  ### Params

  - `receiver` - The receiver to tell about this request.
  - `action` - The ReceiveMessage action representing the request.

  Returns a list of message PIDs that can be queried for their data.
  """
  @spec receive_messages(pid, Vassal.Actions.ReceiveMessage.t) :: [pid]
  def receive_messages(receiver, action) do
    req_id = UUID.uuid4
    GenServer.cast(receiver, %ReceiveRequest{action: action,
                                             from: self,
                                             id: req_id})

    wait_time_ms = action.wait_time_ms
    if wait_time_ms == 0 do
      wait_time_ms = 500
    end
    receive do
      {:response, ^req_id, message_pids} ->
        :ok = GenServer.call(receiver, {:ack, req_id})
        message_pids
    after
      wait_time_ms ->
        GenServer.cast(receiver, {:cancel_request, req_id})
        []
    end
  end

  @doc """
  Returns the PID of a Receiver process when given the queue name.
  """
  @spec for_queue(String.t, non_neg_integer) :: pid
  def for_queue(queue_name, timeout \\ 50) do
    {pid, _} = queue_name |> to_gproc_name |> :gproc.await(timeout)
    pid
  end

  def start_link(queue_name) do
    GenServer.start_link(__MODULE__, queue_name)
  end

  def init(queue_name) do
    queue_name |> to_gproc_name |> :gproc.reg

    :erlang.send_after(@poll_interval, self, :poll)
    {:ok, %{queue_messages_pid: QueueMessages.for_queue(queue_name),
            waiting_requests: [],
            completed_requests: HashDict.new}}
  end

  def handle_call({:ack, uuid}, _from, state) do
    {_, timer_ref} = state.completed_requests[uuid]
    :erlang.cancel_timer(timer_ref)
    {:reply, :ok, Dict.update!(state,
                               :completed_requests,
                               &(Dict.delete &1, uuid))}
  end

  def handle_cast(%ReceiveRequest{} = request,
                  %{waiting_requests: []} = state) do
    messages = QueueMessages.dequeue(state.queue_messages_pid,
                                     request.action.max_messages)
    if messages == [] do
      {:noreply, %{state | waiting_requests: [request]}}
    else
      new_state = reply_to_request(request, state, messages)
      {:noreply, new_state}
    end
  end

  def handle_cast(%ReceiveRequest{} = request, state) do
    {:noreply, Dict.update!(state,
                            :waiting_requests,
                            &(List.insert_at &1, -1, request))}
  end

  def handle_cast({:cancel_request, req_id}, state) do
    new_requests = Enum.reject state.waiting_requests, fn (req) ->
      req.id == req_id
    end
    {:noreply, %{state | waiting_requests: new_requests}}
  end

  def handle_info(:poll, state) do
    result = attempt_receives(state)
    :erlang.send_after(@poll_interval, self, :poll)
    {:noreply, result}
  end

  def handle_info({:ack_timeout, uuid}, state) do
    Logger.warn "Receiver ack timeout!"
    {messages, _} = state.completed_requests[uuid]
    QueueMessages.requeue(state.queue_messages_pid, messages)

    {:noreply, Dict.update!(state,
                            :completed_requests,
                            &(Dict.delete &1, uuid))}
  end

  defp attempt_receives(%{waiting_requests: []} = state), do: state
  defp attempt_receives(%{waiting_requests: [request|rest]} = state) do
    messages = QueueMessages.dequeue(state.queue_messages_pid,
                                     request.action.max_messages)
    if messages == [] do
      state
    else
      new_state = reply_to_request(request, state, messages)
      attempt_receives(%{new_state | waiting_requests: rest})
    end
  end

  @recv_ack_timeout_ms 5000

  defp reply_to_request(request, state, messages) do
    send(request.from, {:response, request.id, messages})
    timer_ref = :erlang.send_after(@recv_ack_timeout_ms, self,
                                   {:ack_timeout, request.id})
    Dict.update!(state,
                 :completed_requests,
                 &(Dict.put &1, request.id, {messages, timer_ref}))
  end

  defp to_gproc_name(queue_name) do
    {:n, :l, "queue.#{queue_name}.receiver"}
  end
end

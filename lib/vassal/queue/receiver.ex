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
    defstruct action: nil, from: nil
  end

  @doc """
  Tell a receiver about a ReceiveMessage request.

  ### Params

  - `receiver` - The receiver to tell about this request.
  - `action` - The ReceiveMessage action representing the request.
  - `form` - The GenServer `from` parameter that should be used to reply.
  """
  def receive_messages(receiver, action) do
    GenServer.cast(receiver, %ReceiveRequest{action: action, from: self})
    wait_time_ms = action.wait_time_ms
    if wait_time_ms == 0 do
      wait_time_ms = 500
    end
    receive do
      {:response, uuid, messages} ->
        :ok = GenServer.call(receiver, {:ack, uuid})
        messages
    after
      wait_time_ms -> []
    end
  end

  def start_link(queue_messages_pid) do
    GenServer.start_link(__MODULE__, queue_messages_pid)
  end

  def init(queue_messages_pid) do
    :timer.send_interval(@poll_interval, :poll)
    {:ok, %{queue_messages_pid: queue_messages_pid,
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
                            :receive_requests,
                            &(List.insert_at &1, -1, request))}
  end

  def handle_info(:poll, state) do
    {:noreply, attempt_receives(state)}
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
    resp_uuid = UUID.uuid1
    send(request.from, {:response, resp_uuid, messages})
    timer_ref = :erlang.send_after(@recv_ack_timeout_ms, self,
                                   {:ack_timeout, resp_uuid})
    Dict.update!(state,
                 :completed_requests,
                 &(Dict.put &1, resp_uuid, {messages, timer_ref}))
  end

end

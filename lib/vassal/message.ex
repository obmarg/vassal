defmodule Vassal.Message do
  @moduledoc """
  This module provides a process for a single message on a queue.

  It is implemented in two parts - a GenServer and a state machine. The
  GenServer feeds the state machine events which cause it to transition into
  states. When a state transition requires an action, the state machine will
  send a message to the GenServer that causes it to take that action.
  """
  use GenServer

  alias Vassal.Queue.QueueMessages

  defmodule MessageInfo do
    @moduledoc """
    A struct that contains all the information about a message.
    """

    defstruct [delay_ms: 0,
               default_visibility_timeout_ms: 30 * 1000,
               message_id: nil,
               body_md5: nil,
               body: nil,
               attributes: %{sent_timestamp: 0,
                             approx_first_receive: nil,
                             approx_receive_count: 0}]

  end

  defmodule StateMachine do
    @moduledoc """
    This module defines the state machine for our Message process.

    In response to an event we will transition to a new state, and send details
    of any actions that need to be taken to the current processes mailbox.
    """

    use Fsm, initial_state: :new

    # TODO: Document all the states/events.

    # TODO: Need to add current_retries, max_retries & expiry time to the state
    # machine, and transition accordingly when they max out.

    defstate new do
      defevent start() do
        send(self, :start_initial_timer)
        next_state(:initial_wait)
      end
    end

    defstate initial_wait do
      defevent timer_expired do
        send(self, :add_to_queue)
        next_state(:queued)
      end
    end

    defstate queued do
      defevent send_data(visibility_timeout_ms) do
        send(self, {:start_visibility_timer, visibility_timeout_ms})
        next_state(:processing)
      end
      defevent delete do
        next_state(:awaiting_delete)
      end
    end

    defstate processing do
      defevent delete do
        send(self, :finish)
        next_state(:finish)
      end
      defevent timer_expired do
        send(self, :add_to_queue)
        next_state(:queued)
      end
    end

    defstate awaiting_delete do
      defevent send_data(_) do
        send(self, :finish)
      end
    end
  end

  @doc """
  Starts a message process
  """
  def start_link(queue_name, message_info) do
    GenServer.start_link(__MODULE__, [queue_name, message_info])
  end

  @doc """
  Returns a messages data and starts it's visibility timer
  """
  def receive_message(message_pid, visibility_timeout_ms) do
    GenServer.call(message_pid, {:receive_message, visibility_timeout_ms})
  end

  @doc """
  Deletes a message.

  This will cause the message worker to shut down at some point. If the message
  is currently in the queue, we will wait until it is "received" before shutting
  down.
  """
  def delete_message(message_pid) do
    GenServer.call(message_pid, :delete_message)
  end

  @doc """
  Changes the visibility timeout of a message.
  """
  def change_visibility_timeout(message_pid, timeout_ms) do
    GenServer.call(message_pid, {:change_visibility_timeout, timeout_ms})
  end

  def init([queue_name, message_info]) do
    sm = StateMachine.new |> StateMachine.start

    message_info = update_in(
      message_info.attributes.sent_timestamp,
      fn (_) -> now end
    )

    {:ok, %{state_machine: sm,
            message: message_info,
            queue_messages_pid: QueueMessages.for_queue(queue_name)}}
  end

  def handle_call({:receive_message, vis_timeout_ms}, _from, state) do
    state = update_in state.message.attributes, fn(attrs) ->
      first_recv = attrs.approx_first_receive
      if first_recv == nil do
        first_recv = now
      end
      %{attrs | approx_first_receive: first_recv,
                approx_receive_count: attrs.approx_receive_count + 1}
    end

    reply = state.message
    if state.state_machine.state == :awaiting_delete do
      reply = nil
    end

    {:reply, reply, Dict.update!(state,
                                 :state_machine,
                                 &(StateMachine.send_data &1, vis_timeout_ms))}
  end

  def handle_call(:delete_message, _from, state) do
    {:reply, :ok, Dict.update!(state, :state_machine, &StateMachine.delete/1)}
  end

  def handle_call({:change_visibility_timeout, timeout_ms}, _from, state) do
    if state.state_machine.state == :processing do
      old_ms = :erlang.read_timer(state.timer_ref)
      if old_ms do
        :erlang.cancel_timer(state.timer_ref)
        timer_ref = :erlang.start_timer(old_ms + timeout_ms,
                                        self, :timer_expired)
        state = %{state | timer_ref: timer_ref}
      end
    end
    {:reply, :ok, state}
  end

  def handle_info(:start_initial_timer, state) do
    timer_ref = :erlang.start_timer(state.message.delay_ms,
                                    self, :timer_expired)
    {:noreply, Dict.put(state, :timer_ref, timer_ref)}
  end

  def handle_info({:timeout, _, :timer_expired}, state) do
    new_state =
      state
        |> Dict.delete(:timer_ref)
        |> Dict.update!(:state_machine, &StateMachine.timer_expired/1)

    {:noreply, new_state}
  end

  def handle_info(:add_to_queue, state) do
    QueueMessages.enqueue(state.queue_messages_pid, self)
    {:noreply, state}
  end

  def handle_info({:start_visibility_timer, timer_len}, state) do
    if timer_len == :nil do
      timer_len = state.message.default_visibility_timeout_ms
    end

    timer_ref = :erlang.start_timer(timer_len, self, :timer_expired)
    {:noreply, Dict.put(state, :timer_ref, timer_ref)}
  end

  def handle_info(:finish, state) do
    if Map.has_key?(state, :timer_ref) do
      :erlang.cancel_timer(state.timer_ref)
    end

    {:stop, :shutdown, state}
  end

  def handle_info(msg, state) do
    Logger.warning("Message received unknown message: #{inspect msg}")
    {:noreply, state}
  end

  defp now do
    :os.system_time(:seconds)
  end
end

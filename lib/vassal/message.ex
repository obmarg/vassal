defmodule Vassal.Message do
  @moduledoc """
  This module provides a process for a single message on a queue.

  It is implemented in two parts - a GenServer and a state machine. The
  GenServer feeds the state machine events which cause it to transition into
  states. When a state transition requires an action, the state machine will
  send a message to the GenServer that causes it to take that action.
  """
  use GenServer
  require Logger

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
               max_receives: nil,
               dead_letter_queue: nil,
               attributes: %{sent_timestamp: 0,
                             approx_first_receive: nil,
                             approx_receive_count: 0}]

    @type t :: %__MODULE__{
      delay_ms: non_neg_integer,
      default_visibility_timeout_ms: non_neg_integer,
      message_id: String.t,
      body_md5: nil,
      body: <<>>,
      max_receives: non_neg_integer | nil,
      dead_letter_queue: String.t | nil,
      attributes: %{
        sent_timestamp: non_neg_integer,
        approx_first_receive: non_neg_integer | nil,
        approx_receive_count: non_neg_integer
      }
    }
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
      defevent start(max_receives) do
        send(self, :start_initial_timer)
        next_state(:initial_wait, max_receives)
      end
    end

    defstate initial_wait do
      defevent timer_expired do
        send(self, :add_to_queue)
        next_state(:queued)
      end
    end

    defstate queued do
      defevent send_data(visibility_timeout_ms), data: remaining_recvs do
        send(self, {:start_visibility_timer, visibility_timeout_ms})
        next_state(:processing, remaining_recvs - 1)
      end
      defevent delete do
        next_state(:awaiting_delete)
      end
    end

    defstate processing do
      defevent delete do
        send(self, :finish)
        next_state(:done)
      end
      defevent timer_expired, data: remaining_recvs do
        if remaining_recvs > 0 do
          send(self, :add_to_queue)
          next_state(:queued)
        else
          send(self, :max_receives)
          next_state(:done)
        end
      end
    end

    defstate awaiting_delete do
      defevent send_data(_) do
        send(self, :finish)
        next_state(:done)
      end
    end

    defstate done do
    end
  end

  @doc """
  Starts a message process
  """
  @spec start_link(String.t, MessageInfo.t) :: GenServer.on_start
  def start_link(queue_name, message_info) do
    GenServer.start_link(__MODULE__, {queue_name, message_info})
  end

  @doc """
  Returns a messages data and starts it's visibility timer
  """
  @spec receive_message(pid, non_neg_integer) :: term
  def receive_message(message_pid, visibility_timeout_ms) do
    GenServer.call(message_pid, {:receive_message, visibility_timeout_ms})
  end

  @doc """
  Deletes a message.

  This will cause the message worker to shut down at some point. If the message
  is currently in the queue, we will wait until it is "received" before shutting
  down.
  """
  @spec delete_message(pid) :: term
  def delete_message(message_pid) do
    GenServer.call(message_pid, :delete_message)
  end

  @doc """
  Changes the visibility timeout of a message.
  """
  @spec change_visibility_timeout(pid, non_neg_integer) :: term
  def change_visibility_timeout(message_pid, timeout_ms) do
    GenServer.call(message_pid, {:change_visibility_timeout, timeout_ms})
  end

  @spec init({String.t, MessageInfo.t}) :: term
  def init({queue_name, message_info}) do
    max_receives = message_info.max_receives || 1000
    sm = StateMachine.new |> StateMachine.start(max_receives)

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
      first_recv = attrs.approx_first_receive || now
      %{attrs | approx_first_receive: first_recv,
                approx_receive_count: attrs.approx_receive_count + 1}
    end

    reply =
      if state.state_machine.state != :awaiting_delete do
        state.message
      end

    {:reply, reply, Dict.update!(state,
                                 :state_machine,
                                 &(StateMachine.send_data &1, vis_timeout_ms))}
  end

  def handle_call(:delete_message, _from, state) do
    {:reply, :ok, Dict.update!(state, :state_machine, &StateMachine.delete/1)}
  end

  def handle_call({:change_visibility_timeout, timeout_ms}, _from, state) do
    state =
      if state.state_machine.state == :processing do
        :erlang.cancel_timer(state.timer_ref)
        timer_ref = :erlang.start_timer(timeout_ms, self, :timer_expired)
        state = %{state | timer_ref: timer_ref}
      else
        state
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
    timer_len = timer_len || state.message.default_visibility_timeout_ms

    timer_ref = :erlang.start_timer(timer_len, self, :timer_expired)
    {:noreply, Dict.put(state, :timer_ref, timer_ref)}
  end

  def handle_info(:max_receives, state) do
    import Vassal.Queue, only: [send_message: 2]

    if state.message.dead_letter_queue do
      default_attributes = %MessageInfo{}.attributes
      send_message(state.message.dead_letter_queue,
                   %MessageInfo{state.message | delay_ms: nil,
                                                attributes: default_attributes})
    end

    {:stop, :shutdown, state}
  end

  def handle_info(:finish, state) do
    if Map.has_key?(state, :timer_ref) do
      :erlang.cancel_timer(state.timer_ref)
    end

    {:stop, :shutdown, state}
  end

  def handle_info(msg, state) do
    Logger.warn("Message received unknown message: #{inspect msg}")
    {:noreply, state}
  end

  @spec now() :: non_neg_integer
  defp now do
    :os.system_time(:seconds)
  end
end

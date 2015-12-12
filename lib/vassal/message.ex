defmodule Vassal.Message do
  @moduledoc """
  This module provides a process for a single message on a queue.

  It is implemented in two parts - a GenServer and a state machine. The
  GenServer feeds the state machine events which cause it to transition into
  states. When a state transition requires an action, the state machine will
  send a message to the GenServer that causes it to take that action.
  """
  use GenServer

  defmodule MessageInfo do
    @moduledoc """
    A struct that contains all the information about a message.
    """

    defstruct [delay_ms: 0,
               visibility_timeout_ms: 30 * 1000,
               message_id: nil,
               body_md5: nil,
               body: nil]
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
      defevent send_data do
        send(self, :start_visibility_timer)
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
      defevent send_data do
        send(self, :finish)
      end
    end
  end

  @doc """
  Starts a message process
  """
  def start_link(queue_messages_pid, message_info) do
    GenServer.start_link(__MODULE__, [queue_messages_pid, message_info])
  end

  @doc """
  Returns a messages data and starts it's visibility timer
  """
  def receive_message(message_pid) do
    GenServer.call(message_pid, :receive_message)
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

  def init([queue_messages_pid, message_info]) do
    sm = StateMachine.new |> StateMachine.start
    {:ok, %{state_machine: sm,
            message: message_info,
            queue_messages_pid: queue_messages_pid}}
  end

  # TODO: We need a handle_call for getting the message data...
  # TODO: We also need a handle_call for deleting the message.

  def handle_call(:receive_message, _from, state) do
    {:reply, state.message, Dict.update!(state,
                                         :state_machine,
                                         &StateMachine.send_data/1)}
  end

  def handle_call(:delete_message, _from, state) do
    {:reply, :ok, Dict.update!(state, :state_machine, &StateMachine.delete/1)}
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
    Vassal.Queue.QueueMessages.enqueue(state.queue_messages_pid, self)
    {:noreply, state}
  end

  def handle_info(:start_visibility_timer, state) do
    timer_ref = :erlang.start_timer(state.message.visibility_timeout_ms,
                                    self,
                                    :timer_expired)
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
end

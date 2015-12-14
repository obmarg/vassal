defmodule Vassal.Queue.ReceiptHandles do
  @moduledoc """
  This module provides an agent for managing a queues receipt handles.
  """

  def start_link(queue_name) do
    Agent.start_link fn ->
      queue_name |> to_gproc_name |> :gproc.reg

      %{receipts_to_pid: %{}, pid_to_receipts: %{}}
    end
  end

  @doc """
  Returns the PID of a ReceiptHandles process when given the queue name.
  """
  def for_queue(queue_name, timeout \\ 50) do
    {pid, _} = queue_name |> to_gproc_name |> :gproc.await(timeout)
    pid
  end

  @doc """
  Creates a receipt handle for a message.
  """
  def create_receipt(receipts_pid, message_pid) do
    receipt_handle = UUID.uuid4
    Agent.update receipts_pid, fn (state) ->
      r_to_p = Dict.put(state.receipts_to_pid, receipt_handle, message_pid)
      p_to_r = Dict.update(state.pid_to_receipts,
                           message_pid,
                           [],
                           &(List.insert_at &1, 0, receipt_handle))

      %{state | receipts_to_pid: r_to_p,
                pid_to_receipts: p_to_r}
    end
    receipt_handle
  end

  @doc """
  Deletes a message by its receipt handle.
  """
  def get_pid_from_handle(receipts_pid, receipt_handle) do
    Agent.get receipts_pid, fn (state) ->
      state.receipts_to_pid[receipt_handle]
    end
  end

  @doc """
  Deletes all records related to a receipt handle & its PID.
  """
  def delete_handle(receipts_pid, receipt_handle) do
    Agent.update receipts_pid, fn (state) ->
      pid = state.receipts_to_pid[receipt_handle]
      receipts = state.pid_to_receipts[pid]
      %{state | pid_to_receipts: Dict.drop(state.pid_to_receipts, [pid]),
                receipts_to_pid: Dict.drop(state.receipts_to_pid, receipts)}
    end
  end

  defp to_gproc_name(queue_name) do
    {:n, :l, "queue.#{queue_name}.receipt_handles"}
  end
end

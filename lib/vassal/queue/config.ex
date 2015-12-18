defmodule Vassal.Queue.Config do
  @moduledoc """
  A struct that defines the configuration for a queue.
  """

  alias Vassal.Utils

  defstruct [delay_ms: 0,
             max_message_bytes: 256 * 1024,
             retention_secs: 60 * 60 * 24 * 4,
             recv_wait_time_ms: 0,
             visibility_timeout_ms: 30 * 1000,
             max_receives: nil,
             dead_letter_queue: nil]

  @type t :: %__MODULE__{
    delay_ms: non_neg_integer,
    max_message_bytes:  non_neg_integer,
    retention_secs:  non_neg_integer,
    recv_wait_time_ms:  non_neg_integer,
    visibility_timeout_ms:  non_neg_integer,
    max_receives: non_neg_integer | nil,
    dead_letter_queue: String.t | nil
  }

  @spec from_incoming_attrs(%{}) :: __MODULE__.t
  def from_incoming_attrs(attrs) do
    import Utils, only: [get_param_as_ms: 2, get_param_as_int: 2]

    rv = %{
      delay_ms: get_param_as_ms(attrs, :delay_seconds),
      max_message_bytes: get_param_as_int(attrs, :maximum_message_size),
      retention_secs: get_param_as_int(attrs, :message_retention_period),
      recv_wait_time_ms: get_param_as_ms(attrs,
                                         :receive_message_wait_time_seconds),
      visibility_timeout_ms: get_param_as_ms(attrs, :visibility_timeout)
    }

    if attrs[:redrive_policy] do
      redrive = Poison.decode!(attrs[:redrive_policy])
      dead_letter_queue = nil
      if redrive["deadLetterTargetArn"] do
        dead_letter_queue =
          redrive["deadLetterTargetArn"]
            |> String.split(":")
            |> List.last
      end
      rv = rv
      |> Dict.put(:max_receives, redrive["maxReceiveCount"])
      |> Dict.put(:dead_letter_queue, dead_letter_queue)
    end

    defaults = Map.from_struct(%__MODULE__{})
    rv = Dict.merge(rv, defaults, fn(_, v1, v2) -> v1 || v2 end)
    struct(__MODULE__, rv)
  end

  @spec from_incoming_attrs(__MODULE__.t) :: %{}
  def to_outgoing_attrs(config) do
    rv = %{
      "DelaySeconds" => div(config.delay_ms, 1000),
      "MaximumMessageSize" => config.max_message_bytes,
      "MessageRetentionPeriod" => config.retention_secs,
      "ReceiveMessageWaitTimeSeconds" => div(config.recv_wait_time_ms, 1000),
      "VisibilityTimeout" => div(config.visibility_timeout_ms, 1000),
    }
    if config.max_receives do
      redrive_policy = %{"maxReceiveCount" => config.max_receives}
      if config.dead_letter_queue do
        redrive_policy = Dict.put(redrive_policy,
                                  "deadLetterTargetArn",
                                  Utils.make_arn(config.dead_letter_queue))
      end
      rv = Dict.put(rv, "RedrivePolicy", Poison.encode!(redrive_policy))
    end
    rv
  end
end

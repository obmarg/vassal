defmodule Vassal.Actions.ReceiveMessage do
  @moduledoc """
  Action for sending a message.
  """

  @derive [Inspect]
  defstruct [queue_name: nil,
             max_messages: 1,
             visibility_timeout_ms: 30 * 1000,
             wait_time_ms: 0,
             attributes: [],
             message_attributes: []]

  @type t :: %__MODULE__{
    queue_name: String.t,
    max_messages: non_neg_integer,
    visibility_timeout_ms: non_neg_integer,
    wait_time_ms: non_neg_integer,
    attributes: [:atom],
    message_attributes: [:atom]
  }

  def from_params(params, queue_name) do
    {vis_secs, ""} = Integer.parse(Dict.get(params, :VisibilityTimeout, "30"))
    {wait_secs, ""} = Integer.parse(Dict.get(params, :WaitTimeSeconds, "0"))
    {max_msgs, ""} = Integer.parse(Dict.get(params, :MaxNumberOfMessages, "1"))

    %__MODULE__{queue_name: queue_name,
                max_messages: max_msgs,
                visibility_timeout_ms: vis_secs * 1000,
                wait_time_ms: wait_secs * 1000,
                attributes: [],
                message_attributes: []}
  end

  defimpl Vassal.Actions.ActionValidator, for: __MODULE__ do
    def valid?(action) do
      Vassal.Actions.valid_queue_name?(action.queue_name)
      and
      Vassal.Actions.valid_attributes?(action.attributes)
      and
      (action.max_messages in 1..10)
    end
  end

  defmodule Message do
    @moduledoc """
    A message that will be returned from the ReceiveMessage action.
    """
    defstruct [message_id: nil,
               receipt_handle: nil,
               body_md5: nil,
               attributes: %{}]
  end

  defmodule Result do
    @moduledoc """
    The result of a SendMessage request.
    """
    defstruct messages: []

    defimpl Vassal.Actions.Response, for: __MODULE__ do
      require EEx
      EEx.function_from_file(
        :def, :from_result,
        "lib/vassal/actions/response_templates/receive_message.xml.eex",
        [:result]
      )
    end
  end
end

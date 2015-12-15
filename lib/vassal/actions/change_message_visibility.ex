defmodule Vassal.Actions.ChangeMessageVisibility do
  @moduledoc """
  Action for changing the visibility timeout of a message.
  """

  @derive [Inspect]
  defstruct [queue_name: nil,
             receipt_handle: nil,
             visibility_timeout_ms: nil]

  @type t :: %__MODULE__{
    queue_name: String.t,
    receipt_handle: String.t,
    visibility_timeout_ms: non_neg_integer
  }

  def from_params(params, queue_name) do
    {vis_secs, ""} = Integer.parse(params["VisibilityTimeout"])
    %__MODULE__{queue_name: queue_name,
                receipt_handle: params["ReceiptHandle"],
                visibility_timeout_ms: vis_secs * 1000}
  end

  defimpl Vassal.Actions.ActionValidator, for: __MODULE__ do
    def valid?(action) do
      Vassal.Actions.valid_queue_name?(action.queue_name)
      and
      (String.length(action.receipt_handle) > 1)
      and
      action.visibility_timeout_ms in 0..43200000
    end
  end

  defmodule Result do
    @moduledoc """
    The result of a ChangeMessageVisibility request.
    """
    defstruct []

    defimpl Vassal.Actions.Response, for: __MODULE__ do
      require EEx
      EEx.function_from_file(
        :def, :from_result,
        ("lib/vassal/actions/response_templates" <>
         "/change_message_visibility.xml.eex"),
        [:_result]
      )
    end
  end
end

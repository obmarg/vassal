defmodule Vassal.Actions.DeleteMessage do
  @moduledoc """
  Action for deleting a message.
  """

  @derive [Inspect]
  defstruct [queue_name: nil,
             receipt_handle: nil]

  @type t :: %__MODULE__{
    queue_name: String.t,
    receipt_handle: String.t,
  }

  def from_params(params, queue_name) do
    %__MODULE__{queue_name: queue_name,
                receipt_handle: params["ReceiptHandle"]}
  end

  defimpl Vassal.Actions.ActionValidator, for: __MODULE__ do
    def valid?(action) do
      Vassal.Actions.valid_queue_name?(action.queue_name)
      and
      (String.length(action.receipt_handle) > 1)
    end
  end

  defmodule Result do
    @moduledoc """
    The result of a SendMessage request.
    """
    defstruct []

    defimpl Vassal.Actions.Response, for: __MODULE__ do
      require EEx
      EEx.function_from_file(
        :def, :from_result,
        "lib/vassal/actions/response_templates/delete_message.xml.eex",
        [:result]
      )
    end
  end
end

defmodule Vassal.Actions.DeleteQueue do
  @moduledoc """
  Action for deleting a queue.
  """

  @derive [Inspect]
  defstruct [queue_name: nil]

  @type t :: %__MODULE__{
    queue_name: String.t
  }

  def from_params(_params, queue_name) do
    %__MODULE__{queue_name: queue_name}
  end

  defimpl Vassal.Actions.ActionValidator, for: __MODULE__ do
    def valid?(action) do
      Vassal.Actions.valid_queue_name?(action.queue_name)
    end
  end

  defmodule Result do
    @moduledoc """
    The result of a DeleteQueue request.
    """
    defstruct []

    defimpl Vassal.Actions.Response, for: __MODULE__ do
      require EEx
      EEx.function_from_file(
        :def, :from_result,
        "lib/vassal/actions/response_templates/delete_queue.xml.eex",
        [:_result]
      )
    end
  end
end

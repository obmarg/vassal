defmodule Vassal.Actions.GetQueueUrl do
  @moduledoc """
  Action for getting the URL of a queue if it exists.
  """
  defstruct queue_name: nil

  def from_params(params) do
    %__MODULE__{queue_name: params["QueueName"]}
  end

  defimpl Vassal.Actions.ActionValidator, for: __MODULE__ do
    def valid?(action) do
      Vassal.Actions.valid_queue_name?(action.queue_name)
    end
  end

  defmodule Result do
    @moduledoc """
    The result of a GetQueueUrl request.
    """
    defstruct queue_url: nil

    defimpl Vassal.Actions.Response, for: __MODULE__ do
      require EEx
      EEx.function_from_file(
        :def, :from_result,
        "lib/vassal/actions/response_templates/get_queue_url.xml.eex",
        [:result]
      )
    end
  end
end

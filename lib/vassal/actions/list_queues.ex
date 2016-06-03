defmodule Vassal.Actions.ListQueues do
  @moduledoc """
  Action for listing all queues.
  """
  defstruct prefix: nil

  def from_params(params) do
    %__MODULE__{prefix: params["QueueNamePrefix"]}
  end

  defimpl Vassal.Actions.ActionValidator, for: __MODULE__ do
    def valid?(_action), do: true
  end

  defmodule Result do
    @moduledoc """
    The result of a ListQueues request.
    """
    defstruct queue_urls: nil

    defimpl Vassal.Actions.Response, for: __MODULE__ do
      require EEx
      EEx.function_from_file(
        :def, :from_result,
        "lib/vassal/actions/response_templates/list_queues.xml.eex",
        [:result]
      )
    end
  end
end

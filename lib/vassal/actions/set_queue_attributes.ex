defmodule Vassal.Actions.SetQueueAttributes do
  @moduledoc """
  Action for setting queue attributes.
  """

  @derive [Inspect]
  defstruct queue_name: nil, attributes: %{}

  @type t :: %__MODULE__{
    queue_name: String.t,
    attributes: %{:atom => String.t}
  }

  @spec from_params(Plug.Conn.params) :: t
  def from_params(params) do
    %__MODULE__{queue_name: params["QueueName"],
                attributes: Vassal.Utils.parse_attribute_map(params)}
  end

  defimpl Vassal.Actions.ActionValidator, for: __MODULE__ do
    def valid?(action) do
      Vassal.Actions.valid_queue_name?(action.queue_name)
      and
      Vassal.Actions.valid_attributes?(action.attributes)
    end
  end

  defmodule Result do
    @moduledoc """
    The result of a SetQueueAttribute request.
    """
    defstruct []

    defimpl Vassal.Actions.Response, for: __MODULE__ do
      require EEx
      EEx.function_from_file(
        :def, :from_result,
        "lib/vassal/actions/response_templates/set_queue_attributes.xml.eex",
        [:_result]
      )
    end
  end
end

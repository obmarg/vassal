defmodule Vassal.Actions.CreateQueue do
  @moduledoc """
  Action for creating a Queue if it doesn't exist.
  """

  @derive [Inspect]
  defstruct queue_name: nil, attributes: %{}

  @type t :: %__MODULE__{
    queue_name: String.t,
    attributes: %{:atom => String.t}
  }

  @spec from_params(Plug.Conn.params) :: __MODULE__.t
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
    The result of a CreateQueue request.
    """
    defstruct queue_url: nil

    defimpl Vassal.Actions.Response, for: __MODULE__ do
      require EEx
      EEx.function_from_file(
        :def, :from_result,
        "lib/vassal/actions/response_templates/create_queue.xml.eex",
        [:result]
      )
    end
  end
end

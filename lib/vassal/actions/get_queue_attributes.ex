defmodule Vassal.Actions.GetQueueAttributes do
  @moduledoc """
  Action for getting queue attributes.
  """

  @derive [Inspect]
  defstruct queue_name: nil, attributes: %{}

  @type t :: %__MODULE__{
    queue_name: String.t,
    attributes: [String.t]
  }

  def from_params(params, queue_name) do
    %__MODULE__{queue_name: queue_name,
                attributes: parse_attributes_list(params)}
  end

  defp parse_attributes_list(params) do
    params
    |> Enum.filter(fn ({p, _}) -> String.starts_with?(p, "AttributeName") end)
    |> Enum.map(fn ({_, value}) -> value end)
  end

  defp attr_name_to_atom(attr_name) do
    attr_name |> Mix.Utils.underscore |> String.to_existing_atom
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
    The result of a GetQueueAttribute request.
    """
    defstruct attributes: %{}

    defimpl Vassal.Actions.Response, for: __MODULE__ do
      require EEx
      EEx.function_from_file(
        :def, :from_result,
        "lib/vassal/actions/response_templates/get_queue_attributes.xml.eex",
        [:result]
      )
    end
  end
end

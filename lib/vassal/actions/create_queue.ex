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

  def from_params(params) do
    %__MODULE__{queue_name: params["QueueName"],
                attributes: parse_attrs(params)}
  end

  defp parse_attrs(params) do
    params
    |> Enum.filter(fn ({p, _}) -> String.contains?(p, "Attribute.") end)
    |> Enum.sort_by(fn ({param, _}) -> param end)
    |> Enum.map(fn ({_, value}) -> value end)
    |> Enum.chunk(2)
    |> Enum.map(fn ([key, val]) -> {attr_name_to_atom(key), val} end)
    |> Enum.into(%{})
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


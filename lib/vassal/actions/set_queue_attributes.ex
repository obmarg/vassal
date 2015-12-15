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

  def from_params(params, queue_name) do
    %__MODULE__{queue_name: queue_name,
                attributes: parse_attrs(params)}
  end

  defp parse_attrs(params) do
    params
    |> Enum.filter(fn {k, _} -> String.contains?(k, "Attribute.") end)
    |> Enum.group_by(fn {k, _} -> k |> String.split(".") |> List.last end)
    |> Enum.map(fn {_, vals} ->
      Enum.group_by(vals, fn {k, _} ->
        [_, x, _] = String.split(k, ".")
        x
      end)
    end)
    |> Enum.map(fn kv_dict ->
      [{_, key}] = kv_dict["Name"]
      [{_, value}] = kv_dict["Value"]
      {key |> attr_name_to_atom, value}
    end)
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
    The result of a SetQueueAttribute request.
    """
    defstruct []

    defimpl Vassal.Actions.Response, for: __MODULE__ do
      require EEx
      EEx.function_from_file(
        :def, :from_result,
        "lib/vassal/actions/response_templates/set_queue_attributes.xml.eex",
        [:result]
      )
    end
  end
end

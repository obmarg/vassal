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

  def from_params(params) do
    %__MODULE__{queue_name: params["QueueName"],
                attributes: parse_attrs(params)}
  end

  defp parse_attrs(params) do
    params
    |> Enum.filter(fn {k, _} -> String.contains?(k, "Attribute.") end)
    |> Enum.map(fn {k, v} -> {parse_attr_key(k), v} end)
    |> Enum.group_by(fn {k, _} -> k["num"] end)
    |> Enum.map(fn {_, vals} ->
      Enum.group_by(vals, fn {k, _} -> k["type"] end)
    end)
    |> Enum.map(fn (kv_dict) ->
      [{_, key}] = kv_dict["Name"]
      [{_, value}] = kv_dict["Value"]
      {key |> attr_name_to_atom, value}
    end)
    |> Enum.into(%{})
  end

  defp parse_attr_key(attr_key) do
    # attr_key can either be "Attribute.1.Name" or "Attribute.1.Name"
    rv = Regex.named_captures(~r/^Attribute\.(?<num>\d+)\.(?<type>\w+)$/,
                              attr_key)
    unless rv do
      rv = Regex.named_captures(~r/^Attribute\.(?<type>\w+)\.(?<num>\d+)$/,
                                attr_key)
    end
    rv
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
        [:_result]
      )
    end
  end
end

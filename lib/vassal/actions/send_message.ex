defmodule Vassal.Actions.SendMessage do
  @moduledoc """
  Action for sending a message.
  """

  @derive [Inspect]
  defstruct [queue_name: nil,
             message_body: nil,
             delay_ms: 0,
             message_attributes: %{}]

  @type t :: %__MODULE__{
    queue_name: String.t,
    message_body: <<>>,
    delay_ms: non_neg_integer,
    message_attributes: %{:atom => String.t}
  }

  def from_params(params) do
    {delay_secs, ""} = Integer.parse(Dict.get(params, :Delay, "0"))
    %__MODULE__{queue_name: params["QueueName"],
                message_body: params["MessageBody"],
                delay_ms: delay_secs * 1000,
                message_attributes: parse_attrs(params)}
  end

  defp parse_attrs(params) do
    # TODO: this won't work if anyone passes Type as well as key & value...
    params
    |> Enum.filter(fn ({p, _}) -> String.contains?(p, "MessageAttribute.") end)
    |> Enum.sort_by(fn ({param, _}) -> param end)
    |> Enum.map(fn ({_, value}) -> value end)
    |> Enum.chunk(2)
    |> Enum.map(fn ([key, val]) -> {attr_name_to_atom(key), val} end)
    |> Enum.into(%{})
  end

  defp attr_name_to_atom(attr_name) do
    attr_name |> Macro.underscore |> String.to_existing_atom
  end

  defimpl Vassal.Actions.ActionValidator, for: __MODULE__ do
    def valid?(action) do
      Vassal.Actions.valid_queue_name?(action.queue_name)
      and
      (action.delay_ms in 0..900000)
    end
  end

  defmodule Result do
    @moduledoc """
    The result of a SendMessage request.
    """
    defstruct message_id: nil, body_md5: nil, attrs_md5: nil

    defimpl Vassal.Actions.Response, for: __MODULE__ do
      require EEx
      EEx.function_from_file(
        :def, :from_result,
        "lib/vassal/actions/response_templates/send_message.xml.eex",
        [:result]
      )
    end
  end
end

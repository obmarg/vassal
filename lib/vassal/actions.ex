defmodule Vassal.Actions do
  @moduledoc """
  Defines a number of structs that represent SQS API actions.

  Implements parsing & validation of these structs from incoming parameters.
  """
  defmodule InvalidActionError do
    @moduledoc """
    Error thrown when an invalid action is attempted.
    """
    defexception message: "Invalid action!"
  end

  defprotocol ActionValidation do
    @doc """
    Returns true if the actions data is valid.
    """
    @fallback_to_any
    def valid?(action)
  end

  defimpl ActionValidation, for: Any do
    def valid?(action), do: true
  end

  def valid!(action) do
    if Vassal.Actions.ActionValidation.valid?(action) do
      action
    else
      raise InvalidActionError
    end
  end

  defmodule CreateQueue do
    @moduledoc """
    Action for creating a Queue if it doesn't exist.
    """

    @derive [Inspect]
    defstruct queue_name: nil, attributes: %{}

    @type t :: %CreateQueue{queue_name: String.t,
                            attributes: %{:atom => String.t}}

    # We define these here because they're allowed, but we do nothing with them.
    @ignored_attrs [:policy,
                    :visibility_timeout,
                    :maximum_message_size,
                    :message_retention_period,
                    :delay_seconds,
                    :receive_message_wait_time_seconds,
                    :redrive_policy]

    def from_params(params) do
      %CreateQueue{queue_name: params["QueueName"],
                   attributes: parse_attrs(params)}
    end

    defp parse_attrs(params) do
      params
      |> Enum.filter(fn ({p, _}) -> String.contains?(p, "Attribute.") end)
      |> Enum.sort_by(fn ({param, _}) -> param end)
      |> Enum.map(fn ({_, value}) -> value end)
      |> Enum.chunk(2)
      |> Enum.map(fn ([key, val]) -> {String.to_existing_atom(key), val} end)
      |> Enum.into(%{})
    end
  end

  defimpl ActionValidation, for: CreateQueue do
    def valid?(action) do
      cond do
        not Regex.match?(~r/[\w-]{1,80}/, action.queue_name) -> false
        true -> true
      end
    end
  end

  @doc """
  Converts incoming parameters into an action.
  """
  def params_to_action(params) do
    case params["Action"] do
      "CreateQueue" -> CreateQueue.from_params(params)
    end
  end

end

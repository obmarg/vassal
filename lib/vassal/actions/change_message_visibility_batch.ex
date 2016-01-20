defmodule Vassal.Actions.ChangeMessageVisibilityBatch do
  @moduledoc """
  Action for ChangeMessageVisibilityBatch
  """

  alias Vassal.Actions.ChangeMessageVisibility

  @derive [Inspect]
  defstruct [actions: []]

  @type t :: %__MODULE__{
    actions: [{String.t, ChangeMessageVisibility.t}]
  }

  @entry_name "ChangeMessageVisibilityBatchRequestEntry"

  @spec from_params(Plug.Conn.params) :: __MODULE__.t
  def from_params(params) do
    import Vassal.Utils, only: [parse_parameter_map: 2]

    actions = params
    |> Enum.map(&(parse_parameter_map(&1, @entry_name)))
    |> Enum.map(fn {action_map} ->
      {action_map["Id"], ChangeMesssageVisibility.from_params(params)}
    end)

    %__MODULE__{
      actions: actions
    }
  end

  defimpl Vassal.Actions.ActionValidator, for: __MODULE__ do
    def valid?(action) do
      Enum.all?(action.actions, &Vassal.Actions.ActionValidator.valid?/1)
    end
  end

  defmodule Result do
    @moduledoc """
    The result of a ChangeMessageVisibilityBatch request.
    """
    defstruct results: nil

    defimpl Vassal.Actions.Response, for: __MODULE__ do
      require EEx
      EEx.function_from_file(
        :def, :from_result,
        ("lib/vassal/actions/response_templates/" <>
         "change_message_visibility_batch.xml.eex")
      )
    end
  end

end

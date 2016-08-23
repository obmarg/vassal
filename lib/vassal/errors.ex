defmodule Vassal.Errors do
  @moduledoc """
  Defines the errors we can return from Vassal.
  """
  defmodule SQSError do
    @moduledoc """
    Error raised/returned to send an SQS error to the user.
    """
    defexception code: "", type: "Sender", message: "SQSError"

    @doc """
    Convenience method for raising exceptions.

    Allows this:

    raise SQSError, "SQS.SimpleQueueService.SomeError"
    """
    def exception(code) when is_binary(code) do
      msg = "#{code}; See SQS Docs for more details"
      %SQSError{message: msg, code: code}
    end

    def exception(attrs) do
      struct(__MODULE__, attrs)
    end

    defimpl Vassal.Actions.Response, for: __MODULE__ do
      require EEx
      EEx.function_from_file(
        :def, :from_result,
        "lib/vassal/actions/response_templates/error.xml.eex",
        [:result]
      )
    end
  end

  defmodule InvalidActionError do
    @moduledoc """
    Error thrown when an invalid action is attempted.
    """
    defexception message: "Invalid action!"
  end
end

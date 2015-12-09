defmodule Vassal.Actions do
  @moduledoc """
  This module contains the structs that represent API actions & their results.

  It also defines some protocols & functions for parsing those actions,
  validating that they are correct, and serializing responses to XML.

  Each individual action struct is responsible for implementing each of the
  protocols required.
  """

  @doc """
  Converts incoming parameters into an action.
  """
  def params_to_action(params) do
    case params["Action"] do
      "CreateQueue" -> Vassal.Actions.CreateQueue.from_params(params)
      "GetQueueUrl" -> Vassal.Actions.GetQueueUrl.from_params(params)
      _ -> raise Vassal.Errors.SQSError, "AWS.SimpleQueueService.InvalidAction"
    end
  end

  @doc """
  Chckes if an action is valid, and raises an InvalidActionError if not.
  """
  def valid!(action) do
    if Vassal.Actions.ActionValidator.valid?(action) do
      action
    else
      raise Vassal.Errors.InvalidActionError
    end
  end

  defprotocol ActionValidator do
    @doc """
    Returns true if the actions data is valid.
    """
    @fallback_to_any
    def valid?(action)
  end

  defimpl ActionValidator, for: Any do
    def valid?(action), do: true
  end

  @doc """
  Validates a queue name.
  """
  def valid_queue_name?(queue_name) do
    Regex.match?(~r/[\w-]{1,80}/, queue_name)
  end

  defprotocol Response do
    @doc """
    Converts a result struct into XML suitable for response.
    """
    def from_result(result)
  end

  @moduledoc """
  Utility function for adding response metadata into our response XML.
  """
  def response_metadata do
    """
    <ResponseMetadata>
        <RequestId>
           #{UUID.uuid4}
        </RequestId>
    </ResponseMetadata>
    """
  end
end

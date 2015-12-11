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
    @moduledoc """
    Validates the data in an action.
    """

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

  @valid_attrs Enum.into HashSet.new, [:policy,
                                       :visibility_timeout,
                                       :maximum_message_size,
                                       :message_retention_period,
                                       :delay_seconds,
                                       :receive_message_wait_time_seconds,
                                       :redrive_policy]

  @doc """
  Validates a set of attributes.

  Some of these may not be valid attributes for this operation, but those should
  just be ignored.
  """
  def valid_attributes?(attrs) do
    attrs
    |> Dict.keys
    |> Enum.all?(&(Set.member?(@valid_attrs, &1)))
  end

  defprotocol Response do
    @moduledoc """
    Handles converting result structs into response XML.
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

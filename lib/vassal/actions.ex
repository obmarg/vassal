defmodule Vassal.Actions do
  @moduledoc """
  This module contains the structs that represent API actions & their results.

  It also defines some protocols & functions for parsing those actions,
  validating that they are correct, and serializing responses to XML.

  Each individual action struct is responsible for implementing each of the
  protocols required.
  """

  require Logger

  @type action :: Vassal.Actions.CreateQueue.t
                | Vassal.Actions.GetQueueUrl.t
                | Vassal.Actions.SendMessage.t
                | Vassal.Actions.ReceiveMessage.t
                | Vassal.Actions.DeleteMessage.t
                | Vassal.Actions.ChangeMessageVisibility.t
                | Vassal.Actions.DeleteQueue.t
                | Vassal.Actions.SetQueueAttributes.t
                | Vassal.Actions.GetQueueAttributes.t

  @type result :: Vassal.Actions.CreateQueue.Result.t
                | Vassal.Actions.GetQueueUrl.Result.t
                | Vassal.Actions.SendMessage.Result.t
                | Vassal.Actions.ReceiveMessage.Result.t
                | Vassal.Actions.DeleteMessage.Result.t
                | Vassal.Actions.ChangeMessageVisibility.Result.t
                | Vassal.Actions.DeleteQueue.Result.t
                | Vassal.Actions.SetQueueAttributes.Result.t
                | Vassal.Actions.GetQueueAttributes.Result.t

  @doc """
  Converts incoming parameters into a queue action.
  """
  @spec params_to_action(Plug.Conn.params) :: action
  def params_to_action(params) do
    try do
      module = Module.safe_concat([Vassal, Actions, params["Action"]])
      module.from_params(params)
    rescue
      _ in [UndefinedFunctionError, ArgumentError] ->
        Logger.error("Unknown action #{params["Action"]}")
        raise Vassal.Errors.SQSError, "AWS.SimpleQueueService.InvalidAction"
    end
  end

  @doc """
  Chckes if an action is valid, and raises an InvalidActionError if not.
  """
  @spec valid!(action) :: action
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
    @spec valid?(t) :: boolean
    def valid?(action)
  end

  @doc """
  Validates a queue name.
  """
  @spec valid_queue_name?(String.t) :: boolean
  def valid_queue_name?(queue_name) do
    Regex.match?(~r/[\w-]{1,80}/, queue_name)
  end

  @valid_attrs Enum.into [:all,
                          :policy,
                          :visibility_timeout,
                          :maximum_message_size,
                          :message_retention_period,
                          :delay_seconds,
                          :receive_message_wait_time_seconds,
                          :redrive_policy,
                          :approximate_first_receive_timestamp,
                          :approximate_receive_count,
                          :sender_id,
                          :sent_timestamp], HashSet.new

  @doc """
  Validates a set of attributes.

  Some of these may not be valid attributes for this operation, but those should
  just be ignored.
  """
  def valid_attributes?(attrs) when is_map(attrs) do
    attrs |> Dict.keys |> valid_attributes?
  end

  def valid_attributes?(attrs) when is_list(attrs) do
    Enum.all?(attrs, &valid_attribute?/1)
  end

  def valid_attribute?(attr) when is_atom(attr) do
    Set.member?(@valid_attrs, attr)
  end

  def valid_attribute?(attr) when is_binary(attr) do
    try do
      attr
      |> Mix.Utils.underscore
      |> String.to_existing_atom
      |> valid_attribute?
    rescue
      ArgumentError -> false
    end
  end

  defprotocol Response do
    @moduledoc """
    Handles converting result structs into response XML.
    """

    @spec from_result(t) :: String.t
    def from_result(result)
  end

  @doc """
  Utility function for adding response metadata into our response XML.
  """
  @spec response_metadata :: String.t
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

defmodule Vassal.Utils do
  @moduledoc """
  Utility functions for Vassal
  """

  @doc """
  Gets a parameter from a dict as an integer
  """
  @spec get_param_as_int(%{}, String.t | :atom) :: integer | nil
  def get_param_as_int(params, param_name) do
    data = Dict.get(params, param_name, nil)
    if data do
      {data, ""} = Integer.parse(data)
      data
    else
      nil
    end
  end

  @doc """
  Gets a parameter from a dict and converts to milliseconds.
  """
  @spec get_param_as_ms(%{}, String.t | :atom) :: integer | nil
  def get_param_as_ms(params, param_name) do
    secs = get_param_as_int(params, param_name)
    if secs do
      secs * 1000
    else
      nil
    end
  end

  @doc """
  Builds a fake ARN from a queue_name
  """
  @spec make_arn(String.t) :: String.t
  def make_arn(queue_name) do
    "arn:aws:sqs:vassal:000000000000:#{queue_name}"
  end

end

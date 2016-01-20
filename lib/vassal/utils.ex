defmodule Vassal.Utils do
  @moduledoc """
  Utility functions for Vassal.

  Most (though not all) of these are for parsing parameters.
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

  @doc """
  Parses a parameter map out of a list of all parameters.

  `param_prefix` should be set to the name of the parameter map.
  """
  @spec parse_parameter_map(Plug.Conn.params, String.t) :: [%{}]
  def parse_parameter_map(params, param_prefix) do
    params
    |> Enum.filter(fn {k, _} -> String.starts_with?(k, param_prefix) end)
    |> Enum.map(fn {k, v} -> {parse_parameter_map_key(k, param_prefix), v} end)
    |> group_by_num_and_type
  end

  @doc """
  Takes a string in AttributeName format and converts to a snake-case atom.
  """
  @spec attr_name_to_atom(String.t) :: :atom
  def attr_name_to_atom(attr_name) do
    attr_name |> Mix.Utils.underscore |> String.to_existing_atom
  end

  @doc """
  Parses attributes from some parameters.
  """
  @spec parse_attribute_map(Plug.Conn.params) :: %{atom: String.t}
  def parse_attribute_map(params) do
    params
    |> parse_parameter_map("Attribute")
    |> Enum.map(fn (%{"Name" => key, "Value" => value}) ->
      {key |> attr_name_to_atom, value}
    end)
    |> Enum.into(%{})
  end

  @typep parsed_parameter_map_key :: %{num: String.t, type: String.t}

  @spec group_by_num_and_type(parsed_parameter_map_key) :: [%{}]
  defp group_by_num_and_type(parsed_params) do
    parsed_params
    |> Enum.group_by(fn {k, _} -> k["num"] end)
    |> Enum.map(fn {_, vals} ->
      Enum.group_by(vals, fn {k, _} -> k["type"] end)
    end)
    |> Enum.map(fn (kv_dict) ->
      kv_dict
      |> Enum.map(fn {key, [{_, val}]} -> {key, val} end)
      |> Enum.into(%{})
    end)
  end

  defmacrop do_key_parsing(param_name, key) do
    regex1 = Macro.escape(~r/^#{param_name}\.(?<type>\w+)\.(?<num>\d+)/)
    regex2 = Macro.escape(~r/^#{param_name}\.(?<num>\d+)\.(?<type>\w+)/)

    quote do
      rv = Regex.named_captures(unquote(regex1), unquote(key))
      unless rv do
        rv = Regex.named_captures(unquote(regex2), unquote(key))
      end
      rv
    end
  end

  @spec parse_parameter_map_key(String.t, :atom) :: parsed_parameter_map_key
  defp parse_parameter_map_key(key, "Attribute") do
    do_key_parsing("Attribute", key)
  end

end

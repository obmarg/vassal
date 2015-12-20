defmodule Vassal.UtilsTest do
  use ExUnit.Case, async: true

  import Vassal.Utils

  test "parsing parameter map in number first format" do
    result = parse_parameter_map(
      %{"Attribute.1.Name" => "Test",
        "Attribute.1.Value" => "Yep",
        "Attribute.2.Name" => "Sure?",
        "Attribute.2.Value" => "Yep!"}, "Attribute"
    )
    assert result == [%{"Name" => "Test", "Value" => "Yep"},
                      %{"Name" => "Sure?", "Value" => "Yep!"}]
  end

  test "parsing parameter map in number last format" do
    result = parse_parameter_map(
      %{"Attribute.Name.1" => "Test",
        "Attribute.Value.1" => "Yep",
        "Attribute.Name.2" => "Sure?",
        "Attribute.Value.2" => "Yep!"}, "Attribute"
    )
    assert result == [%{"Name" => "Test", "Value" => "Yep"},
                      %{"Name" => "Sure?", "Value" => "Yep!"}]
  end

  test "parsing attribute map" do
    result = parse_attribute_map(
      %{"Attribute.Name.1" => "Test",
        "Attribute.Value.1" => "Yep",
        "Attribute.Name.2" => "Sure",
        "Attribute.Value.2" => "Yep!"}
    )
    assert result == %{test: "Yep", sure: "Yep!"}
  end
end

defmodule Vassal.Results do
  @moduledoc """
  This module defines the results structs of various operations.
  """

  defmodule CreateQueueResult do
    @moduledoc """
    The result of a CreateQueue request.
    """
    defstruct queue_name: nil
  end

  defprotocol Result do
    @doc """
    Converts a result struct into XML suitable for response.
    """
    def to_xml(result)
  end

  defimpl Result, for: CreateQueueResult do
    require EEx
    EEx.function_from_file(:def, :to_xml,
                           "lib/vassal/results/create_queue.xml.eex",
                           [:result])
  end
end

defmodule Vassal.Results do
  @moduledoc """
  This module defines the results structs of various operations.
  """

  defprotocol Result do
    @doc """
    Converts a result struct into XML suitable for response.
    """
    def to_xml(result)
  end

  defmodule CreateQueueResult do
    @moduledoc """
    The result of a CreateQueue request.
    """
    defstruct queue_url: nil
  end

  defimpl Result, for: CreateQueueResult do
    require EEx
    EEx.function_from_file(:def, :to_xml,
                           "lib/vassal/results/create_queue.xml.eex",
                           [:result])
  end

  defmodule GetQueueUrlResult do
    @moduledoc """
    The result of a GetQueueUrl request.
    """
    defstruct queue_url: nil
  end

  defimpl Result, for: GetQueueUrlResult do
    require EEx
    EEx.function_from_file(:def, :to_xml,
                           "lib/vassal/results/get_queue_url.xml.eex",
                           [:result])
  end

  defmodule SQSError do
    @moduledoc """
    Error raised/returned to send an SQS error to the user.
    """
    defexception code: "", type: "Sender"
  end

  defimpl Result, for: SQSError do
    require EEx
    EEx.function_from_file(:def, :to_xml,
                           "lib/vassal/results/error.xml.eex",
                           [:result])
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

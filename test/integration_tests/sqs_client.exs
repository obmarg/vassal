defmodule SQSClient do
  use ExAws.SQS.Client

  def config_root do
    Application.get_env(:vassal, ExAws)
  end
end

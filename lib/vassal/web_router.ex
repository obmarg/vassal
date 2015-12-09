defmodule Vassal.WebRouter do
  @moduledoc """
  This module provides the HTTP endpoint for SQS emulation.
  """
  require Logger

  use Plug.Router
  use Plug.ErrorHandler

  if Mix.env != :test do
    # Don't log when we're testing as it obscures test output.
    plug Plug.Logger
  end

  plug Plug.Parsers, parsers: [:urlencoded]
  plug :match
  plug :dispatch

  alias Vassal.Results.SQSError

  def init(_options) do
    []
  end

  get "/" do
    conn
    |> put_resp_header("content-type", "application/xml")
    |> send_resp(200, handle_general_request(conn))
  end

  post "/" do
    conn
    |> put_resp_header("content-type", "application/xml")
    |> send_resp(200, handle_general_request(conn))
  end

  defp handle_general_request(%{params: params}) do
    # Routes non queue-specific requests.
    params
    |> Vassal.Actions.params_to_action
    |> Vassal.Actions.valid!
    |> Vassal.QueueManager.do_action
    |> Vassal.Results.Result.to_xml
  end

  defp handle_errors(conn, %{reason: %Vassal.Results.SQSError{} = error}) do
    conn
    |> put_resp_header("content-type", "application/xml")
    |> send_resp(400, Vassal.Results.Result.to_xml(error))
  end
  defp handle_errors(conn, %{reason: unknown}) do
    Logger.error("Unknown Error:")
    Logger.error(unknown)
    conn
    |> put_resp_header("content-type", "application/xml")
    |> send_resp(400, Vassal.Results.Result.to_xml(
          %Vassal.Results.SQSError{code: "AWS.SimpleQueueService.Unknown"}
        ))
  end
end

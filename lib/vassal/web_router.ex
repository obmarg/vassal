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

  alias Vassal.Errors.SQSError
  alias Vassal.Actions

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
    |> Actions.params_to_action
    |> Actions.valid!
    |> Vassal.QueueManager.do_action
    |> Actions.Response.from_result
  end

  defp handle_errors(conn, %{reason: %SQSError{} = error}) do
    conn
    |> put_resp_header("content-type", "application/xml")
    |> send_resp(400, Actions.Response.from_result(error))
  end
  defp handle_errors(conn, %{reason: unknown}) do
    Logger.error("Unknown Error:")
    Logger.error(inspect unknown)
    conn
    |> put_resp_header("content-type", "application/xml")
    |> send_resp(400, Actions.Response.from_result(
          %SQSError{code: "AWS.SimpleQueueService.Unknown"}
        ))
  end
end

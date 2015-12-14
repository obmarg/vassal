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
  alias Vassal.Queue

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

  get "/:queue_name" do
    conn
    |> put_resp_header("content-type", "application/xml")
    |> send_resp(200, handle_queue_request(queue_name, conn))
  end

  post "/:queue_name" do
    conn
    |> put_resp_header("content-type", "application/xml")
    |> send_resp(200, handle_queue_request(queue_name, conn))
  end

  defp handle_general_request(%{params: params} = conn) do
    if Dict.has_key?(params, "QueueUrl") do
      # This is actually a queue request, lets forward it on...
      queue_name = params["QueueUrl"] |> String.split("/") |> List.last
      handle_queue_request(queue_name, conn)
    else
      # Route non queue-specific requests.
      params
      |> log_action
      |> Actions.params_to_action
      |> Actions.valid!
      |> Vassal.QueueManager.run_action
      |> Actions.Response.from_result
    end
  end

  defp handle_queue_request(queue_name, %{params: params}) do
    params
    |> log_action
    |> Actions.params_to_action(queue_name)
    |> Actions.valid!
    |> Queue.run_action
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

  defp log_action(params) do
    if Mix.env != :test do
      # Don't log when we're testing as it obscures test output.
      Logger.info "Handling #{params["Action"]} action."
    end
    params
  end
end

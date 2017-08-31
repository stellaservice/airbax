defmodule Airbax.Item do
  @moduledoc false

  # This module is responsible for building the payload for an Airbrake error.
  # Refer to https://airbrake.io/docs/#error-notification-v3 for
  # documentation on such payload.

  def draft(environment) do
    %{
      "errors" => [],
      "context" => %{
        "notifier" => notifier(),
        "os" => platform(),
        "hostname" => host(),
        "language" => language(),
        "environment" => environment
      },
      "environment" => %{}, # TODO: send some env variables? which ones?
      "session" => %{},
      "params" => %{}
    }
  end

  def compose(draft, {_level, body, params, session}) do
    draft
    |> Map.put("errors", [body])
    |> Map.put("params", params)
    |> Map.put("session", session)
  end

  def message_to_body(message, meta) do
    %{"message" => Map.put(meta, "body", message)}
  end

  def exception_to_body(kind, value, stacktrace) do
    exception(kind, value)
    |> Map.merge(%{"backtrace" => stacktrace_to_frames(stacktrace)})
  end

  defp exception(:throw, value) do
    %{"type" => "throw", "message" => inspect(value)}
  end

  defp exception(:exit, value) do
    %{"type" => "exit", "message" => Exception.format_exit(value)}
  end

  defp exception(:error, exception) do
    %{"type" => inspect(exception.__struct__), "message" => Exception.message(exception)}
  end

  defp stacktrace_to_frames(stacktrace) do
    Enum.map(stacktrace, &stacktrace_entry_to_frame/1)
  end

  def stacktrace_entry_to_frame({module, fun, arity, location}) when is_integer(arity) do
    %{"function" => Exception.format_mfa(module, fun, arity)}
    |> put_location(location)
  end

  def stacktrace_entry_to_frame({module, fun, arity, location}) when is_list(arity) do
    function = Exception.format_mfa(module, fun, length(arity))
    args = Enum.map(arity, &inspect/1)

    %{"function" => "#{function} [#{args}]"}
    |> put_location(location)
  end

  def stacktrace_entry_to_frame({fun, arity, location}) when is_integer(arity) do
    %{"function" => Exception.format_fa(fun, arity)}
    |> put_location(location)
  end

  def stacktrace_entry_to_frame({fun, arity, location}) when is_list(arity) do
    function = Exception.format_fa(fun, length(arity))
    args = Enum.map(arity, &inspect/1)

    %{"function" => "#{function} [#{args}]"}
    |> put_location(location)
  end

  defp put_location(frame, location) do
    if file = location[:file] do
      frame = Map.put(frame, "file", List.to_string(file))
      if line = location[:line] do
        Map.put(frame, "line", line)
      else
        frame
      end
    else
      Map.put(frame, "file", "unknown")
    end
  end

  defp host() do
    {:ok, host} = :inet.gethostname()
    List.to_string(host)
  end

  defp language() do
    "Elixir v" <> System.version
  end

  defp platform() do
    :erlang.system_info(:system_version)
    |> List.to_string
    |> String.trim
  end

  defp notifier() do
    %{
      "name" => "Airbax",
      "version" => unquote(Mix.Project.config[:version])
      # TODO: url?
    }
  end
end

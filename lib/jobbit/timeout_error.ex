defmodule Jobbit.TimeoutError do
  @moduledoc """
  Exception generated when a Jobbit task times out.

  Captures the `Task` and `timeout` value.
  """
  alias Jobbit.TimeoutError

  @type t :: %TimeoutError{
    task: Task.t(),
    timeout: timeout()
  }

  defexception [:task, :timeout]

  @doc false
  @spec build(Task.t(), timeout()) :: t()
  def build(%Task{} = task, timeout) when is_integer(timeout) do
    %TimeoutError{task: task, timeout: timeout}
  end

  @doc false
  @spec message(t()) :: String.t()
  def message(%TimeoutError{timeout: timeout} = err) do
    """
    Jobbit task timed out after #{render_timeout(err)}.

      task: #{render_task(err)}
      timeout: #{inspect(timeout)}
    """
  end

  defp render_task(%TimeoutError{task: task}) do
    inspect(task)
  end

  defp render_timeout(%TimeoutError{timeout: t}) when is_integer(t), do: "#{t}ms"
  defp render_timeout(%TimeoutError{timeout: t}), do: inspect(t)
end

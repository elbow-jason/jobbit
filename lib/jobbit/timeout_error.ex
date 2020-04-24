defmodule Jobbit.TimeoutError do
  alias Jobbit.TimeoutError

  @type t :: %TimeoutError{
    task: Task.t(),
    timeout: timeout()
  }

  defexception [:task, :timeout]

  @spec build(Task.t(), timeout()) :: t()
  def build(%Task{} = task, timeout) when is_integer(timeout) do
    %TimeoutError{task: task, timeout: timeout}
  end

  @spec message(t()) :: String.t()
  def message(error) do
    """
    Jobbit task timed out after #{render_timeout(error)}ms.
    task: #{render_task(error)}
    """
  end

  defp render_task(%TimeoutError{task: task}) do
    inspect(task)
  end

  defp render_timeout(%TimeoutError{timeout: t}), do: inspect(t)
end

defmodule Jobbit.ExitError do
  @moduledoc """
  Exception generated when the task's process is signaled to exit.

  Captures the `Task` and the `reason` of the exit.
  """
  alias Jobbit.ExitError

  @type reason :: term()

  @type t :: %ExitError{
    task: Task.t(),
    reason: reason,
  }

  defexception [:task, :reason]

  @doc false
  @spec build(Task.t(), reason()) :: t()
  def build(%Task{} = task, reason) do
    %ExitError{
      task: task,
      reason: reason,
    }
  end

  @doc false
  def message(%ExitError{} = error) do
    """
    Jobbit task was signaled to exit.

      task: #{render_task(error)}
      reason: #{render_reason(error)}
    """
  end

  defp render_task(%ExitError{task: task}) do
    inspect(task)
  end

  defp render_reason(%ExitError{reason: reason}) do
    inspect(reason, pretty: true)
  end
end

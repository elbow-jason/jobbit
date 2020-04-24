defmodule Jobbit.TaskError do
  alias Jobbit.TaskError

  @type stack_item :: {atom(), atom(), integer(), Keyword.t()}
  @type exception :: %{__struct__: module(), __exception__: true} | atom()

  @type t :: %TaskError{
    task: Task.t(),
    exception: exception(),
    stacktrace: [stack_item()]
  }

  defexception [:task, :exception, :stacktrace]

  @spec build(Task.t(), exception, [stack_item]) :: t()
  def build(%Task{} = task, exception, stacktrace) when is_list(stacktrace) do
    %TaskError{
      task: task,
      exception: exception,
      stacktrace: stacktrace,
    }
  end

  def message(%TaskError{} = error) do
    """
    Jobbit task encountered an exception.
    task: #{render_task(error)}
    exception: #{render_exception(error)}
    stacktrace: #{render_stacktrace(error)}
    """
  end

  defp render_exception(%TaskError{exception: exception}) do
    inspect(exception)
  end

  defp render_task(%TaskError{task: task}) do
    inspect(task)
  end

  defp render_stacktrace(%TaskError{stacktrace: stacktrace}) do
    inspect(stacktrace, pretty: true)
  end
end

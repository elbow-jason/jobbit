defmodule Jobbit do
  # get the absolute path to via the relative path of this file to the README.
  @readme_path Path.join(__DIR__, "../README.md")

  # ensure the module recompiles if the README changes
  # NOTE: @external_resource requires an absolute path.
  @external_resource @readme_path

  # read the README into the moduledoc
  @moduledoc File.read!(@readme_path)

  alias Jobbit.Configuration
  alias Jobbit.ExitError
  alias Jobbit.TimeoutError
  alias Jobbit.TaskError

  @type supervisor_t :: Task.Supervisor
  @type supervisor :: atom() | pid() | {atom, any} | {:via, atom, any}
  @type args :: list(any)

  @type closure :: (() -> any())
  @type option :: Task.Supervisor.option()
  @type on_start :: Task.Supervisor.on_start()
  @type func_name :: atom()

  @type error :: TimeoutError.t() | TaskError.t() | ExitError.t()
  @type result :: :ok | {:ok, any()} | {:error, any()} | tuple() | {:error, error}

  @enforce_keys [:task]

  @type t :: %Jobbit{
    task: Task.t()
  }

  defstruct [:task]

  @doc """
  The child spec for a Jobbit.

  The `child_spec` for a `Jobbit` task supervisor. This `child_spec`
  forwards the provided `jobbit_opts` to `Jobbit.start_link/1` when
  the `child_spec` is applied as a child by a supervisor.
  """
  @spec child_spec([option]) :: Supervisor.child_spec()
  def child_spec(jobbit_opts \\ []) do
    %{
      id: Jobbit,
      start: {Jobbit, :start_link, [jobbit_opts]},
      type: :supervisor,
      restart: :permanent,
      shutdown: 1_000,
    }
  end

  @doc """
  Starts a Task.Supervisor passing the provided `option` list.

  Example:

    iex> {:ok, pid} = Jobbit.start_link()
    iex> is_pid(pid)
    true

    iex> {:ok, pid} = Jobbit.start_link(name: :jobbit_test_task_sup)
    iex> is_pid(pid)
    true
    iex> Process.whereis(:jobbit_test_task_sup) == pid
    true
  """
  @spec start_link([option]) :: on_start()
  def start_link(opts \\ []), do: Task.Supervisor.start_link(opts)

  @doc """
  Runs the given `closure` as a task on the given `supervisor`.

  The task runs as an unlinked, asynchronous, task process supervised by the
  `supervisor` (default: `Jobbit.DefaultTaskSupervisor`).

  See `Task.Supervisor.async_nolink/3` for `opts` details.
  """
  @spec async(supervisor, closure(), Keyword.t()) :: t()
  def async(supervisor \\ default_supervisor(), closure, opts \\ []) when is_function(closure, 0) do
    supervisor
    |> Task.Supervisor.async_nolink(closure, opts)
    |> build()
  end

  @doc """
  Runs the given `module`, `func`, and `args` as a task on the given `supervisor`.

  The task runs as an unlinked, asynchronous, task process supervised by the
  `supervisor` (default: `Jobbit.DefaultTaskSupervisor`).

  See `Task.Supervisor.async_nolink/3` for `opts` details.
  """
  @spec async_apply(supervisor(), module(), func_name(), args(), opts :: Keyword.t()) :: t()
  def async_apply(supervisor \\ default_supervisor(), module, func, args, opts \\ []) do
    supervisor
    |> Task.Supervisor.async_nolink(module, func, args, opts)
    |> build()
  end

  defguardp is_ok_tuple(t) when is_tuple(t) and elem(t, 0) == :ok
  defguardp is_error_tuple(t) when is_tuple(t) and elem(t, 0) == :error

  @doc """
  Synchronously blocks the caller waiting for the Jobbit task to finish.

  ## Easier than `Task.yield/2`

  When yielding with the Task module it is the caller's responsibility to
  ensure a task does not live beyond it's timeout. The Task documentation
  recommends the following code:

      Task.yield(task, timeout) || Task.shutdown(task)

  With the above code, if the caller to `Task.yield/2` forgets to call
  `Task.shutdown/1` the running task *might* never stop. Additionally, the
  outcome of call above is not very straight forward; there are a multitude
  of return values (If you are curious take a look at the source code of
  `yield/2`).

  In Jobbit, `yield/2` calls both `Task.yield/2` and `Task.shutdown/2` and
  wraps/handles the multitude of result types

  ## Outcomes

  Yielding a Jobbit task with `yield/2` will result in 1 of 4 outcomes:

    - success: The task finished without crashing the task process.
      In the case of success, the return value with be either an ok-tuple
      that the closure/mfa returned, an error-tuple that the closure/mfa
      returned, or `{:ok, returned_value}` where `returned_value` was the
      return value from the closure.

    - exception: An exception occured while the task was running and the task
      process crashed. When a exception occurs during task execution the return
      value is `{:error, TaskError.t()}`. The TaskError itself is an exception
      (it can be raised). Also, TaskError wraps the task's exception and
      stacktrace which can be used to find the cause of the exception or
      reraised if necessary.

    - timeout: The task took too long to complete and was gracefully shut down.
      In the case of a timeout, `yield/2` returns `{:error, TimeoutError.t()}`.
      TimeoutError is an exception (it can be raised) that wraps the `timeout`
      value.

    - exit: The task process was terminated with an exit signal e.g.
    `Process.exit(pid, :kill)`. In the case of a non-exception exit signal,
    `yield/2` returns `{:error, ExitError.t()}`. ExitError

  """
  @spec yield(Jobbit.t(), timeout) :: result()
  def yield(%Jobbit{task: task}, timeout \\ 5_000) do
    result = Task.yield(task, timeout) || Task.shutdown(task)
    handle_result(result, task, timeout)
  end

  @type shutdown :: :brutal_kill | :infinity | non_neg_integer()

  @doc """
  Shuts down a Jobbit task.
  """
  @spec shutdown(t(), shutdown()) :: result()
  def shutdown(%Jobbit{task: task}, shutdown \\ 5_000) do
    case Task.shutdown(task, shutdown) do
      nil -> :ok
      result -> handle_result(result, task, nil)
    end
  end

  @spec default_supervisor :: atom()
  def default_supervisor, do: Configuration.default_supervisor()

  defp build(%Task{} = task), do: %Jobbit{task: task}

  defp handle_result(result, task, timeout) do
    case result do
      {:ok, :ok} ->
        :ok
      {:ok, okay} when is_ok_tuple(okay) ->
        okay
      {:ok, err} when is_error_tuple(err) ->
        err
      okay when is_ok_tuple(okay) ->
        okay
      nil ->
        error = TimeoutError.build(task, timeout)
        {:error, error}
      {:exit, {exception, stacktrace}} ->
        error = TaskError.build(task, exception, stacktrace)
        {:error, error}
      {:exit, signal} when is_atom(signal) ->
        error = ExitError.build(task, signal)
        {:error, error}
    end
  end
end

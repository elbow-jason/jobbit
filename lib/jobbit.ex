defmodule Jobbit do
  @moduledoc __DIR__
    |> Path.join("../README.md")
    |> File.read!()

  alias Jobbit.Configuration
  alias Jobbit.TimeoutError
  alias Jobbit.TaskError

  @type supervisor_t :: Task.Supervisor
  @type supervisor :: atom() | pid() | {atom, any} | {:via, atom, any}
  @type args :: list(any)

  @type closure :: (() -> any())
  @type func_name :: atom()

  @type exit_error :: {:exit, TimeoutError.t() | TaskError.t()}
  @type result :: :ok | {:ok, any()} | {:error, any()} | exit_error()
  @type option :: Task.Supervisor.option()
  @type on_start :: Task.Supervisor.on_start()

  @enforce_keys [:task]

  @type t :: %Jobbit{
    task: Task.t()
  }

  defstruct [:task]

  @doc """
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
  Runs the given `closure` as an unlinked, asynchronous, task process supervised
  by the provided or configured (default: `Jobbit.DefaultTaskSupervisor`)
  `supervisor`.

  See `Task.Supervisor.async_nolink/3` for `opts` details.
  """
  @spec async(supervisor, closure(), Keyword.t()) :: t()
  def async(supervisor \\ default_supervisor(), closure, opts \\ []) when is_function(closure, 0) do
    supervisor
    |> Task.Supervisor.async_nolink(closure, opts)
    |> build()
  end

  @doc """
  Runs the given `module`, `func`, and `args` an unlinked, asynchronous task
  process supervised by the provided or configured (default:
  `Jobbit.DefaultTaskSupervisor`) `supervisor`.

  The `opts` arg is forwarded as-is to `Task.Supervisor.async_nolink/3`.
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
  Synchronously blocks the calling process waiting for the Jobbit task to
  finish successfully, crash, or timeout.

  Similar to `Task.yield/2`, `Jobbit.yield2/` takes a task and a `timeout` in
  milliseconds (default: 5000).

  If the task process crashes or times out the return value is either
  `{:exit, %Jobbit.TaskError{}}` or `{:exit, %Jobbit.TimeoutError{}}`.
  """
  @spec yield(Jobbit.t(), timeout) :: result()
  def yield(%Jobbit{task: task}, timeout \\ 5_000) do
    case Task.yield(task, timeout) || Task.shutdown(task) do
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
    end
  end

  @type shutdown :: :brutal_kill | :infinity | non_neg_integer()

  @doc """
  Shuts down a Jobbit task.
  """
  @spec shutdown(t(), shutdown()) :: :ok | {:exit, any} | {:ok, any}
  def shutdown(%Jobbit{task: task}, shutdown \\ 5_000) do
    case Task.shutdown(task, shutdown) do
      nil -> :ok
      other -> other
    end
  end

  @spec default_supervisor :: atom()
  def default_supervisor, do: Configuration.default_supervisor()

  defp build(%Task{} = task), do: %Jobbit{task: task}
end

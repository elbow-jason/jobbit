defmodule Jobbit.TaskErrorTest do
  use ExUnit.Case

  alias Jobbit.TaskError

  def new_task, do: Task.async(fn -> :timer.sleep(:infinity) end)

  def new_stacktrace do
    [
      {:erlang, :div, [1, 0], []},
      {Kernel, :div, 2, [file: 'lib/kernel.ex', line: 405]},
      {Task.Supervised, :invoke_mfa, 2, [file: 'lib/task/supervised.ex', line: 90]},
      {Task.Supervised, :reply, 5, [file: 'lib/task/supervised.ex', line: 35]},
      {:proc_lib, :init_p_do_apply, 3, [file: 'proc_lib.erl', line: 249]}
    ]
  end

  def new_exception do
    %RuntimeError{message: "Bad thing happened"}
  end

  def new_error(%Task{} = task) do
    %TaskError{
      task: task,
      exception: new_exception(),
      stacktrace: new_stacktrace()
    }
  end

  setup do
    task = new_task()
    error = new_error(task)
    message = TaskError.message(error)
    {:ok, task: task, error: error, message: message}
  end

  test "Jobbit.TaskError struct can be raised (because it's an exception)", %{error: error} do
    assert %TaskError{} = error
    assert_raise(TaskError, fn -> raise error end)
  end

  describe "message" do
    test "has an explanation", %{message: message} do
      assert message =~ "Jobbit task encountered an exception."
    end

    test "shows the task", %{task: task, message: message} do
      %Task{pid: pid, ref: ref, owner: owner} = task
      assert message =~ "pid: " <> inspect(pid)
      assert message =~ "ref: " <> inspect(ref)
      assert message =~ "owner: " <> inspect(owner)
      assert message =~ "%Task{"
    end

    test "shows the exception", %{message: message} do
      assert message =~ ~s(exception: %RuntimeError{message: "Bad thing happened"})
    end

    test "shows the stacktrace", %{message: message, error: error} do
      %TaskError{stacktrace: stacktrace} = error
      assert message =~ "stacktrace: " <> inspect(stacktrace, pretty: true)
    end
  end

  describe "build/3" do
    test "accepts Elixir exception structs as the `exception`", %{task: task} do
      exception = %RuntimeError{message: "It went waaaaay bad."}
      stacktrace = new_stacktrace()
      assert %TaskError{} = TaskError.build(task, exception, stacktrace)
    end

    test "can handle :badarith as the `exception` (bug regression test from 23 APR 2020)" , %{task: task} do
      exception = :badarith
      stacktrace = new_stacktrace()
      assert %TaskError{} = TaskError.build(task, exception, stacktrace)
    end
  end
end

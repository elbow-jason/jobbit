defmodule JobbitTest do
  use ExUnit.Case, async: true

  alias Jobbit.Configuration
  alias Jobbit.TaskError
  alias Jobbit.TimeoutError
  alias Jobbit.ExitError

  @moduletag capture_log: true

  doctest Jobbit

  describe "start_link/0" do
    test "starts a Task.Supervisor" do
      assert {:ok, pid} = Jobbit.start_link()
      assert is_pid(pid) == true
      assert Process.alive?(pid) == true
    end
  end

  describe "start_link/1" do
    test "can start a supervisor with an empty options list" do
      assert {:ok, pid} = Jobbit.start_link([])
      assert is_pid(pid) == true
      assert Process.alive?(pid) == true
    end

    test "can start a named supervisor" do
      name = :jobbit_test_start_link
      assert {:ok, pid} = Jobbit.start_link(name: name)
      assert is_pid(pid) == true
      assert Process.whereis(name) == pid
    end
  end

  describe "child_spec/0" do
    test "works" do
      assert Jobbit.child_spec() == %{
        id: Jobbit,
        start: {Jobbit, :start_link, [[]]},
        restart: :permanent,
        shutdown: 1000,
        type: :supervisor
      }
    end
  end

  describe "child_spec/1" do
    test "works" do
      assert Jobbit.child_spec(name: :supsupsup) == %{
        id: Jobbit,
        start: {Jobbit, :start_link, [[name: :supsupsup]]},
        restart: :permanent,
        shutdown: 1000,
        type: :supervisor
      }
    end

    setup :start_testing_supervisor

    test "returns a Task.Supervisor-useable child_spec", %{sup: sup} do
      child_spec = Jobbit.child_spec(name: :supsupsup)
      assert {:ok, pid} = Task.Supervisor.start_child(sup, child_spec)
      assert is_pid(pid) == true
    end
  end

  describe "async/1" do
    test "runs a closure" do
      this_test = self()

      assert {:ok, :the_closure_ran} =
        fn -> send(this_test, :the_closure_ran) end
        |> Jobbit.async()
        |> Jobbit.yield(100)

      assert_receive(:the_closure_ran, 100)
    end

    test "returns a Jobbit struct" do
      assert %Jobbit{} = Jobbit.async(fn -> :ok end)
    end

    test "runs on the default supervisor" do
      assert %Jobbit{
        task: %Task{pid: pid}
      } = Jobbit.async(fn -> :timer.sleep(:infinity) end)

      children =
        Configuration.default_supervisor()
        |> Process.whereis()
        |> case do
          sup_pid ->
            assert is_pid(sup_pid) == true
            assert Process.alive?(sup_pid) == true
            sup_pid
        end
        |> Task.Supervisor.children()

      assert pid in children
    end

    test "does not crash the calling process when the task crashes" do
      message = "this should not crash the calling process"
      assert %Jobbit{task: %Task{pid: pid}} = Jobbit.async(fn -> raise message end)
      assert_receive({:DOWN, _, _, ^pid, {%RuntimeError{message: ^message}, _}}, 50)
    end

    setup :start_testing_supervisor
    test "does not crash the calling process when the task process exits", %{sup: sup} do
      assert %Jobbit{task: %Task{pid: pid}} = Jobbit.async(sup, fn -> :timer.sleep(52) end)
      Process.exit(pid, :kaboom)
      assert_receive({:DOWN, _, _, ^pid, :kaboom}, 50)
    end
  end

  describe "async/2" do
    setup :start_testing_supervisor
    test "starts a closure on the given supervisor", %{sup: sup} do
      %Jobbit{task: %Task{pid: pid}} = Jobbit.async(sup, fn -> :timer.sleep(1000) end)
      assert is_pid(pid) == true
      assert pid in Task.Supervisor.children(sup)

      # and sup is not the default supervisor
      assert_not_default_supervisor(sup)
    end
  end

  describe "async/3" do
    setup :start_testing_supervisor
    test "starts a closure on the given supervisor", %{sup: sup} do
      closure = fn -> :timer.sleep(1000) end
      %Jobbit{task: %Task{pid: pid}} = Jobbit.async(sup, closure, [])
      assert is_pid(pid) == true
      assert pid in Task.Supervisor.children(sup)

      # and sup is not the default supervisor
      assert_not_default_supervisor(sup)
    end
  end

  describe "yield/2" do
    setup :start_testing_supervisor
    test "does not crash the caller when task process is signaled to exit (bug regression test from 27 AUG 2020)", %{sup: sup} do
      assert %Jobbit{task: %Task{pid: pid}} = task = Jobbit.async(sup, fn -> :timer.sleep(1000) end)
      true = Process.exit(pid, :some_exit_signal)
      assert {:error, %ExitError{reason: :some_exit_signal}} = Jobbit.yield(task, 30)
    end

    test "does not crash the caller when yielding a :badarith task exception (bug regression test from 23 APR 2020)" do
      job = Jobbit.async_apply(Kernel, :div, [1, 0])
      assert {:error, %TaskError{}} = Jobbit.yield(job, 30)
    end

    test "returns {:error, %TaskError{}} when the task crashes", ctx do
      assert {:error, %TaskError{}} =
        fn -> raise "this raise intentional and is meant to crash the task of #{inspect(ctx.test)}" end
        |> Jobbit.async()
        |> Jobbit.yield(30)
    end

    test "returns {:error, %TimeoutError{}} when the task takes too long" do
      assert {:error, %TimeoutError{timeout: 1}} =
        fn -> :timer.sleep(40) end
        |> Jobbit.async()
        |> Jobbit.yield(1)
    end

    test "a task is not alive after it finishes successfully" do
      assert %Jobbit{task: %Task{pid: pid}} = job = Jobbit.async(fn -> :yup end)
      assert {:ok, :yup} = Jobbit.yield(job, 100)
      assert Process.alive?(pid) == false
    end

    test "a task is not alive after it crashes" do
      assert %Jobbit{task: %Task{pid: pid}} = job = Jobbit.async(fn -> raise "boom" end)
      assert {:error, %TaskError{}} = Jobbit.yield(job, 100)
      assert Process.alive?(pid) == false
    end

    test "a task is not alive after it times out" do
      assert %Jobbit{task: %Task{pid: pid}} = job = Jobbit.async(fn -> :timer.sleep(1000) end)
      assert {:error, %TimeoutError{}} = Jobbit.yield(job, 1)
      assert Process.alive?(pid) == false
    end

    test "a task is not alive after it is signaled to exit" do
      assert %Jobbit{task: %Task{pid: pid}} = job = Jobbit.async(fn -> :timer.sleep(1000) end)
      true = Process.exit(pid, :kaboom)
      assert {:error, %ExitError{}} = Jobbit.yield(job, 1)
      assert Process.alive?(pid) == false
    end

    test "a task that returns :ok yields :ok" do
      assert :ok =
        fn -> :ok end
        |> Jobbit.async()
        |> Jobbit.yield(25)
    end

    test "a task that returns {:error, reason} yields {:error, reason}" do
      assert {:error, "it failed"} =
        fn -> {:error, "it failed"} end
        |> Jobbit.async()
        |> Jobbit.yield(25)
    end

    test "a task that returns an ok-tuple yields the same ok-tuple" do
      assert {:ok, 2} =
        fn -> {:ok, 1 + 1} end
        |> Jobbit.async()
        |> Jobbit.yield(25)

      assert {:ok, 2, 4} =
        fn -> {:ok, 1 + 1, 2 * 2} end
        |> Jobbit.async()
        |> Jobbit.yield(25)
    end

    test "a task that returns a value that is not :ok, an ok-tuple, or an error-tuple" do
      assert {:ok, 2} =
        fn -> {:ok, 1 + 1} end
        |> Jobbit.async()
        |> Jobbit.yield(25)
    end
  end

  def assert_not_default_supervisor(sup) do
    default_sup_name = Configuration.default_supervisor()
    default_sup_pid = Process.whereis(default_sup_name)
    assert is_pid(default_sup_pid) == true
    assert sup != default_sup_pid
  end

  def start_testing_supervisor do
    assert {:ok, sup} = Task.Supervisor.start_link()
    sup
  end

  def start_testing_supervisor(_ctx) do
    {:ok, sup: start_testing_supervisor()}
  end
end

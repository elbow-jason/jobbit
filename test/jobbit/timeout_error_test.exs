defmodule Jobbit.TimeoutErrorTest do
  use ExUnit.Case

  alias Jobbit.TimeoutError

  def new_task, do: Task.async(fn -> :timer.sleep(:infinity) end)

  def new_error(task) do
    %TimeoutError{task: task, timeout: 5_000}
  end

  test "Jobbit.TimeoutError struct can be raised (because it's an exception)", %{error: error} do
    assert %TimeoutError{} = error
    assert_raise(TimeoutError, fn -> raise error end)
  end

  setup do
    task = new_task()
    error = new_error(task)
    message = TimeoutError.message(error)
    {:ok, task: task, error: error, message: message}
  end

  describe "message" do
    test "is formatted correctly", %{message: message} do
      assert message =~ "Jobbit task timed out after 5000ms."
    end
  end

end

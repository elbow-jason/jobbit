defmodule JobbitTest do
  use ExUnit.Case
  doctest Jobbit

  test "async returns a result when the task does not crash" do
    assert Jobbit.async(fn -> 1 + 1 end) |> Jobbit.await == {:ok, 2}
  end

  test "await returns and error tuple on timeout" do
    assert Jobbit.async(fn -> :timer.sleep(1000) end) |> Jobbit.await(1) == {:error, :timeout}
  end

  # despite red text appearing this test passes
  test "async/await does not crash parent process when an exception occurs" do
    error_message = "This is an intentional exception for testing purposes"
    result = Jobbit.async(fn -> raise error_message end) |> Jobbit.await
    assert result == {:error, %RuntimeError{message: error_message}}
  end

  test "async/await works for multiple jobs and keeps them in order" do
    result = 1..5
      |> Enum.map(fn num ->
        Jobbit.async(fn ->
          time = (33 * num)
          :timer.sleep(300 - time)
          time
        end)
      end)
      |> Enum.map(fn job -> Jobbit.await(job) end)
    assert result == [ok: 33, ok: 66, ok: 99, ok: 132, ok: 165]
    # make sure there are no lingering messages...
    # if so we may be leaking mem...
    thing = receive do
      x -> x
    after
      1 ->
        nil
    end
    assert thing == nil
  end

end

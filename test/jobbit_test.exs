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
  test "async await does not crash parent process when an exception occurs" do
    error_message = "This is an intentional exception for testing purposes"
    result = Jobbit.async(fn -> raise error_message end) |> Jobbit.await
    assert result |> is_tuple
    assert result |> elem(0) == :error
  end

end

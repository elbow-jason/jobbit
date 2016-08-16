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
    {:error, reason} = Jobbit.async(fn -> 1/0 end) |> Jobbit.await
    assert reason |> elem(0) == :badarith
  end

end

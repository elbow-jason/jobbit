defmodule Jobbit do
  require Logger

  defstruct [
    pid: nil,
    ref: nil,
    owner: nil,
  ]

  def async(fun) do
    async(:erlang, :apply, [fun, []])
  end
  def async(mod, func, args) do
    owner = self
    pid = spawn(fn -> run(owner, fn -> apply(mod, func, args) end) end)
    ref = Process.monitor(pid)
    send(pid, {owner, ref})
    %Jobbit{
      pid: pid,
      ref: ref,
      owner: self,
    }
  end

  def await(task, timeout \\ 5000)
  def await(%Jobbit{owner: owner}, _) when owner != self do
    raise "Invalid Jobbit owner"
  end
  def await(%Jobbit{ref: ref}, timeout) do
    receive do
      {^ref, reply} ->
        Process.demonitor(ref, [:flush])
        {:ok, reply}
      {:DOWN, ^ref, _, _, reason} ->
        {:error, reason}
      x ->
        Process.demonitor(ref, [:flush])
        {:error, x}
    after
      timeout ->
        Process.demonitor(ref, [:flush])
        {:error, :timeout}
    end
  end

  defp run(owner, func, timeout \\ 500) when owner |> is_pid and func |> is_function do
    receive do
      {^owner, ref} -> send owner, {ref, func.()}
      err -> invalid_owner_error(err, owner)
    after
      timeout ->
        send owner, {:error, :worker_timeout}
    end
  end

  defp invalid_owner_error(err, owner) do
    Logger.error("Jobbit - Invalid Owner: Expected {#{inspect owner}, ref}. Got #{inspect err}")
    exit(:shutdown)
  end

end

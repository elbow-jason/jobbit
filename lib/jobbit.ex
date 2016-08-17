defmodule Jobbit do
  require Logger

  defstruct [
    pid: nil,
    ref: nil,
    owner: nil,
  ]

  def async(func) do
    async(:erlang, :apply, [func, []])
  end
  def async(mod, func_atom, args) do
    owner = self
    pid = spawn(fn -> run(owner, make_func(mod, func_atom, args)) end)
    ref = Process.monitor(pid)
    send(pid, {owner, ref})
    %Jobbit{
      pid: pid,
      ref: ref,
      owner: self,
    }
  end

  def await(job, timeout \\ 5000, seen \\ [])
  def await(%Jobbit{owner: owner}, _, _) when owner != self do
    raise "Invalid Jobbit owner"
  end
  def await(%Jobbit{ref: ref} = job, timeout, seen) do
    if Enum.member?(seen, ref) do
      {:error, :internal_error}
    else
      receive do
        {^ref, reply} ->
          Process.demonitor(ref, [:flush])
          {:ok, reply}
        {:DOWN, ^ref, _, _, {reason, _details}} ->
          {:error, reason}
        {:DOWN, ^ref, _, _, :normal} ->
          await(job, timeout, seen)
        {:DOWN, ^ref, _, _, reason} ->
          {:error, reason}
        {other_ref, reply} when other_ref |> is_reference ->
          send self, {other_ref, reply}
          await(job, timeout, [other_ref|seen])
        {:DOWN, other_ref, some_atom, pid, reason} when other_ref |> is_reference ->
          send self, {:DOWN, other_ref, some_atom, pid, reason}
          await(job, timeout, [other_ref|seen])
        x ->
          {:error, :internal_error}
      after
        timeout ->
          Process.demonitor(ref, [:flush])
          {:error, :timeout}
      end
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

  defp make_func(mod, func_atom, args) do
    fn -> apply(mod, func_atom, args) end
  end

  defp invalid_owner_error(err, master) do
    Logger.error("Jobbit - Invalid :owner\n\tExpected {#{inspect master}, ref}\n\tGot #{inspect err}")
    exit(:shutdown)
  end

end

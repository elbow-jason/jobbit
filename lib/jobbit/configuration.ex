defmodule Jobbit.Configuration do
  @moduledoc false
  @default_sup Jobbit.DefaultTaskSupervisor

  def default_supervisor, do: get(:default_supervisor, @default_sup)

  def default_supervisor_opts, do: get(:default_supervisor_opts, [])

  def start_jobbit?, do: get(:start_jobbit?, true)

  defp get(key, default), do: Application.get_env(:jobbit, key, default)
end

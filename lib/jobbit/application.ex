defmodule Jobbit.Application do
  use Application

  alias Jobbit.Configuration

  def start(_type, _args) do
    case jobbit_children() do
      [] -> :ignore
      children -> Supervisor.start_link(children, strategy: :one_for_one)
    end
  end

  defp jobbit_children() do
    if Configuration.start_jobbit?() do
      name = Configuration.default_supervisor()
      extra_opts = Configuration.default_supervisor_opts()
      [{Jobbit, [{:name, name} | extra_opts]}]
    else
      []
    end
  end


end

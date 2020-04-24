
use Mix.Config

config :jobbit,
  start_jobbit?: true,
  default_supervisor: Jobbit.DefaultTaskSupervisor,
  default_supervisor_opts: []

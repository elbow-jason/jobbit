# Jobbit

Run risky tasks asynchronously or synchronously without endangering the
calling process.

`Jobbit` is a thin, mildly opinionated wrapper for Elixir's `Task` and
`Task.Supervisor` modules and functionality.

`Task` and `Task.Supervisor` provide an easy-to-use, extensible, and
dependable interface for running one or many supervised or unsupervised
asynchronous tasks. If you want to "harness the power of OTP" you should
investigate those two modules and what can be achieved with their use.

## Installation

Add `jobbit` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:jobbit, "~> 0.4.0"},
  ]
end
```

## Usage / Running Tasks

Tasks in `Jobbit` can be run with a closure:

```elixir
Jobbit.async(fn -> :ok end)
=> %Jobbit{}
```

Or with a `module`, `func`, and `args` (similar to `apply/3`):

```elixir
Jobbit.async_apply(Kernel, :div, [1, 0])
=> %Jobbit{}
```

## FAQ

#### How is `Jobbit` like `Task`?

  + Both are used to perform asynchronous tasks.

  + Both have `yield/2` which waits for results for a certain
    amount of time (`timeout`), but does not raise upon timeout.

#### How is `Jobbit` like `Task.Supervisor`?

  + Both are used to perform asynchronous tasks.

  + Both can start caller-unlink, supervised tasks.

  + Both require a `Task.Supervisor` to be running

    + Note: `Jobbit` itself can be used as a child_spec callback module
      instead of `Task.Supervisor`.

    + Note: `Jobbit` starts its own task supervisor by default at application
      startup.

#### How is `Jobbit` different than `Task`?

  + `Jobbit` never links to the calling process. All the risk is move to
    the task process.

  + `Jobbit` only provides one function to (idiomatically) synchronize on a
    tasks result (via `yield/2`). `Task` has also has `yield/2` which is
    similar, but also provides `await/2` which will raise if the task times
    out; `yeild/2` will not raise.

  + `Jobbit` homogenizes results of tasks. With `Task` yielding can return
    `{:ok, :ok}`. `Jobbit` homogenizes `{:ok, :ok}` into `:ok`. This way is
    much less boilerplate.

#### How is `Jobbit` different than `Task.Supervisor`?

  + `Jobbit` provides a default supervisor via its application tree.

  + `Jobbit` is less generalized, but easier to out-of-the-box.

  + `Jobbit` has fewer functions, and a more focused scope. `Jobbit` *ONLY*
    runs asynchronous, unlinked tasks.

## Task Supervision

With `Jobbit`, tasks are run on a `Jobbit` task supervisor and the
`Jobbit.Application` starts a default task supervisor (default:
`Jobbit.DefaultTaskSupervisor`) at application startup.

`Jobbit` implements `child_spec/1` and can, therefore, be used as
a child's callback module for a supervisor

A supervisor can be added to a supervision tree using like so:

```elixir
# in `MyApp.SomeSupervisor` or in `MyApp.Application`...
# Note: it's a good idea to `:name` your task supervisor
# (because you need to be able to address it)...

children = [
  {Jobbit, name: MyApp.MyBusinessDomainTaskSupervisor}
]
```

A custom `Jobbit` task supervisor can also be started directly via
`Jobbit.start_link/1`.

```elixir
Jobbit.start_link(name: :some_task_sup)
=> {:ok, #PID<0.109.0>}
```

Or `Jobbit.start_link/0`:

```elixir
Jobbit.start_link()
=> {:ok, #PID<0.110.0>}
```

## Configuration

Jobbit can be configured via `config/*.exs` files.

By default, the `:jobbit` OTP app will start a default
task supervisor called `Jobbit.DefaultTaskSupervisor`.

The default task supervisor can be configured via the `:default_supervisor`
config value.

Additionally, the entire `:jobbit` application can instructed not
to start by flagging `:start_jobbit?` with a falsey (`nil` or `false`)
value.

Note: `Jobbit.async/1` and `Jobbit.async_apply/3` rely on the default supervisor
to be running when they are called. If `start_jobbit?: false` is set in the config
and the `:default_supervisor` is not set to a running task supervisor these
functions will not work.

An example of configuring `:jobbit`:

```elixir
config :jobbit,
  start_jobbit?: true,
  default_supervisor: Jobbit.DefaultTaskSupervisor,
  default_supervisor_opts: []
```



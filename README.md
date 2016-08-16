# Jobbit

A small Elixir module allows execution of tasks without crashing the parent
process

## Usage

Usage is just like `Task.async` and `Task.await` except `Jobbit` will not crash
the parent process when an error occurs.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add `jobbit` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:jobbit, "~> 0.1.0"}]
    end
    ```

  2. Ensure `jobbit` is started before your application:

    ```elixir
    def application do
      [applications: [:jobbit]]
    end
    ```

## Todos

+ type_specs

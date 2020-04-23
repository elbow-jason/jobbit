defmodule Jobbit.Mixfile do
  use Mix.Project

  def project do
    [
      app: :jobbit,
      version: "0.4.0",
      elixir: "~> 1.3",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      description: description(),
      package: package(),
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end

  defp elixirc_paths(:prod), do: ["lib"]
  defp elixirc_paths(_), do: ["lib", "test/support"]

  defp description do
    """
    Execute tasks without crashing the parent process.
    """
  end

  defp package do
    [
      name: :jobbit,
      files: ["lib", "mix.exs", "README*", "LICENSE*", "test"],
      maintainers: ["Jason Goldberger"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/elbow-jason/jobbit"},
    ]
  end
end

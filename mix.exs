defmodule Jobbit.Mixfile do
  use Mix.Project

  def project do
    [
      app: :jobbit,
      version: "0.1.0",
      elixir: "~> 1.3",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps,
    ]
  end

  defp apps do
    [
      :logger
    ]
  end
  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [
      applications: apps,
    ]
  end

  defp deps do
    []
  end

  defp description do
    """
    A few sentences (a paragraph) describing the project.
    """
  end

  defp package do
    [# These are the default files included in the package
     name: :jobbit,
     files: ["lib", "priv", "mix.exs", "README*", "readme*", "LICENSE*", "license*"],
     maintainers: ["Eric Meadows-Jönsson", "José Valim"],
     licenses: ["Apache 2.0"],
     links: %{"GitHub" => "https://github.com/ericmj/postgrex",
              "Docs" => "http://ericmj.github.io/postgrex/"}]
  end
end

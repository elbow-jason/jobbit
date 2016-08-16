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
end

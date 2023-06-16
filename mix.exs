defmodule ProxyEnv.MixProject do
  use Mix.Project

  def project do
    [
      app: :proxy_env,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:tesla, "~> 1.0"},
      {:hackney, "~> 1.6", only: :test},
      {:mint, "~> 1.0", only: :test},
      {:castore, "~> 1.0", only: :test}
    ]
  end
end

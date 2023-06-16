defmodule ProxyEnv.MixProject do
  use Mix.Project

  def project do
    [
      app: :proxy_env,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      package: package(),
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp package do
    [
      name: "proxy_env",
      description:
        "A tesla middleware, read environment variable and set up proxying for adapter.",
      files: ["lib", "mix.exs", "README.md"],
      maintainers: ["feng19"],
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/feng19/proxy_env"}
    ]
  end

  defp deps do
    [
      {:tesla, "~> 1.0"},
      {:hackney, "~> 1.6", only: :test},
      {:mint, "~> 1.0", only: :test},
      {:castore, "~> 1.0", only: :test},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end
end

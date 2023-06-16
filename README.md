# ProxyEnv

**A tesla middleware, read environment variable and set up proxying for adapter.**

## Installation

The package can be installed by adding `proxy_env` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:proxy_env, "~> 0.1"}
  ]
end
```

## Usage

```
defmodule MyClient do
  use Tesla
  plug ProxyEnv
end
```


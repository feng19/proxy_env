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

Supported adapters: `httpc` | `mint` | `hackney`.

## Usage with Finch

Finch configures proxies when the connection pool is started, not per request, so the
`ProxyEnv` middleware can't be used with `Tesla.Adapter.Finch`
(it returns `{:error, {ProxyEnv, :unknown_adapter}}`).

Instead, use `ProxyEnv.http_proxy/0` / `ProxyEnv.https_proxy/0` to build the pool's `conn_opts`
when starting Finch. Both return `{proxy_uri | nil, no_proxy_list, auth | nil}`,
where `auth` is `{user, pass}` or `nil`.

```elixir
defmodule MyApp.FinchProxy do
  def conn_opts({nil, _no_proxy, _auth}), do: []

  def conn_opts({%URI{scheme: scheme, host: host, port: port}, _no_proxy, auth}) do
    opts = [proxy: {String.to_existing_atom(scheme), host, port, []}]

    case auth do
      nil ->
        opts

      {user, pass} ->
        value = "Basic " <> Base.encode64("#{user}:#{pass}")
        Keyword.put(opts, :proxy_headers, [{"proxy-authorization", value}])
    end
  end
end

# in your supervision tree
children = [
  {Finch,
   name: MyFinch,
   pools: %{
     # requests to https:// hosts use HTTPS_PROXY
     :default => [conn_opts: MyApp.FinchProxy.conn_opts(ProxyEnv.https_proxy())],
     # requests to http:// hosts use HTTP_PROXY
     "http://example.com" => [conn_opts: MyApp.FinchProxy.conn_opts(ProxyEnv.http_proxy())]
   }}
]
```

Then use Finch as the Tesla adapter as usual:

```elixir
defmodule MyClient do
  use Tesla
  adapter Tesla.Adapter.Finch, name: MyFinch
end
```

Notes:

- The proxy applies to the whole pool, so `NO_PROXY` is **not** applied automatically.
  For hosts that should bypass the proxy, add a separate pool entry for that host
  (e.g. `"https://internal.example.com" => [conn_opts: []]`), using the list returned as
  the second element of `ProxyEnv.https_proxy/0` as a reference.
- Finch pools are keyed by scheme/host/port, so add one pool entry per `http://` host
  that should go through `HTTP_PROXY`.

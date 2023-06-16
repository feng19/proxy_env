defmodule ProxyEnv do
  @moduledoc """
  A tesla middleware, read environment variable and set up proxying for adapter.
  Supported adapter: httpc | mint | hackney

  ### Example usage (auto)
  ```
  defmodule MyClient do
    use Tesla
    plug #{inspect(__MODULE__)}
  end
  ```

  ### Example usage (custom)
  ```
  defmodule MyClient do
    use Tesla
    plug #{inspect(__MODULE__)}, :httpc # :httpc | :mint | :hackney
  end
  ```
  """

  @behaviour Tesla.Middleware

  @impl true
  def call(env, next, :httpc) do
    {http_auth, https_auth} =
      if :persistent_term.get({__MODULE__, :httpc_setup}, false) do
        {_, _, _, http_auth, https_auth} = proxy_env()
        {http_auth, https_auth}
      else
        {http_proxy, https_proxy, no_proxy, http_auth, https_auth} = proxy_env()
        no_proxy = Enum.map(no_proxy, &String.to_charlist/1)
        setup_proxy_for_httpc(:http, http_proxy, no_proxy)
        setup_proxy_for_httpc(:https, https_proxy, no_proxy)
        :persistent_term.put({__MODULE__, :httpc_setup}, true)
        {http_auth, https_auth}
      end

    case URI.parse(env.url) do
      %URI{scheme: "http"} -> http_auth
      %URI{scheme: "https"} -> https_auth
    end
    |> case do
      nil ->
        Tesla.run(env, next)

      proxy_auth ->
        adapter_opts = [proxy_auth: String.to_charlist(proxy_auth)]
        env |> update_adapter_opts(adapter_opts) |> Tesla.run(next)
    end
  end

  def call(env, next, :mint) do
    {http_proxy, https_proxy, no_proxy, _, _} = proxy_env()

    case uri = URI.parse(env.url) do
      %URI{scheme: "http"} -> check_no_proxy(http_proxy, uri, no_proxy)
      %URI{scheme: "https"} -> check_no_proxy(https_proxy, uri, no_proxy)
    end
    |> case do
      nil ->
        Tesla.run(env, next)

      %URI{scheme: scheme, host: proxy_address, port: proxy_port, userinfo: nil} ->
        proxy = {String.to_existing_atom(scheme), proxy_address, proxy_port, []}
        adapter_opts = [proxy: proxy]
        env |> update_adapter_opts(adapter_opts) |> Tesla.run(next)

      %URI{scheme: scheme, host: proxy_address, port: proxy_port, userinfo: proxy_auth} ->
        proxy = {String.to_existing_atom(scheme), proxy_address, proxy_port, []}
        proxy_headers = [{"Proxy-Authorization", "Basic #{Base.encode64(proxy_auth)}"}]
        adapter_opts = [proxy: proxy, proxy_headers: proxy_headers]
        env |> update_adapter_opts(adapter_opts) |> Tesla.run(next)
    end
  end

  def call(env, next, :hackney) do
    {http_proxy, https_proxy, no_proxy, http_auth, https_auth} = proxy_env()

    case uri = URI.parse(env.url) do
      %URI{scheme: "http"} -> {check_no_proxy(http_proxy, uri, no_proxy), http_auth}
      %URI{scheme: "https"} -> {check_no_proxy(https_proxy, uri, no_proxy), https_auth}
    end
    |> case do
      {nil, _} ->
        Tesla.run(env, next)

      {proxy, nil} ->
        {{m, f, [opts]}, next} = List.pop_at(next, -1)
        adapter_opts = Keyword.merge([proxy: URI.to_string(proxy)], opts)
        next = List.insert_at(next, -1, {m, f, [adapter_opts]})
        Tesla.run(env, next)

      {proxy, proxy_auth} ->
        {{m, f, [opts]}, next} = List.pop_at(next, -1)
        adapter_opts = Keyword.merge([proxy: URI.to_string(proxy), proxy_auth: proxy_auth], opts)
        next = List.insert_at(next, -1, {m, f, [adapter_opts]})
        Tesla.run(env, next)
    end
  end

  def call(env, next, _opts) do
    case List.last(next) do
      {Tesla.Adapter.Httpc, _, _} -> call(env, next, :httpc)
      {Tesla.Adapter.Mint, _, _} -> call(env, next, :mint)
      {Tesla.Adapter.Hackney, _, _} -> call(env, next, :hackney)
      _adapter -> {:error, {__MODULE__, :unknown_adapter}}
    end
  end

  def reload do
    :persistent_term.erase({__MODULE__, :proxy_env})
    proxy_env()
  end

  defp proxy_env do
    if proxy_env = :persistent_term.get({__MODULE__, :proxy_env}, nil) do
      proxy_env
    else
      http_proxy =
        case System.get_env("HTTP_PROXY") || System.get_env("http_proxy") do
          nil -> nil
          "" -> nil
          proxy -> URI.parse(proxy)
        end

      https_proxy =
        case System.get_env("HTTPS_PROXY") || System.get_env("https_proxy") do
          nil -> nil
          "" -> nil
          proxy -> URI.parse(proxy)
        end

      no_proxy = (System.get_env("NO_PROXY") || System.get_env("no_proxy")) |> no_proxy_list()

      proxy_env =
        {http_proxy, https_proxy, no_proxy, proxy_auth(http_proxy), proxy_auth(https_proxy)}

      :persistent_term.put({__MODULE__, :proxy_env}, proxy_env)
      proxy_env
    end
  end

  defp no_proxy_list(nil), do: []
  defp no_proxy_list(no_proxy), do: String.split(no_proxy, ",")

  defp setup_proxy_for_httpc(_scheme, nil, _no_proxy), do: :ignore

  defp setup_proxy_for_httpc(scheme, uri, no_proxy) do
    if uri.host && uri.port do
      host = String.to_charlist(uri.host)

      proxy_scheme =
        case scheme do
          :http -> :proxy
          :https -> :https_proxy
        end

      :httpc.set_options([{proxy_scheme, {{host, uri.port}, no_proxy}}])
    end
  end

  defp proxy_auth(nil), do: nil
  defp proxy_auth(%URI{userinfo: nil}), do: nil

  defp proxy_auth(%URI{userinfo: auth}) do
    destructure [user, pass], String.split(auth, ":", parts: 2)
    {user, pass || ""}
  end

  defp check_no_proxy(nil, _, _), do: nil

  defp check_no_proxy(proxy, %URI{host: request_host}, no_proxy_list) do
    if Enum.any?(no_proxy_list, &matches_no_proxy_value?(request_host, &1)) do
      nil
    else
      proxy
    end
  end

  defp matches_no_proxy_value?(request_host, no_proxy_value) do
    cond do
      no_proxy_value == "" -> false
      String.starts_with?(no_proxy_value, ".") -> String.ends_with?(request_host, no_proxy_value)
      String.contains?(no_proxy_value, "*") -> matches_wildcard?(request_host, no_proxy_value)
      true -> request_host == no_proxy_value
    end
  end

  defp matches_wildcard?(request_host, wildcard_domain) do
    Regex.escape(wildcard_domain)
    |> String.replace("\\*", ".*")
    |> Regex.compile!()
    |> Regex.match?(request_host)
  end

  defp update_adapter_opts(env, adapter_opts) do
    Map.update(
      env,
      :opts,
      [adapter: adapter_opts],
      &Keyword.update(&1, :adapter, adapter_opts, fn opts ->
        Keyword.merge(adapter_opts, opts)
      end)
    )
  end
end

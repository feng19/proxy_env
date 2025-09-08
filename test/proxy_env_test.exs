defmodule ProxyEnvTest do
  use ExUnit.Case

  @test_url "https://www.youtube.com"

  test "httpc" do
    client = Tesla.client([{ProxyEnv, :httpc}])
    assert {:ok, %{status: 200}} = Tesla.get(client, @test_url)
  end

  test "mint" do
    client = Tesla.client([{ProxyEnv, :mint}], Tesla.Adapter.Mint)
    assert {:ok, %{status: 200}} = Tesla.get(client, @test_url)
  end

  test "hackney" do
    client = Tesla.client([{ProxyEnv, :hackney}], Tesla.Adapter.Hackney)
    assert {:ok, %{status: 200}} = Tesla.get(client, @test_url)
  end

  test "finch" do
    {%{host: host, port: port}, _, _} = ProxyEnv.http_proxy()
    opts = [conn_opts: [proxy: {:http, host, port, []}]]
    {:ok, _} = Finch.start_link(name: Test.Finch, pools: %{default: opts})
    client = Tesla.client([], {Tesla.Adapter.Finch, name: Test.Finch})
    assert {:ok, %{status: 200}} = Tesla.get(client, @test_url)
  end
end

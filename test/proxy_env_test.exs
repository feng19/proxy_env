defmodule ProxyEnvTest do
  use ExUnit.Case

  @test_url "https://www.google.com"

  defmodule Httpc do
    use Tesla
    plug ProxyEnv
  end

  test "httpc" do
    assert {:ok, %{status: 200}} = Httpc.get(@test_url)
  end

  defmodule Mint do
    use Tesla
    adapter Tesla.Adapter.Mint
    plug ProxyEnv, :mint
  end

  test "mint" do
    assert {:ok, %{status: 200}} = Mint.get(@test_url)
  end

  defmodule Hackney do
    use Tesla
    adapter Tesla.Adapter.Hackney
    plug ProxyEnv, :hackney
  end

  test "hackney" do
    assert {:ok, %{status: 200}} = Hackney.get(@test_url)
  end
end

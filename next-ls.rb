class NextLs < Formula
  desc "Language server for Elixir that just works"
  homepage "https://www.elixir-tools.dev/next-ls"
  url "https://github.com/elixir-tools/next-ls/archive/refs/tags/v0.21.4.tar.gz"
  sha256 "071c761453258612147b6c567e3518caf6967470670f0d3df7ba97cb4bce7570"
  license "MIT"

  bottle do
    root_url "https://github.com/elixir-tools/homebrew-tap/releases/download/next-ls-0.21.3"
    sha256 cellar: :any_skip_relocation, arm64_sonoma: "225394a264699311f0f36dbb7f8515f960581dead64da8a7e949075c06f442df"
    sha256 cellar: :any_skip_relocation, ventura:      "c15e56f3488368d7a1e12142721f24fec557635613610d4c26b7cb28290f60e7"
    sha256 cellar: :any_skip_relocation, x86_64_linux: "0667141d81646233c8afe24bc4b0b88c070ba13ae63df3440980fc51c419ab1b"
  end

  depends_on "elixir" => :build
  depends_on "xz" => :build
  depends_on "erlang"

  resource "zig" do
    on_macos do
      on_arm do
        url "https://ziglang.org/download/0.11.0/zig-macos-aarch64-0.11.0.tar.xz"
        sha256 "c6ebf927bb13a707d74267474a9f553274e64906fd21bf1c75a20bde8cadf7b2"
      end

      on_intel do
        url "https://ziglang.org/download/0.11.0/zig-macos-x86_64-0.11.0.tar.xz"
        sha256 "1c1c6b9a906b42baae73656e24e108fd8444bb50b6e8fd03e9e7a3f8b5f05686"
      end
    end

    on_linux do
      url "https://ziglang.org/download/0.11.0/zig-linux-x86_64-0.11.0.tar.xz"
      sha256 "2d00e789fec4f71790a6e7bf83ff91d564943c5ee843c5fd966efc474b423047"
    end
  end

  def install
    zig_install_dir = buildpath/"zig"
    mkdir zig_install_dir
    resources.each do |r|
      r.fetch

      system "tar", "xvC", zig_install_dir, "-f", r.cached_download
      zig_dir =
        if OS.mac? && Hardware::CPU.arm?
          zig_install_dir/"zig-macos-aarch64-0.11.0"
        elsif OS.mac? && Hardware::CPU.intel?
          zig_install_dir/"zig-macos-x86_64-0.11.0"
        elsif OS.linux? && Hardware::CPU.intel?
          zig_install_dir/"zig-linux-x86_64-0.11.0"
        end

      ENV["PATH"] = "#{zig_dir}:" + ENV["PATH"]
    end

    system "mix", "local.hex", "--force"
    system "mix", "local.rebar", "--force"

    target =
      if OS.mac? && Hardware::CPU.arm?
        "darwin_arm64"
      elsif OS.mac? && Hardware::CPU.intel?
        "darwin_amd64"
      elsif OS.linux? && Hardware::CPU.intel?
        "linux_amd64"
      end

    ENV["BURRITO_TARGET"] = target
    ENV["MIX_ENV"] = "prod"
    system "mix", "deps.get"
    system "mix", "release"

    bin.install "burrito_out/next_ls_#{target}" => "nextls"
  end

  test do
    require "open3"

    json = <<~JSON
      {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "initialize",
        "params": {
          "rootUri": null,
          "capabilities": {}
        }
      }
    JSON

    shell_output("#{Formula["erlang"].prefix}/bin/epmd -daemon")

    Open3.popen3("#{bin}/nextls", "--stdio") do |stdin, stdout, _e, w|
      stdin.write "Content-Length: #{json.size}\r\n\r\n#{json}"
      sleep 3
      assert_match(/^Content-Length: \d+/i, stdout.readline)
      Process.kill("KILL", w.pid)
    end
  end
end

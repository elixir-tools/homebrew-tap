class NextLs < Formula
  desc "Language server for Elixir that just works"
  homepage "https://www.elixir-tools.dev/next-ls"
  url "https://github.com/elixir-tools/next-ls/archive/refs/tags/v0.20.1.tar.gz"
  sha256 "3192f9d28a3d5478599d0661728005be04ca79baa4a499df849f68c4aeda5380"
  license "MIT"

  bottle do
    root_url "https://github.com/elixir-tools/homebrew-tap/releases/download/next-ls-0.20.1"
    sha256 cellar: :any_skip_relocation, arm64_sonoma: "f80b7945a576c0c0b9f85b5ee54fc15966a6faecb8b213f03cd2a3af92080e6a"
    sha256 cellar: :any_skip_relocation, ventura:      "a7551279ecffd7b8104651a55fbc1e9cf3100b92bda27929f85de9a3d36cda26"
    sha256 cellar: :any_skip_relocation, x86_64_linux: "b9d6dd4f0b5d6f268025d681b2fb979ad15330e4c562e78008575c6246977c2b"
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

class NextLs < Formula
  desc "Language server for Elixir that just works"
  homepage "https://www.elixir-tools.dev/next-ls"
  url "https://github.com/elixir-tools/next-ls/archive/refs/tags/v0.22.7.tar.gz"
  sha256 "d2100e5bccae8be557beadf4d80d363c4bdb32cf8abde47b0bf6ffcd91c3a3ed"
  license "MIT"

  bottle do
    root_url "https://github.com/elixir-tools/homebrew-tap/releases/download/next-ls-0.22.7"
    sha256 cellar: :any_skip_relocation, arm64_sonoma: "7a1fd148220725b2d8554ad9d429bbd11f1a8dfcf93efa645efc4fe58a320ec6"
    sha256 cellar: :any_skip_relocation, ventura:      "9dda2d9b89f4e076ed182e6c0f0f0a6a78f28a69a73bc1d74cf3f811b4fee9be"
    sha256 cellar: :any_skip_relocation, x86_64_linux: "7fbf953ac49262089b5d26c8ddfea2924ba4763d551768f0e19dd05c2429a8c2"
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
    ENV["NEXTLS_RELEASE_MODE"] = "burrito"
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

class NextLs < Formula
  desc "Language server for Elixir that just works"
  homepage "https://www.elixir-tools.dev/next-ls"
  url "https://github.com/elixir-tools/next-ls/archive/refs/tags/v0.12.7.tar.gz"
  sha256 "79c96307db5b0591786ba453e79f3723a78862afdffcc5d9f0f7fd0ecfd588b3"
  license "MIT"

  bottle do
    root_url "https://github.com/elixir-tools/homebrew-tap/releases/download/next-ls-0.12.6"
    sha256 cellar: :any_skip_relocation, ventura:      "89b09bd2d7a3735c189873fedb49ec8aa3bc6f5a1ce536c87c001ef9d120629d"
    sha256 cellar: :any_skip_relocation, x86_64_linux: "4967b231721bc6f81882904dbb396187c0ac8cb5e133fbb6046c8f32d73f771f"
  end

  depends_on "elixir" => :build
  depends_on "xz" => :build
  depends_on "erlang"

  resource "zig" do
    on_macos do
      on_arm do
        url "https://ziglang.org/download/0.10.0/zig-macos-aarch64-0.10.0.tar.xz"
        sha256 "02f7a7839b6a1e127eeae22ea72c87603fb7298c58bc35822a951479d53c7557"
      end

      on_intel do
        url "https://ziglang.org/download/0.10.0/zig-macos-x86_64-0.10.0.tar.xz"
        sha256 "3a22cb6c4749884156a94ea9b60f3a28cf4e098a69f08c18fbca81c733ebfeda"
      end
    end

    on_linux do
      url "https://ziglang.org/download/0.10.0/zig-linux-x86_64-0.10.0.tar.xz"
      sha256 "631ec7bcb649cd6795abe40df044d2473b59b44e10be689c15632a0458ddea55"
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
          zig_install_dir/"zig-macos-aarch64-0.10.0"
        elsif OS.mac? && Hardware::CPU.intel?
          zig_install_dir/"zig-macos-x86_64-0.10.0"
        elsif OS.linux? && Hardware::CPU.intel?
          zig_install_dir/"zig-linux-x86_64-0.10.0"
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

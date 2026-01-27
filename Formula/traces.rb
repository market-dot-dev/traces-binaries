# typed: false
# frozen_string_literal: true

class Traces < Formula
  desc "Traces CLI"
  homepage "https://github.com/market-dot-dev/traces"
  version "0.1.21"

  on_macos do
    if Hardware::CPU.intel?
      url "https://github.com/market-dot-dev/traces-binaries/releases/download/v0.1.21/traces-darwin-x64"
      sha256 "d84baaad76959d480987ad506d9efeb804ae47fd4c9db2929b43a0739b1b9f2f"

      def install
        bin.install "traces-darwin-x64" => "traces"
      end
    end
    if Hardware::CPU.arm?
      url "https://github.com/market-dot-dev/traces-binaries/releases/download/v0.1.21/traces-darwin-arm64"
      sha256 "4a95a5e76d01c86219b27ae44db6854784be3f91f09d9d8018f90f4e037e86ae"

      def install
        bin.install "traces-darwin-arm64" => "traces"
      end
    end
  end

  on_linux do
    if Hardware::CPU.intel? && Hardware::CPU.is_64_bit?
      url "https://github.com/market-dot-dev/traces-binaries/releases/download/v0.1.21/traces-linux-x64"
      sha256 "263be1b8cf7550f222f9c9963e64745892e5ce96fc59db1be3d250a5c95192d8"
      def install
        bin.install "traces-linux-x64" => "traces"
      end
    end
  end
end

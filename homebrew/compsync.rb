class Compsync < Formula
  desc "Synchronize DevContainer configurations from MiguelRodo/comp"
  homepage "https://github.com/MiguelRodo/compsync"
  url "https://github.com/MiguelRodo/compsync/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "REPLACE_WITH_ACTUAL_SHA256"
  license "MIT"

  depends_on "python3"

  def install
    # Install all scripts to libexec to preserve directory structure
    libexec.install "scripts"

    # Create a wrapper script in bin
    (bin/"compsync").write <<~EOS
      #!/bin/bash
      exec "#{libexec}/scripts/compsync.sh" "$@"
    EOS
  end

  test do
    assert_match "Usage:", shell_output("#{bin}/compsync --help")
  end
end

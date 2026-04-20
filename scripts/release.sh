#!/bin/bash
set -e

VERSION=$(grep 'version:' mix.exs | head -1 | sed 's/.*"\(.*\)".*/\1/')
echo "releasing v${VERSION}"

MIX_ENV=prod mix release --overwrite
SHA_ARM=$(shasum -a 256 burrito_out/el_macos_arm64 | awk '{print $1}')

GITHUB_TOKEN=$GITHUB_LIMADELIC gh release delete "v${VERSION}" -y -R limadelic/el 2>/dev/null || true
GITHUB_TOKEN=$GITHUB_LIMADELIC gh release create "v${VERSION}" \
  burrito_out/el_macos_arm64 \
  --repo limadelic/el --title "v${VERSION}" --notes "v${VERSION}"

TAP=/tmp/homebrew-tap
if [ ! -d "$TAP" ]; then
  git clone "https://github.com/limadelic/homebrew-tap.git" "$TAP"
fi
cd "$TAP" && git pull

cat > Formula/el.rb <<FORMULA
class El < Formula
  desc "CLI for managing headless Claude Code sessions"
  homepage "https://github.com/limadelic/el"
  license "MIT"
  version "${VERSION}"

  url "https://github.com/limadelic/el/releases/download/v${VERSION}/el_macos_arm64"
  sha256 "${SHA_ARM}"

  def install
    bin.install "el_macos_arm64" => "el"
  end

  test do
    assert_match "usage", shell_output("#{bin}/el", 0)
  end
end
FORMULA

git add Formula/el.rb
git commit -m "bump to v${VERSION}"
GITHUB_TOKEN=$GITHUB_LIMADELIC git push

echo "v${VERSION} released"
echo "arm64 sha: ${SHA_ARM}"

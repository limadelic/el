#!/bin/bash
set -e

CURRENT_VERSION=$(grep 'version:' mix.exs | head -1 | sed 's/.*"\(.*\)".*/\1/')
MAJOR_MINOR=$(echo $CURRENT_VERSION | sed 's/\(.*\)\.\([0-9]*\)$/\1/')
PATCH=$(echo $CURRENT_VERSION | sed 's/.*\.\([0-9]*\)$/\1/')
NEW_PATCH=$((PATCH + 1))
NEW_VERSION="${MAJOR_MINOR}.${NEW_PATCH}"

sed -i '' "s/version: \"${CURRENT_VERSION}\"/version: \"${NEW_VERSION}\"/" mix.exs

git add mix.exs
git commit -m "v${NEW_VERSION}"
git push

VERSION=$NEW_VERSION
REPO="limadelic/el"
echo "releasing v${VERSION}"

echo "triggering GHA pack workflow..."
GITHUB_TOKEN=$GITHUB_LIMADELIC gh workflow run pack.yml --repo $REPO -f version=$VERSION

echo "waiting for pack to complete..."
sleep 10
RUN_ID=$(GITHUB_TOKEN=$GITHUB_LIMADELIC gh run list --repo $REPO --workflow=pack.yml -L 1 --json databaseId --jq '.[0].databaseId')
GITHUB_TOKEN=$GITHUB_LIMADELIC gh run watch "$RUN_ID" --repo $REPO --exit-status

echo "downloading binary..."
rm -rf burrito_out
mkdir -p burrito_out
GITHUB_TOKEN=$GITHUB_LIMADELIC gh run download "$RUN_ID" --repo $REPO --name el_macos_arm64 -D burrito_out/

chmod +x burrito_out/el_macos_arm64
SHA_ARM=$(shasum -a 256 burrito_out/el_macos_arm64 | awk '{print $1}')

echo "creating github release..."
GITHUB_TOKEN=$GITHUB_LIMADELIC gh release delete "v${VERSION}" -y -R $REPO 2>/dev/null || true
GITHUB_TOKEN=$GITHUB_LIMADELIC gh release create "v${VERSION}" \
  burrito_out/el_macos_arm64 \
  --repo $REPO --title "v${VERSION}" --notes "v${VERSION}"

echo "updating homebrew tap..."
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

echo "upgrading brew..."
brew upgrade limadelic/tap/el 2>/dev/null || brew install limadelic/tap/el

echo "v${VERSION} released and installed"

#!/bin/bash
set -e

VERSION=$(grep 'version:' mix.exs | head -1 | sed 's/.*"\(.*\)".*/\1/')
echo "releasing v${VERSION}"

echo "downloading tarball from GitHub Actions..."
RUN_ID=$(GITHUB_TOKEN=$GITHUB_LIMADELIC gh run list --repo limadelic/el --workflow=pack.yml -L 1 --json databaseId --jq '.[0].databaseId')
GITHUB_TOKEN=$GITHUB_LIMADELIC gh run download "$RUN_ID" --repo limadelic/el --name el-macos-arm64 -D /tmp/el-release/

SHA=$(shasum -a 256 /tmp/el-release/el-macos-arm64.tar.gz | awk '{print $1}')

GITHUB_TOKEN=$GITHUB_LIMADELIC gh release delete "v${VERSION}" -y -R limadelic/el 2>/dev/null || true
GITHUB_TOKEN=$GITHUB_LIMADELIC gh release create "v${VERSION}" \
  /tmp/el-release/el-macos-arm64.tar.gz \
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

  url "https://github.com/limadelic/el/releases/download/v${VERSION}/el-macos-arm64.tar.gz"
  sha256 "${SHA}"

  def install
    libexec.install Dir["*"]
    (bin/"el").write <<~EOS
      #!/bin/bash
      export EL_BIN="$0"
      exec "#{libexec}/bin/el" eval "El.CLI.main(System.argv())" -- "$@"
    EOS
    chmod 0755, bin/"el"
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
echo "sha: ${SHA}"

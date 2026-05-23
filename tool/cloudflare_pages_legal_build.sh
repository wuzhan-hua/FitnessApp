#!/usr/bin/env bash

set -euo pipefail

rm -rf dist
mkdir -p dist/privacy dist/terms

cp web-static/privacy/index.html dist/privacy/index.html
cp web-static/terms/index.html dist/terms/index.html

echo "已生成 Cloudflare Pages 法律页面产物："
echo " - dist/privacy/index.html"
echo " - dist/terms/index.html"

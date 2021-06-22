#!/usr/bin/env bash

fail() {
  msg="$1"
  >&2 echo "ERROR: $msg"
  exit 1
}

homebrew_installed() {
  which brew 2>/dev/null
}

if ! homebrew_installed
then
  fail "Homebrew isn't installed. Please install it."
fi


#!/usr/bin/env bash
#
# Bedrock Connect updater
#
# Notes:
# - Requires an Ubuntu or Ubuntu distribution.
# - Requires curl and jq.
# - Automatic update will install dependencies if not present.
# - The update download in the current user home folder.
# - The automatic updater expect a bedrock_connect systemd service to restart.
#

function requires_root() {
  if [[ "$(whoami)" != "root" ]]; then
    echo "Error: This script need to be ran as root (or using sudo)."
    exit 1
  fi
}

function os_deps_check() {
  if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    if [[ "$ID" == "ubuntu" || "$ID_LIKE" == *"ubuntu"* ]]; then
      command -v curl > /dev/null || apt install -y curl
      command -v jq > /dev/null || apt install -y jq
    elif [[ "$ID" == "centos" ]]; then
      [[ "$(yum list epel-release 2>/dev/null)" == *Available* ]] && yum install -y epel-release
      command -v curl > /dev/null || yum install -y curl
      command -v jq > /dev/null || yum install -y jq
    else
      echo "Unsupported OS"
      exit 2
    fi
  else
    echo "Unsupported OS"
    exit 2
  fi
}

function install() {
  requires_root
  os_deps_check

  # Add crontab
  (crontab -l 2>/dev/null; echo "0 * * * * $PWD/$0 run") | crontab -
}

function uninstall() {
  requires_root
  os_deps_check

  # Remove crontab
  (crontab -l 2>/dev/null | sed "/$(basename "$0") run/d") | crontab -
}

function update() {
  local path="${1:-$HOME}"

  if ! command -v curl > /dev/null; then echo "Missing curl."; exit 2; fi
  if ! command -v jq > /dev/null; then echo "Missing jq."; exit 2; fi

  CURRENT_TAG_NAME="$(cat "$path/.bedrock_connect_version" 2>/dev/null)"

  LATEST="$(curl -s https://api.github.com/repos/Pugmatt/BedrockConnect/releases/latest)"

  LATEST_TAG_NAME="$(echo "$LATEST" | jq -r .tag_name)"

  if [[ "$CURRENT_TAG_NAME" == "$LATEST_TAG_NAME" ]]; then exit; fi

  curl "$(echo "$LATEST" | jq -r .assets[0].browser_download_url)" -sLo "$path/BedrockConnect-1.0-SNAPSHOT.jar"

  printf "$LATEST_TAG_NAME" > "$path/.bedrock_connect_version"
}

function run() {
  update "$(cat /etc/systemd/system/bedrock_connect.service | grep WorkingDirectory | cut -c 18-)"

  # Restart the service
  systemctl restart bedrock_connect
}

function help() {
  echo "Usage: $0 [command]"
  echo "Commands:"
  echo "  install      Install a crontab for automatic update (requires root)"
  echo "  uninstall    Uninstall the automatic update (requires root)"
  echo "  update       Perform a manual update"
}

case "$1" in
install)   install;;
uninstall) uninstall;;
update)    update;;
run)       run;;
*)         help;;
esac

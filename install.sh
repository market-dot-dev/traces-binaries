#!/usr/bin/env bash
set -euo pipefail

APP=traces
REPO="market-dot-dev/traces-binaries"
INSTALL_DIR_DEFAULT="$HOME/.traces/bin"

MUTED='\033[0;2m'
RED='\033[0;31m'
ORANGE='\033[38;5;214m'
NC='\033[0m'

requested_version="${TRACES_VERSION:-}"
install_dir="${TRACES_INSTALL_DIR:-}"
binary_path=""
no_modify_path=false

usage() {
  cat <<EOF
Traces Installer

Usage: install.sh [options]

Options:
  -h, --help              Display this help message
  -v, --version <version> Install a specific version (e.g., 0.1.9)
  -b, --binary <path>     Install from a local binary instead of downloading
      --no-modify-path    Don't modify shell config files (.zshrc, .bashrc, etc.)

Examples:
  curl -fsSL https://traces.sh/install | bash
  curl -fsSL https://traces.sh/install | bash -s -- --version 0.1.9
  ./install.sh --binary /path/to/traces
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    -v|--version)
      if [[ -n "${2:-}" ]]; then
        requested_version="$2"
        shift 2
      else
        echo -e "${RED}Error: --version requires a version argument${NC}"
        exit 1
      fi
      ;;
    -b|--binary)
      if [[ -n "${2:-}" ]]; then
        binary_path="$2"
        shift 2
      else
        echo -e "${RED}Error: --binary requires a path argument${NC}"
        exit 1
      fi
      ;;
    --no-modify-path)
      no_modify_path=true
      shift
      ;;
    *)
      echo -e "${ORANGE}Warning: Unknown option '$1'${NC}" >&2
      shift
      ;;
  esac
done

detect_os() {
  local raw_os
  raw_os="$(uname -s)"
  case "$raw_os" in
    Darwin) echo "darwin" ;;
    Linux) echo "linux" ;;
    MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
    *) echo "unsupported" ;;
  esac
}

detect_arch() {
  local arch
  arch="$(uname -m)"
  case "$arch" in
    arm64|aarch64) echo "arm64" ;;
    x86_64|amd64) echo "x64" ;;
    *) echo "unsupported" ;;
  esac
}

latest_version() {
  curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
    | grep -m 1 -E '"tag_name"' \
    | sed -nE 's/.*"tag_name":\s*"v?([^"]+)".*/\1/p' \
    | tr -d '[:space:]'
}

resolve_install_dir() {
  if [ -n "$install_dir" ]; then
    echo "$install_dir"
    return
  fi
  echo "$INSTALL_DIR_DEFAULT"
}

print_message() {
  local level=$1
  local message=$2
  local color=""

  case $level in
    info) color="${NC}" ;;
    warning) color="${NC}" ;;
    error) color="${RED}" ;;
  esac

  echo -e "${color}${message}${NC}"
}

install_from_binary() {
  print_message info "${MUTED}Installing${NC} ${APP} ${MUTED}from:${NC} ${binary_path}"
  if [ ! -f "$binary_path" ]; then
    print_message error "Binary not found at ${binary_path}"
    exit 1
  fi
  mkdir -p "$install_dir"
  cp "$binary_path" "$install_dir/${APP}"
  chmod 755 "$install_dir/${APP}"
}

download_and_install() {
  local version="$1"
  local os="$2"
  local arch="$3"
  local asset="${APP}-${os}-${arch}"
  local url="https://github.com/${REPO}/releases/download/v${version}/${asset}"
  local tmp_dir

  tmp_dir="$(mktemp -d)"
  trap "rm -rf \"$tmp_dir\"" EXIT

  print_message info "${MUTED}Installing${NC} ${APP} ${MUTED}version:${NC} ${version}"
  curl -# -L -o "${tmp_dir}/${APP}" "$url"

  mkdir -p "$install_dir"
  install -m 755 "${tmp_dir}/${APP}" "$install_dir/${APP}"
}

add_to_path() {
  local config_file=$1
  local command=$2

  if grep -Fxq "$command" "$config_file"; then
    print_message info "Command already exists in $config_file, skipping write."
  elif [[ -w $config_file ]]; then
    echo -e "\n# ${APP}" >> "$config_file"
    echo "$command" >> "$config_file"
    print_message info "${MUTED}Added${NC} ${APP} ${MUTED}to PATH in${NC} $config_file"
  else
    print_message warning "Manually add the directory to $config_file (or similar):"
    print_message info "  $command"
  fi
}

main() {
  local os arch version

  os="$(detect_os)"
  arch="$(detect_arch)"

  if [ "$os" = "unsupported" ] || [ "$arch" = "unsupported" ]; then
    print_message error "Unsupported platform: $(uname -s) $(uname -m)"
    exit 1
  fi

  install_dir="$(resolve_install_dir)"

  if [ -n "$binary_path" ]; then
    install_from_binary
  else
    if [ -z "$requested_version" ]; then
      version="$(latest_version)"
      if [ -z "$version" ]; then
        print_message error "Failed to fetch latest version"
        exit 1
      fi
    else
      requested_version="${requested_version#v}"
      version="$requested_version"
    fi
    download_and_install "$version" "$os" "$arch"
  fi

  if [[ "$no_modify_path" != "true" ]]; then
    local config_files
    local config_file=""
    local shell_name

    shell_name=$(basename "$SHELL")
    XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-$HOME/.config}

    case $shell_name in
      fish)
        config_files="$HOME/.config/fish/config.fish"
      ;;
      zsh)
        config_files="${ZDOTDIR:-$HOME}/.zshrc ${ZDOTDIR:-$HOME}/.zshenv $XDG_CONFIG_HOME/zsh/.zshrc $XDG_CONFIG_HOME/zsh/.zshenv"
      ;;
      bash)
        config_files="$HOME/.bashrc $HOME/.bash_profile $HOME/.profile $XDG_CONFIG_HOME/bash/.bashrc $XDG_CONFIG_HOME/bash/.bash_profile"
      ;;
      *)
        config_files="$HOME/.bashrc $HOME/.bash_profile $XDG_CONFIG_HOME/bash/.bashrc $XDG_CONFIG_HOME/bash/.bash_profile"
      ;;
    esac

    for file in $config_files; do
      if [[ -f $file ]]; then
        config_file=$file
        break
      fi
    done

    if [[ -z $config_file ]]; then
      print_message warning "No config file found for $shell_name. You may need to add to PATH manually:"
      print_message info "  export PATH=$install_dir:\$PATH"
    elif [[ ":$PATH:" != *":$install_dir:"* ]]; then
      case $shell_name in
        fish)
          add_to_path "$config_file" "fish_add_path $install_dir"
        ;;
        *)
          add_to_path "$config_file" "export PATH=$install_dir:\$PATH"
        ;;
      esac
    fi
  fi

  print_message info "Installed ${APP} to ${install_dir}/${APP}"
  print_message info "Run: ${APP} --version"
}

main "$@"

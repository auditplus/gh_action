#!/usr/bin/env sh

# Copyright (c) 2022 Auditplus Technologies.

# This is a simple script that can be downloaded and run from
# https://install.auditplus.com in order to install the Auditplus ERP
# command-line tools and database server. It automatically detects
# the host operating platform, and cpu architecture type, and
# downloads the latest binary for the relevant platform.

# This install script attempts to install the Auditplus ERP binary
# automatically, or otherwise it will prompt the user to specify 
# the desired install location.

set -u

VERSION=""

INTERACTIVE=false

INSTALL_DIR="/usr/local/bin"

AERP_ROOT="https://download.auditplus.io"

expand() {
    case "$1" in
    (\~)        echo "$HOME";;
    (\~/*)      echo "$HOME/${1#\~/}";;
    (\~[^/]*/*) local user=$(eval echo ${1%%/*}) && echo "$user/${1#*/}";;
    (\~[^/]*)   eval echo ${1};;
    (*)         echo "$1";;
    esac
}

install() {

    echo "Installing Auditplus ERP..."
    
    # Parse script arguments

    while [ $# -ge 1 ]; do
        case "$1" in
            -v|--version)
                VERSION="$2"
                shift
                ;;
            -i|--interactive)
                INTERACTIVE=true
                ;;
            *)
                INSTALL_DIR="$1"
                shift
                ;;
        esac
        shift
    done

    # Check for necessary commands

    command -v uname >/dev/null 2>&1 || {
        err "Error: you need to have 'uname' installed and in your path"
    }

    command -v mkdir >/dev/null 2>&1 || {
        err "Error: you need to have 'mkdir' installed and in your path"
    }

    command -v read >/dev/null 2>&1 || {
        err "Error: you need to have 'read' installed and in your path"
    }

    command -v tar >/dev/null 2>&1 || {
        err "Error: you need to have 'tar' installed and in your path"
    }

    # Check for curl or wget commands

    local _cmd

    if command -v curl >/dev/null 2>&1; then
        _cmd=curl
    elif command -v wget >/dev/null 2>&1; then
        _cmd=wget
    else
        err "Error: you need to have 'curl' or 'wget' installed and in your path"
    fi

    # Fetch the latest Auditplus ERP version

    local _ver
    
    if [ "$VERSION" != "" ]; then

        echo "Fetching $VERSION..."

        _ver="$VERSION"
    
    else

        echo "Fetching the latest database version..."

        _ver=$(fetch "$_cmd" "$AERP_ROOT/latest.txt" "Error: could not fetch the latest Auditplus ERP release version")

    fi

    # Compute the current system architecture

    echo "Fetching the host system architecture..."

    local _oss
    local _cpu
    local _arc

    _oss="$(uname -s)"
    _cpu="$(uname -m)"

    case "$_oss" in
        Linux) _oss=linux;;
        Darwin) _oss=darwin;;
        MINGW* | MSYS* | CYGWIN*) _oss=windows;;
        *) err "Error: unsupported operating system: $_oss";;
    esac

    case "$_cpu" in
        arm64 | aarch64) _cpu=arm64;;
        x86_64 | x86-64 | x64 | amd64) _cpu=amd64;;
        *) err "Error: unsupported CPU architecture: $_cpu";;
    esac

    _arc="${_oss}-${_cpu}"

    # Compute the download file extension type

    local _ext

    case "$_oss" in
        linux) _ext="tgz";;
        darwin) _ext="tgz";;
        windows) _ext="exe";;
    esac

    # Define the latest Auditplus ERP download url

    local _url

    _url="${AERP_ROOT}/${_ver}/aerp-${_ver}-${_arc}.${_ext}"

    # Download and unarchive the latest Auditplus ERP binary

    cd /tmp

    echo "Installing aerp-${_ver} for ${_arc}..."

    echo "${_url}"

    if [ "$_cmd" = curl ]; then
        curl --silent --fail --location "$_url" --output "aerp-${_ver}-${_arc}.${_ext}" || {
            err "Error: could not fetch the latest Auditplus ERP file"
        }
    elif [ "$_cmd" = wget ]; then
        wget --quiet "$_url" -O "aerp-${_ver}-${_arc}.${_ext}" || {
            err "Error: could not fetch the latest Auditplus ERP file"
        }
    fi

    tar -zxf "aerp-${_ver}-${_arc}.${_ext}" || {
        err "Error: unable to extract the downloaded archive file"
    }

    # Install the Auditplus ERP binary into the specified directory

    local _loc="$INSTALL_DIR"
        
    mkdir -p "$_loc" 2>/dev/null

    if [ ! -d "$_loc" ] || ! touch "$_loc/aerp" 2>/dev/null; then
        if [ "$INTERACTIVE" = true ]; then
            echo ""
            read -p "Where would you like to install the 'aerp' binary [~/.aerp]? " _loc
            _loc=${_loc:-~/.aerp} && _loc=$(expand "$_loc")
        else
            _loc=~/.aerp
        fi
        mkdir -p "$_loc"
    fi
        
    mv "aerp" "$_loc" 2>/dev/null || {
        err "Error: we couldn't install the 'aerp' binary into $_loc"
    }
    
    # Show some simple instructions

    echo ""    
    echo "Auditplus ERP successfully installed in:"
    echo "  ${_loc}/aerp"
    echo ""

    if [ "${_loc}" != "${INSTALL_DIR}" ]; then
        echo "To ensure that aerp is in your \$PATH run:"
        echo "  PATH=${_loc}:\$PATH"
        echo "Or to move the binary to ${INSTALL_DIR} run:"
        echo "  sudo mv ${_loc}/aerp ${INSTALL_DIR}"
        echo ""
    fi

    echo "To see the command-line options run:"
    echo "  aerp help"
    echo "To start an in-memory database server run:"
    echo "  aerp start --log debug --user root --pass root memory"
    echo "For help with getting started visit:"
    echo "  https://erp.auditplus.io/docs"
    echo ""

    # Exit cleanly

    exit 0

}

err() {
    echo "$1" >&2 && exit 1
}

fetch() {
    if [ "$1" = curl ]; then
        curl --silent --fail --location "$2" || {
            err "$3"
        }
    elif [ "$1" = wget ]; then
        wget --quiet "$2" || {
            err "$3"
        }
    fi
}

install "$@" || exit 1
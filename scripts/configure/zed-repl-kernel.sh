#!/bin/bash
# Install Jupyter kernels so Zed's REPL (repl::Run, bound to `space m r`) can run
# fenced code blocks per language. Zed discovers kernelspecs from the user Jupyter
# data dir (~/Library/Jupyter/kernels). Idempotent and per-language guarded: each
# language installs only when its toolchain is present and its kernel is not yet
# registered, so partial setups converge and re-runs are all-skip.
#
# Languages: Python, Shell (bash), TypeScript/JS (Deno), Ruby. PHP and Rust are
# intentionally excluded -- no maintained PHP kernel (dead ext-zmq), and evcxr
# recompiles on every evaluation. Zed picks the kernel from a block's language tag.
#
# Python deps install via uv (Homebrew pip3 enforces PEP 668).
# Reference: https://zed.dev/docs/repl
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"
require_scope full

KERNEL_VENV="${HOME}/.local/share/zed-repl"
VENV_PY="${KERNEL_VENV}/bin/python"

registered() {
    [[ -d "${HOME}/Library/Jupyter/kernels/$1" ]] && return 0
    [[ -x "${VENV_PY}" ]] && "${VENV_PY}" -m jupyter kernelspec list 2>/dev/null | grep -qw "$1"
}

ensure_venv() {
    [[ -x "${VENV_PY}" ]] && return 0
    command -v uv >/dev/null 2>&1 || { echo "skip:zed-repl (uv not found; run scripts/install/brew-bundle.sh)"; return 1; }
    echo "install:zed-repl (uv venv)"
    uv venv "${KERNEL_VENV}"
}

# --- Python (ipykernel) ---
if registered zed-python; then
    echo "skip:zed-repl (python kernel already registered)"
elif ensure_venv; then
    echo "install:zed-repl (python / ipykernel)"
    uv pip install --python "${VENV_PY}" ipykernel \
        && "${VENV_PY}" -m ipykernel install --user --name zed-python --display-name "Python 3 (Zed)" \
        || echo "fail:zed-repl (python)"
fi

# --- Shell (bash_kernel) -- needs a modern bash, not macOS system bash 3.2 ---
if registered bash; then
    echo "skip:zed-repl (bash kernel already registered)"
else
    BREW_BASH="$( brew --prefix 2>/dev/null )/bin/bash"
    if [[ ! -x "${BREW_BASH}" ]]; then
        echo "skip:zed-repl (bash kernel needs Homebrew bash; run brew install bash)"
    elif ensure_venv; then
        echo "install:zed-repl (shell / bash_kernel)"
        uv pip install --python "${VENV_PY}" bash_kernel \
            && "${VENV_PY}" -m bash_kernel.install --user \
            || echo "fail:zed-repl (bash)"
    fi
fi

# --- TypeScript / JavaScript (Deno) ---
if registered deno; then
    echo "skip:zed-repl (deno kernel already registered)"
elif command -v deno >/dev/null 2>&1; then
    echo "install:zed-repl (typescript / deno)"
    deno jupyter --install || echo "fail:zed-repl (deno)"
else
    echo "skip:zed-repl (deno not found)"
fi

# --- Ruby (iruby) -- needs Homebrew ruby + zeromq, not system ruby 2.6 ---
if registered ruby; then
    echo "skip:zed-repl (ruby kernel already registered)"
else
    RUBY_PREFIX="$( brew --prefix ruby 2>/dev/null )"
    if [[ -x "${RUBY_PREFIX}/bin/gem" ]]; then
        echo "install:zed-repl (ruby / iruby)"
        "${RUBY_PREFIX}/bin/gem" install rubygems-requirements-system iruby \
            && "${RUBY_PREFIX}/bin/iruby" register --force \
            || echo "fail:zed-repl (ruby)"
    else
        echo "skip:zed-repl (Homebrew ruby not found; run brew install ruby zeromq)"
    fi
fi

echo "ok:zed-repl-kernel"
echo "      restart Zed, then run a code block with \`space m r\` (repl::Run)"

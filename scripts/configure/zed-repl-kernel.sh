#!/bin/bash
# Install a Python Jupyter kernel so Zed's REPL can run fenced code blocks in
# markdown and other buffers (repl::Run, bound to `space m r`). Zed discovers
# kernelspecs from the user Jupyter data dir; ipykernel registers one there.
# Idempotent: skips if the kernel is already registered. Uses uv (PEP 668 makes
# Homebrew pip refuse installs), per the repo's Python convention.
# Reference: https://zed.dev/docs/repl
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

KERNEL_NAME="zed-python"
KERNEL_VENV="${HOME}/.local/share/zed-repl"

if ! command -v uv >/dev/null 2>&1; then
    echo "fail:zed-repl-kernel (uv not found; run scripts/install/brew-bundle.sh)"
    exit 1
fi

if [[ -f "${KERNEL_VENV}/share/jupyter/kernels/${KERNEL_NAME}/kernel.json" ]] \
    || "${KERNEL_VENV}/bin/python" -m jupyter kernelspec list 2>/dev/null | grep -q "${KERNEL_NAME}"; then
    echo "skip:zed-repl-kernel (${KERNEL_NAME} already registered)"
    echo "ok:zed-repl-kernel"
    exit 0
fi

echo "install:zed-repl-kernel (uv venv + ipykernel)"
uv venv "${KERNEL_VENV}" || { echo "fail:zed-repl-kernel (uv venv)"; exit 1; }
uv pip install --python "${KERNEL_VENV}/bin/python" ipykernel || { echo "fail:zed-repl-kernel (ipykernel install)"; exit 1; }
"${KERNEL_VENV}/bin/python" -m ipykernel install --user --name "${KERNEL_NAME}" --display-name "Python 3 (Zed)" \
    || { echo "fail:zed-repl-kernel (kernelspec register)"; exit 1; }

echo "ok:zed-repl-kernel"
echo "      restart Zed, then run a python code block with \`space m r\` (repl::Run)"

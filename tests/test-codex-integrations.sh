#!/bin/bash
# Regression tests for Codex integration ownership.
# Source: https://github.com/N4M3Z/forge-provision

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
failures=0

fail() {
    echo "FAIL: $1"
    failures=$((failures + 1))
}

pass() {
    echo "PASS: $1"
}

assert_jq() {
    local file="$1"
    local expression="$2"
    local label="$3"

    if jq -e "$expression" "$file" >/dev/null 2>&1; then
        pass "$label"
    else
        fail "$label"
    fi
}

test_codex_removes_only_imported_claude_hooks() {
    local home="$1"
    local bin="$2"
    local hooks="${home}/.codex/hooks.json"
    local session_sync="${home}/session-sync"

    mkdir -p "${home}/.codex" "$bin"
    printf '%s\n' '#!/bin/bash' 'exit 0' > "${bin}/codex"
    chmod +x "${bin}/codex"

    printf '%s\n' \
        '{' \
        '  "hooks": {' \
        '    "PreToolUse": [' \
        '      {"matcher":"Bash","hooks":[{"type":"command","command":"dcg"}]},' \
        '      {"matcher":"Bash","hooks":[{"type":"command","command":"rtk hook claude"}]},' \
        '      {"matcher":"Bash","hooks":[{"type":"command","command":"keep-me"}]}' \
        '    ],' \
        '    "PreCompact": [' \
        '      {"hooks":[{"type":"command","command":"capture-session"}]}' \
        '    ]' \
        '  }' \
        '}' > "$hooks"
    printf '%s\n' \
        '# existing live config' \
        '[[hooks.PreToolUse]]' \
        '[[hooks.PreToolUse.hooks]]' \
        'type = "command"' \
        'command = "dcg"' > "${home}/.codex/config.toml"

    HOME="$home" PATH="${bin}:${PATH}" SESSION_SYNC="${session_sync}" \
        bash "${ROOT}/scripts/configure/codex.sh" >/dev/null

    assert_jq "$hooks" \
        '[.hooks.PreToolUse[].hooks[].command] | index("dcg") == null' \
        'Codex removes the imported duplicate dcg hook'
    assert_jq "$hooks" \
        '[.hooks.PreToolUse[].hooks[].command] | index("rtk hook claude") == null' \
        'Codex removes the unsupported Claude RTK hook'
    assert_jq "$hooks" \
        '[.hooks.PreToolUse[].hooks[].command] | index("keep-me") != null' \
        'Codex preserves unrelated PreToolUse hooks'
    assert_jq "$hooks" \
        '[.hooks.PreCompact[].hooks[].command] | index("capture-session") == null' \
        'Codex removes retired capture-session hook'
    assert_jq "$hooks" \
        "[.hooks.PreCompact[].hooks[].command] | index(\"${session_sync}\") != null" \
        'Codex rewrites capture-session to session-sync'
    assert_jq "$hooks" \
        "[.hooks.Stop[].hooks[].command] | index(\"${session_sync}\") != null" \
        'Codex ensures Stop session capture'
}

test_codex_preserves_dcg_without_native_replacement() {
    local home="$1"
    local bin="$2"
    local hooks="${home}/.codex/hooks.json"

    mkdir -p "${home}/.codex" "$bin"
    printf '%s\n' '#!/bin/bash' 'exit 0' > "${bin}/codex"
    chmod +x "${bin}/codex"
    printf '%s\n' \
        '{"hooks":{"PreToolUse":[' \
        '  {"matcher":"Bash","hooks":[{"type":"command","command":"dcg"}]},' \
        '  {"matcher":"Bash","hooks":[{"type":"command","command":"rtk hook claude"}]}' \
        ']}}' > "$hooks"
    printf '%s\n' '# existing config without native dcg' > "${home}/.codex/config.toml"

    HOME="$home" PATH="${bin}:${PATH}" SESSION_SYNC="${home}/session-sync" \
        bash "${ROOT}/scripts/configure/codex.sh" >/dev/null

    assert_jq "$hooks" \
        '[.hooks.PreToolUse[].hooks[].command] | index("dcg") != null' \
        'Codex preserves imported dcg when no native replacement exists'
    assert_jq "$hooks" \
        '[.hooks.PreToolUse[].hooks[].command] | index("rtk hook claude") == null' \
        'Codex still removes unsupported RTK hook without native dcg'
}

test_rtk_configures_codex_when_claude_is_current() {
    local home="$1"
    local bin="$2"
    local log="${home}/rtk-calls.log"

    mkdir -p "$home" "$bin"
    printf '%s\n' \
        '#!/bin/bash' \
        'if [[ "$*" == "init -g --show" ]]; then' \
        '    echo "[ok] Hook: configured"' \
        '    exit 0' \
        'fi' \
        'printf "%s\\n" "$*" >> "$RTK_TEST_LOG"' \
        'exit 0' > "${bin}/rtk"
    chmod +x "${bin}/rtk"

    HOME="$home" PATH="${bin}:${PATH}" RTK_TEST_LOG="$log" \
        bash "${ROOT}/scripts/configure/rtk-hook.sh" >/dev/null

    if [[ -f "$log" ]] && [[ "$(<"$log")" == *"init -g --codex"* ]]; then
        pass 'RTK configures its supported Codex instructions path'
    else
        fail 'RTK configures its supported Codex instructions path'
    fi
}

test_codex_seed_matches_current_permission_model() {
    local config="${ROOT}/manifests/codex/config.toml"
    local agents="${ROOT}/manifests/codex/AGENTS.md"

    if grep -q '^default_permissions = "workspace-local"$' "$config"; then
        pass 'Codex seed uses workspace-local permissions'
    else
        fail 'Codex seed uses workspace-local permissions'
    fi

    if grep -q '^approvals_reviewer = "auto_review"$' "$config"; then
        pass 'Codex seed enables auto-review approval classification'
    else
        fail 'Codex seed enables auto-review approval classification'
    fi

    if grep -q '^\[features\.network_proxy\]' "$config"; then
        fail 'Codex seed avoids legacy network_proxy config'
    else
        pass 'Codex seed avoids legacy network_proxy config'
    fi

    if grep -q '^OPENAI_API_KEY' "$config"; then
        fail 'Codex seed does not set a global OPENAI_API_KEY'
    else
        pass 'Codex seed does not set a global OPENAI_API_KEY'
    fi

    if grep -q '^OPENAI_BASE_URL' "$config"; then
        fail 'Codex seed does not set a global OPENAI_BASE_URL'
    else
        pass 'Codex seed does not set a global OPENAI_BASE_URL'
    fi

    if grep -q '@/Users/N4M3Z/.codex/RTK.md' "$agents"; then
        pass 'Codex AGENTS policy keeps RTK instructions'
    else
        fail 'Codex AGENTS policy keeps RTK instructions'
    fi

    if grep -q 'Never read credential stores' "$agents" \
        && grep -q 'Do not commit, tag, release, or push' "$agents" \
        && grep -q 'Computer Use drives GUI apps outside the shell sandbox' "$agents"; then
        pass 'Codex AGENTS policy mirrors Claude auto-mode guardrails'
    else
        fail 'Codex AGENTS policy mirrors Claude auto-mode guardrails'
    fi
}

test_root_agents_policy_is_codex_specific() {
    local agents="${ROOT}/AGENTS.md"

    if grep -q 'Codex, Codex, Gemini' "$agents" \
        || grep -q 'migrate/Codex-history.sh' "$agents"; then
        fail 'Root AGENTS avoids mechanical Claude substitutions'
    else
        pass 'Root AGENTS avoids mechanical Claude substitutions'
    fi

    if grep -q '@/Users/N4M3Z/.codex/RTK.md' "$agents" \
        && grep -q 'These scripts MUTATE the host' "$agents" \
        && grep -q 'Never read credential stores' "$agents" \
        && grep -q 'Do not commit, tag, release, or push' "$agents" \
        && grep -q 'Computer Use drives GUI apps outside the shell sandbox' "$agents"; then
        pass 'Root AGENTS carries Codex daily-driver policy'
    else
        fail 'Root AGENTS carries Codex daily-driver policy'
    fi
}

test_codex_docs_do_not_claim_chezmoi_owns_live_config() {
    if grep -R "chezmoi owns the live config" \
        "${ROOT}/scripts/configure/codex.sh" \
        "${ROOT}/manifests/codex/config.toml" \
        "${ROOT}/docs/tldr/codex.md" >/dev/null 2>&1; then
        fail 'Codex docs avoid chezmoi live-config ownership claim'
    else
        pass 'Codex docs avoid chezmoi live-config ownership claim'
    fi
}

tmp="$(mktemp -d "${TMPDIR:-/tmp}/forge-provision-codex.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

test_codex_removes_only_imported_claude_hooks \
    "${tmp}/codex-home" "${tmp}/codex-bin"
test_codex_preserves_dcg_without_native_replacement \
    "${tmp}/codex-no-dcg-home" "${tmp}/codex-no-dcg-bin"
test_rtk_configures_codex_when_claude_is_current \
    "${tmp}/rtk-home" "${tmp}/rtk-bin"
test_codex_seed_matches_current_permission_model
test_root_agents_policy_is_codex_specific
test_codex_docs_do_not_claim_chezmoi_owns_live_config

if (( failures > 0 )); then
    echo "${failures} test(s) failed"
    exit 1
fi

echo 'All Codex integration tests passed'

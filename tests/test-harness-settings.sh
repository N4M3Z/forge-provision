#!/bin/bash
# Regression tests for transactional cross-harness settings maintenance.
# Source: https://github.com/N4M3Z/forge-provision

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
ENGINE="${ROOT}/scripts/configure/harness-settings.sh"
failures=0

fail() {
    echo "FAIL: $1"
    failures=$((failures + 1))
}

pass() {
    echo "PASS: $1"
}

assert_success() {
    local label="$1"
    local output
    shift

    if output=$("$@" 2>&1); then
        pass "$label"
    else
        fail "$label"
        printf '%s\n' "$output"
    fi
}

assert_failure() {
    local label="$1"
    shift

    if "$@" >/dev/null 2>&1; then
        fail "$label"
    else
        pass "$label"
    fi
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

make_registry() {
    local root="$1"

    mkdir -p "${root}/policies" "${root}/home/.claude" "${root}/home/.codex"
    printf '%s\n' \
        'schema_version: 1' \
        'providers:' \
        '  claude:' \
        '    format: json' \
        '    strategy: json-deep-merge' \
        '    source: .claude/settings.json' \
        '    policy: policies/claude.json' \
        '  codex:' \
        '    format: json' \
        '    strategy: json-deep-merge' \
        '    source: .codex/settings.json' \
        '    policy: policies/codex.json' \
        > "${root}/registry.yaml"

    printf '%s\n' \
        '{' \
        '  "model": "interactive-default",' \
        '  "sandbox": {"enabled": false},' \
        '  "unknown": {"keep": "yes"},' \
        '  "apiKey": "fixture-existing-secret"' \
        '}' > "${root}/home/.claude/settings.json"
    printf '%s\n' \
        '{"sandbox":{"enabled":true},"permissions":{"deny":["Finder"]}}' \
        > "${root}/policies/claude.json"

    printf '%s\n' \
        '{"default_permissions":"untrusted","unknown":{"keep":"codex"}}' \
        > "${root}/home/.codex/settings.json"
    printf '%s\n' \
        '{"default_permissions":"workspace-local"}' \
        > "${root}/policies/codex.json"
}

run_engine() {
    local fixture="$1"
    shift

    HARNESS_SETTINGS_HOME="${fixture}/home" \
        HARNESS_SETTINGS_REGISTRY="${fixture}/registry.yaml" \
        "$ENGINE" "$@"
}

make_chezmoi_registry() {
    local root="$1"

    mkdir -p \
        "${root}/home/.claude" \
        "${root}/source/.harness-settings" \
        "${root}/source/dot_claude"
    printf '%s\n' \
        'schema_version: 1' \
        'providers:' \
        '  claude:' \
        '    deployment: chezmoi' \
        '    format: json' \
        '    strategy: json-deep-merge' \
        '    source: .claude/settings.json' \
        '    policy: .harness-settings/claude.json' \
        '    policy_root: chezmoi' \
        '    managed_source: dot_claude/modify_private_settings.json' \
        > "${root}/registry.yaml"
    printf '%s\n' \
        '{"sandbox":{"enabled":false},"unknown":{"keep":"yes"},"apiKey":"fixture-existing-secret"}' \
        > "${root}/home/.claude/settings.json"
    printf '%s\n' '{"sandbox":{"enabled":true}}' \
        > "${root}/source/.harness-settings/claude.json"
    printf '%s\n' \
        '#!/bin/bash' \
        "jq '. * {\"sandbox\":{\"enabled\":true}}'" \
        > "${root}/source/dot_claude/modify_private_settings.json"
    chmod +x "${root}/source/dot_claude/modify_private_settings.json"
}

make_chezmoi_toml_registry() {
    local root="$1"

    mkdir -p \
        "${root}/home/.grok" \
        "${root}/source/.harness-settings" \
        "${root}/source/dot_grok"
    printf '%s\n' \
        'schema_version: 1' \
        'providers:' \
        '  grok:' \
        '    deployment: chezmoi' \
        '    format: toml' \
        '    strategy: object-deep-merge' \
        '    source: .grok/config.toml' \
        '    policy: .harness-settings/grok.json' \
        '    policy_root: chezmoi' \
        '    managed_source: dot_grok/modify_private_config.toml' \
        > "${root}/registry.yaml"
    printf '%s\n' \
        'model = "interactive-default"' \
        'unknown = "keep-me"' \
        '' \
        '[sandbox]' \
        'enabled = false' \
        > "${root}/home/.grok/config.toml"
    printf '%s\n' '{"sandbox":{"enabled":true}}' \
        > "${root}/source/.harness-settings/grok.json"
    printf '%s\n' \
        '#!/bin/bash' \
        "yq -p=toml -o=toml '.sandbox.enabled = true'" \
        > "${root}/source/dot_grok/modify_private_config.toml"
    chmod +x "${root}/source/dot_grok/modify_private_config.toml"
}

run_chezmoi_engine() {
    local fixture="$1"
    shift

    HARNESS_SETTINGS_HOME="${fixture}/home" \
        HARNESS_SETTINGS_REGISTRY="${fixture}/registry.yaml" \
        HARNESS_SETTINGS_CHEZMOI_SOURCE="${fixture}/source" \
        "$ENGINE" "$@"
}

test_plan_is_deterministic_and_redacted() {
    local fixture="$1"
    local plan_one="${fixture}/plan-one.json"
    local plan_two="${fixture}/plan-two.json"

    assert_success 'plan creates a machine-readable artifact' \
        run_engine "$fixture" plan --workshop "$fixture" --output "$plan_one"
    assert_success 'the same inputs produce the same plan bytes' \
        run_engine "$fixture" plan --workshop "$fixture" --output "$plan_two"

    if cmp -s "$plan_one" "$plan_two"; then
        pass 'plan generation is deterministic'
    else
        fail 'plan generation is deterministic'
    fi

    assert_jq "$plan_one" \
        '.schema_version == 1 and (.approval_sha256 | length) == 64 and (.providers | length) == 2 and (.providers | all(has("capability_gaps"))) and (.tools | keys == ["chezmoi", "jq", "yq"])' \
        'plan records its schema, providers, and approval hash'

    if grep -q 'fixture-existing-secret' "$plan_one"; then
        fail 'plan never renders existing secret values'
    else
        pass 'plan never renders existing secret values'
    fi
}

test_apply_requires_exact_hash_and_preserves_unknown_fields() {
    local fixture="$1"
    local plan="${fixture}/apply-plan.json"
    local before="${fixture}/claude-before.json"
    local approval

    run_engine "$fixture" plan --workshop "$fixture" --output "$plan" >/dev/null
    command cp "${fixture}/home/.claude/settings.json" "$before"

    assert_failure 'apply rejects an incorrect approval hash' \
        run_engine "$fixture" apply --plan "$plan" --approve-sha256 incorrect
    if cmp -s "$before" "${fixture}/home/.claude/settings.json"; then
        pass 'incorrect approval leaves the provider untouched'
    else
        fail 'incorrect approval leaves the provider untouched'
    fi

    approval=$(jq -r '.approval_sha256' "$plan")
    assert_success 'apply accepts the exact plan hash' \
        run_engine "$fixture" apply --plan "$plan" --approve-sha256 "$approval"
    assert_jq "${fixture}/home/.claude/settings.json" \
        '.sandbox.enabled == true and .permissions.deny == ["Finder"] and .unknown.keep == "yes" and .apiKey == "fixture-existing-secret" and .model == "interactive-default"' \
        'apply converges declared fields and preserves unknown and secret fields'
    assert_success 'strict verification passes after convergence' \
        run_engine "$fixture" verify --strict
}

test_stale_plan_is_rejected() {
    local fixture="$1"
    local plan="${fixture}/stale-plan.json"
    local approval

    run_engine "$fixture" plan --workshop "$fixture" --provider claude --output "$plan" >/dev/null
    approval=$(jq -r '.approval_sha256' "$plan")
    jq '.concurrent = "user-change"' "${fixture}/home/.claude/settings.json" \
        > "${fixture}/home/.claude/settings.next.json"
    command mv "${fixture}/home/.claude/settings.next.json" \
        "${fixture}/home/.claude/settings.json"

    assert_failure 'apply rejects a plan when provider state changed after planning' \
        run_engine "$fixture" apply --plan "$plan" --approve-sha256 "$approval"
    assert_jq "${fixture}/home/.claude/settings.json" \
        '.concurrent == "user-change" and .sandbox.enabled == false' \
        'stale-plan rejection preserves the concurrent change'
}

test_provider_rollback_continues_other_providers() {
    local fixture="$1"
    local plan="${fixture}/rollback-plan.json"
    local before="${fixture}/claude-before-rollback.json"
    local approval

    run_engine "$fixture" plan --workshop "$fixture" --output "$plan" >/dev/null
    command cp "${fixture}/home/.claude/settings.json" "$before"
    approval=$(jq -r '.approval_sha256' "$plan")

    assert_failure 'a failed provider makes the overall apply fail' \
        env HARNESS_SETTINGS_TESTING=1 HARNESS_SETTINGS_TEST_FAIL_PROVIDER=claude \
        HARNESS_SETTINGS_HOME="${fixture}/home" \
        HARNESS_SETTINGS_REGISTRY="${fixture}/registry.yaml" \
        "$ENGINE" apply --plan "$plan" --approve-sha256 "$approval"

    if cmp -s "$before" "${fixture}/home/.claude/settings.json"; then
        pass 'failed provider is rolled back byte-for-byte'
    else
        fail 'failed provider is rolled back byte-for-byte'
    fi
    assert_jq "${fixture}/home/.codex/settings.json" \
        '.default_permissions == "workspace-local" and .unknown.keep == "codex"' \
        'apply continues and converges the remaining provider'
}

test_malformed_and_secret_bearing_inputs_fail_closed() {
    local fixture="$1"
    local before="${fixture}/malformed-before.json"

    printf '%s\n' '{not-json' > "${fixture}/home/.claude/settings.json"
    command cp "${fixture}/home/.claude/settings.json" "$before"
    assert_failure 'plan rejects malformed provider state' \
        run_engine "$fixture" plan --workshop "$fixture" --provider claude \
            --output "${fixture}/malformed-plan.json"
    if cmp -s "$before" "${fixture}/home/.claude/settings.json"; then
        pass 'malformed provider state remains untouched'
    else
        fail 'malformed provider state remains untouched'
    fi

    printf '%s\n' '{"valid":true}' > "${fixture}/home/.claude/settings.json"
    printf '%s\n' '{"authToken":"fixture-new-secret"}' > "${fixture}/policies/claude.json"
    assert_failure 'plan refuses secret-bearing tracked policy fields' \
        run_engine "$fixture" plan --workshop "$fixture" --provider claude \
            --output "${fixture}/secret-plan.json"
}

test_chezmoi_is_the_live_settings_writer() {
    local fixture="$1"
    local plan="${fixture}/chezmoi-plan.json"
    local approval

    assert_success 'plan accepts a declared chezmoi provider target' \
        run_chezmoi_engine "$fixture" plan --workshop "$fixture" --output "$plan"
    assert_jq "$plan" \
        '.providers[0].deployment == "chezmoi" and (.providers[0].managed_source_sha256 | length) == 64' \
        'plan pins the exact chezmoi source artifact'
    approval=$(jq -r '.approval_sha256' "$plan")
    assert_success 'apply delegates the approved target to chezmoi' \
        run_chezmoi_engine "$fixture" apply --plan "$plan" --approve-sha256 "$approval"
    assert_jq "${fixture}/home/.claude/settings.json" \
        '.sandbox.enabled == true and .unknown.keep == "yes" and .apiKey == "fixture-existing-secret"' \
        'chezmoi modifier converges policy without replacing provider-owned fields'
    assert_success 'strict verification accepts the chezmoi-deployed state' \
        run_chezmoi_engine "$fixture" verify --strict
}

test_chezmoi_toml_modifier_preserves_provider_state() {
    local fixture="$1"
    local plan="${fixture}/toml-plan.json"
    local approval

    assert_success 'plan normalizes a declared TOML provider without rendering source values' \
        run_chezmoi_engine "$fixture" plan --workshop "$fixture" --output "$plan"
    approval=$(jq -r '.approval_sha256' "$plan")
    assert_success 'apply delegates the approved TOML target to chezmoi' \
        run_chezmoi_engine "$fixture" apply --plan "$plan" --approve-sha256 "$approval"
    if yq -e \
        '.sandbox.enabled == true and .model == "interactive-default" and .unknown == "keep-me"' \
        "${fixture}/home/.grok/config.toml" >/dev/null 2>&1; then
        pass 'TOML modifier converges policy and preserves interactive and unknown state'
    else
        fail 'TOML modifier converges policy and preserves interactive and unknown state'
    fi
    assert_success 'strict verification accepts the TOML provider state' \
        run_chezmoi_engine "$fixture" verify --strict
}

test_capture_debt_blocks_strict_verification() {
    local fixture="$1"
    local debt="${fixture}/capture-debt"
    local approval

    run_engine "$fixture" plan --workshop "$fixture" --output "${fixture}/plan.json" >/dev/null
    approval=$(jq -r '.approval_sha256' "${fixture}/plan.json")
    run_engine "$fixture" apply --plan "${fixture}/plan.json" \
        --approve-sha256 "$approval" >/dev/null
    mkdir -p "$debt"
    printf '%s\n' '{"provider":"claude","capture_status":"failed"}' \
        > "${debt}/claude-fixture.json"

    if HARNESS_CAPTURE_DEBT_DIR="$debt" \
        run_engine "$fixture" verify --strict >/dev/null 2>&1; then
        fail 'persisted capture debt blocks strict verification'
    else
        pass 'persisted capture debt blocks strict verification'
    fi
}

test_scaffold_is_offline_and_idempotent() {
    local fixture="$1"
    local repo="${fixture}/repo"
    local first_hash
    local second_hash

    mkdir -p "$repo/.git"
    if PATH="/opt/homebrew/bin:/usr/bin:/bin" \
        run_engine "$fixture" scaffold --repo "$repo" >/dev/null 2>&1; then
        pass 'scaffold succeeds without any harness binary on PATH'
    else
        fail 'scaffold succeeds without any harness binary on PATH'
    fi
    assert_jq "${repo}/.harness/policy.json" \
        '.schema_version == 1 and .artifact.required_dynamic_test_unavailable == "fail" and .gui.finder == "deny"' \
        'scaffold installs the tracked truthfulness and GUI policy'
    first_hash=$(shasum -a 256 "${repo}/.harness/policy.json" | awk '{print $1}')
    run_engine "$fixture" scaffold --repo "$repo" >/dev/null
    second_hash=$(shasum -a 256 "${repo}/.harness/policy.json" | awk '{print $1}')
    if [[ "$first_hash" == "$second_hash" ]]; then
        pass 'scaffold is idempotent'
    else
        fail 'scaffold is idempotent'
    fi
}

if [[ ! -x "$ENGINE" ]]; then
    fail 'harness-settings engine exists and is executable'
fi

tmp="$(mktemp -d "${TMPDIR:-/tmp}/forge-provision-harness-settings.XXXXXX")"
trap 'command rm -rf "$tmp"' EXIT

fixture="${tmp}/deterministic"
make_registry "$fixture"
test_plan_is_deterministic_and_redacted "$fixture"

fixture="${tmp}/apply"
make_registry "$fixture"
test_apply_requires_exact_hash_and_preserves_unknown_fields "$fixture"

fixture="${tmp}/stale"
make_registry "$fixture"
test_stale_plan_is_rejected "$fixture"

fixture="${tmp}/rollback"
make_registry "$fixture"
test_provider_rollback_continues_other_providers "$fixture"

fixture="${tmp}/fail-closed"
make_registry "$fixture"
test_malformed_and_secret_bearing_inputs_fail_closed "$fixture"

fixture="${tmp}/chezmoi"
make_chezmoi_registry "$fixture"
test_chezmoi_is_the_live_settings_writer "$fixture"

fixture="${tmp}/chezmoi-toml"
make_chezmoi_toml_registry "$fixture"
test_chezmoi_toml_modifier_preserves_provider_state "$fixture"

fixture="${tmp}/capture-debt"
make_registry "$fixture"
test_capture_debt_blocks_strict_verification "$fixture"

fixture="${tmp}/scaffold"
make_registry "$fixture"
test_scaffold_is_offline_and_idempotent "$fixture"

if (( failures > 0 )); then
    echo "${failures} test(s) failed"
    exit 1
fi

echo 'All harness settings tests passed'

#!/bin/bash
# Plan, apply, and verify declared cross-harness settings without owning auth state.
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

REGISTRY="${HARNESS_SETTINGS_REGISTRY:-${FORGE_PROVISION_ROOT}/manifests/harness-settings.yaml}"
SETTINGS_HOME="${HARNESS_SETTINGS_HOME:-${HOME}}"
CHEZMOI_SOURCE="${HARNESS_SETTINGS_CHEZMOI_SOURCE:-${FORGE_PROVISION_ROOT%/*}/dotfiles}"
SECRET_KEY_PATTERN='api.?key|token|secret|password|credential|private.?key'
WORK=""

usage() {
    cat <<'USAGE'
Usage: scripts/configure/harness-settings.sh <command> [options]

Commands:
    plan --workshop <path> [--provider <name>] [--output <plan.json>]
    apply --plan <plan.json> --approve-sha256 <hash>
    verify [--provider <name>] [--strict]
    scaffold --repo <path>

`plan` and `verify` are read-only. `apply` changes only providers named in the
approved plan and refuses stale source or policy hashes. Authentication files
and credential stores are outside this tool's contract.
USAGE
}

cleanup() {
    if [[ -n "$WORK" && -d "$WORK" ]]; then
        command rm -rf "$WORK"
    fi
}

require_tools() {
    local missing=0
    local tool

    for tool in jq yq shasum; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            echo "fail:harness-settings (${tool} not on PATH)" >&2
            missing=1
        fi
    done

    [[ "$missing" -eq 0 ]]
}

make_work_dir() {
    [[ -n "$WORK" ]] && return 0
    WORK=$(mktemp -d "${TMPDIR:-/tmp}/harness-settings.XXXXXX") || {
        echo 'fail:harness-settings (could not create temporary directory)' >&2
        return 1
    }
    chmod 700 "$WORK"
    trap cleanup EXIT
}

sha256_file() {
    shasum -a 256 "$1" | awk '{print $1}'
}

tool_version() {
    local tool="$1"

    if ! command -v "$tool" >/dev/null 2>&1; then
        printf '%s' 'unavailable'
        return 0
    fi
    "$tool" --version 2>&1 | head -1 | tr -d '\r\n'
}

sha256_json() {
    jq -S -c '.' "$1" | shasum -a 256 | awk '{print $1}'
}

source_sha256() {
    if [[ -f "$1" ]]; then
        sha256_file "$1"
    else
        echo 'absent'
    fi
}

registry_json() {
    local output="$1"

    if [[ ! -f "$REGISTRY" ]]; then
        echo "fail:harness-settings (registry missing at ${REGISTRY})" >&2
        return 1
    fi
    if ! yq -o=json '.' "$REGISTRY" > "$output"; then
        echo "fail:harness-settings (registry is not valid YAML)" >&2
        return 1
    fi
    if ! jq -e '.schema_version == 1 and (.providers | type) == "object"' \
        "$output" >/dev/null 2>&1; then
        echo 'fail:harness-settings (unsupported registry schema)' >&2
        return 1
    fi
}

resolve_policy_path() {
    local path="$1"
    local root="${2:-registry}"
    local registry_dir="${REGISTRY%/*}"

    if [[ "$path" == /* ]]; then
        echo "$path"
    elif [[ "$root" == 'chezmoi' ]]; then
        echo "${CHEZMOI_SOURCE}/${path}"
    else
        echo "${registry_dir}/${path}"
    fi
}

resolve_source_path() {
    local path="$1"

    if [[ "$path" == /* ]]; then
        echo "$path"
    else
        echo "${SETTINGS_HOME}/${path}"
    fi
}

validate_json_file() {
    local path="$1"
    local label="$2"

    if ! jq -e 'type == "object"' "$path" >/dev/null 2>&1; then
        echo "fail:${label} (expected a valid JSON object at ${path})" >&2
        return 1
    fi
}

normalize_provider_file() {
    local format="$1"
    local path="$2"
    local output="$3"

    case "$format" in
        json)
            jq -S '.' "$path" > "$output"
            ;;
        toml)
            yq -p=toml -o=json '.' "$path" | jq -S '.' > "$output"
            ;;
        *) return 1 ;;
    esac
}

validate_provider_file() {
    local format="$1"
    local path="$2"
    local label="$3"
    local normalized="${WORK}/validate-${label}.json"

    if ! normalize_provider_file "$format" "$path" "$normalized" \
        || ! jq -e 'type == "object"' "$normalized" >/dev/null 2>&1; then
        echo "fail:${label} (expected a valid ${format} object at ${path})" >&2
        return 1
    fi
}

validate_policy() {
    local path="$1"
    local provider="$2"

    validate_json_file "$path" "${provider}-policy" || return 1
    if jq -e --arg pattern "$SECRET_KEY_PATTERN" \
        '[
            .. | objects | keys[]
            | select(contains("/") | not)
            | select(. != "*")
        ] | any(test($pattern; "i"))' \
        "$path" >/dev/null 2>&1; then
        echo "fail:${provider}-policy (secret-bearing key names are forbidden)" >&2
        return 1
    fi
}

provider_names() {
    local registry_file="$1"
    shift

    if [[ "$#" -gt 0 ]]; then
        printf '%s\n' "$@" | LC_ALL=C sort -u
    else
        jq -r '.providers | keys[]' "$registry_file"
    fi
}

provider_entry() {
    local registry_file="$1"
    local provider="$2"

    jq -e --arg provider "$provider" '.providers[$provider]' \
        "$registry_file" 2>/dev/null
}

plan_provider() {
    local registry_file="$1"
    local provider="$2"
    local output="$3"
    local definition="${WORK}/${provider}-definition.json"
    local source_path
    local policy_path
    local format
    local strategy
    local deployment
    local policy_root
    local managed_source=''
    local managed_source_hash=''
    local source_hash
    local policy_hash
    local base="${WORK}/${provider}-base.json"
    local merged="${WORK}/${provider}-merged.json"
    local status='change'

    if ! provider_entry "$registry_file" "$provider" > "$definition"; then
        echo "fail:harness-settings (unknown provider: ${provider})" >&2
        return 1
    fi

    format=$(jq -r '.format // ""' "$definition")
    strategy=$(jq -r '.strategy // ""' "$definition")
    deployment=$(jq -r '.deployment // "direct"' "$definition")
    policy_root=$(jq -r '.policy_root // "registry"' "$definition")
    source_path=$(resolve_source_path "$(jq -r '.source // ""' "$definition")")
    policy_path=$(resolve_policy_path \
        "$(jq -r '.policy // ""' "$definition")" "$policy_root")

    if [[ "$format" == 'json' && "$strategy" == 'json-deep-merge' ]]; then
        :
    elif [[ "$format" == 'toml' && "$strategy" == 'object-deep-merge' ]]; then
        :
    else
        echo "fail:${provider} (unsupported ${format}/${strategy} provider definition)" >&2
        return 1
    fi
    if [[ ! -f "$policy_path" ]]; then
        echo "fail:${provider} (policy missing at ${policy_path})" >&2
        return 1
    fi
    validate_policy "$policy_path" "$provider" || return 1

    if [[ "$deployment" == 'chezmoi' ]]; then
        managed_source="${CHEZMOI_SOURCE}/$(jq -r '.managed_source // ""' "$definition")"
        if [[ ! -f "$managed_source" ]]; then
            echo "fail:${provider} (chezmoi source missing at ${managed_source})" >&2
            return 1
        fi
        managed_source_hash=$(sha256_file "$managed_source")
    elif [[ "$deployment" != 'direct' ]]; then
        echo "fail:${provider} (unsupported deployment: ${deployment})" >&2
        return 1
    elif [[ "$format" != 'json' ]]; then
        echo "fail:${provider} (direct deployment supports JSON fixtures only)" >&2
        return 1
    fi

    if [[ -f "$source_path" ]]; then
        validate_provider_file "$format" "$source_path" "$provider" || return 1
        normalize_provider_file "$format" "$source_path" "$base"
    else
        printf '%s\n' '{}' > "$base"
    fi

    if ! jq -s '.[0] * .[1]' "$base" "$policy_path" > "$merged"; then
        echo "fail:${provider} (could not render desired state)" >&2
        return 1
    fi
    if cmp -s <(jq -S -c '.' "$base") <(jq -S -c '.' "$merged"); then
        status='converged'
    fi

    source_hash=$(source_sha256 "$source_path")
    policy_hash=$(sha256_file "$policy_path")

    jq -n \
        --arg name "$provider" \
        --arg deployment "$deployment" \
        --arg format "$format" \
        --arg strategy "$strategy" \
        --arg source "$source_path" \
        --arg source_sha256 "$source_hash" \
        --arg policy "$policy_path" \
        --arg policy_sha256 "$policy_hash" \
        --arg managed_source "$managed_source" \
        --arg managed_source_sha256 "$managed_source_hash" \
        --arg status "$status" \
        --slurpfile definition "$definition" \
        --slurpfile desired "$policy_path" '
        def leaf_paths:
            paths as $path
            | getpath($path) as $value
            | select(
                ($value | type) != "object"
                and (($value | type) != "array" or ($value | length) == 0)
            )
            | $path;
        {
            name: $name,
            deployment: $deployment,
            format: $format,
            strategy: $strategy,
            source: $source,
            source_sha256: $source_sha256,
            policy: $policy,
            policy_sha256: $policy_sha256,
            managed_source: $managed_source,
            managed_source_sha256: $managed_source_sha256,
            status: $status,
            capability_gaps: ($definition[0].capability_gaps // []),
            operations: [
                $desired[0]
                | leaf_paths as $path
                | {
                    path: ($path | map(tostring) | join(".")),
                    desired: getpath($path)
                }
            ]
        }' > "$output"
}

command_plan() {
    local workshop=''
    local output=''
    local registry_file
    local body
    local next
    local entry
    local approval
    local provider
    local providers=()

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --workshop)
                workshop="${2:-}"
                shift
                ;;
            --output)
                output="${2:-}"
                shift
                ;;
            --provider)
                providers+=("${2:-}")
                shift
                ;;
            *)
                echo "fail:harness-settings (unknown plan option: $1)" >&2
                return 2
                ;;
        esac
        shift
    done

    if [[ -z "$workshop" || ! -d "$workshop" ]]; then
        echo 'fail:harness-settings (plan requires an existing --workshop)' >&2
        return 2
    fi
    [[ -n "$output" ]] || output="${workshop}/private/harness-settings-plan.json"

    make_work_dir || return 1
    registry_file="${WORK}/registry.json"
    registry_json "$registry_file" || return 1
    body="${WORK}/plan-body.json"
    jq -n \
        --arg workshop "$workshop" \
        --arg registry "$REGISTRY" \
        --arg registry_sha256 "$(sha256_file "$REGISTRY")" \
        --arg chezmoi_version "$(tool_version chezmoi)" \
        --arg jq_version "$(tool_version jq)" \
        --arg yq_version "$(tool_version yq)" \
        '{
            schema_version: 1,
            workshop: $workshop,
            registry: $registry,
            registry_sha256: $registry_sha256,
            tools: {
                chezmoi: $chezmoi_version,
                jq: $jq_version,
                yq: $yq_version
            },
            providers: []
        }' > "$body"

    while IFS= read -r provider; do
        [[ -n "$provider" ]] || continue
        entry="${WORK}/${provider}-plan.json"
        next="${WORK}/plan-next.json"
        plan_provider "$registry_file" "$provider" "$entry" || return 1
        if ! jq --slurpfile entry "$entry" '.providers += $entry' "$body" > "$next"; then
            echo "fail:harness-settings (could not assemble ${provider} plan)" >&2
            return 1
        fi
        command mv "$next" "$body"
    done < <(provider_names "$registry_file" "${providers[@]}")

    if ! jq -e '.providers | length > 0' "$body" >/dev/null 2>&1; then
        echo 'fail:harness-settings (plan selected no providers)' >&2
        return 1
    fi

    approval=$(sha256_json "$body")
    mkdir -p "${output%/*}"
    if ! jq -S --arg approval "$approval" '. + {approval_sha256: $approval}' \
        "$body" > "$output"; then
        echo "fail:harness-settings (could not write ${output})" >&2
        return 1
    fi

    echo "ok:harness-settings-plan (${output})"
    echo "approval-sha256:${approval}"
}

file_mode() {
    local path="$1"

    if stat -f '%Lp' "$path" >/dev/null 2>&1; then
        stat -f '%Lp' "$path"
    else
        stat -c '%a' "$path"
    fi
}

restore_provider() {
    local source_path="$1"
    local source_exists="$2"
    local backup="$3"
    local original_mode="$4"

    if [[ "$source_exists" -eq 1 ]]; then
        command cp "$backup" "$source_path"
        chmod "$original_mode" "$source_path"
    else
        command rm -f "$source_path"
    fi
}

provider_matches_policy() {
    local format="$1"
    local source_path="$2"
    local policy_path="$3"
    local merged="$4"
    local normalized="${WORK}/policy-source-${format}.json"

    if ! normalize_provider_file "$format" "$source_path" "$normalized" \
        || ! jq -s '.[0] * .[1]' "$normalized" "$policy_path" > "$merged"; then
        return 1
    fi
    cmp -s <(jq -S -c '.' "$normalized") <(jq -S -c '.' "$merged")
}

apply_provider() {
    local entry="$1"
    local provider
    local source_path
    local policy_path
    local expected_source_hash
    local expected_policy_hash
    local deployment
    local managed_source
    local expected_managed_source_hash
    local format
    local actual_source_hash
    local actual_policy_hash
    local source_dir
    local source_exists=0
    local original_mode=''
    local backup
    local base
    local rendered

    provider=$(jq -r '.name' "$entry")
    deployment=$(jq -r '.deployment // "direct"' "$entry")
    format=$(jq -r '.format' "$entry")
    source_path=$(jq -r '.source' "$entry")
    policy_path=$(jq -r '.policy' "$entry")
    expected_source_hash=$(jq -r '.source_sha256' "$entry")
    expected_policy_hash=$(jq -r '.policy_sha256' "$entry")
    managed_source=$(jq -r '.managed_source // ""' "$entry")
    expected_managed_source_hash=$(jq -r '.managed_source_sha256 // ""' "$entry")
    actual_source_hash=$(source_sha256 "$source_path")

    if [[ "$actual_source_hash" != "$expected_source_hash" ]]; then
        echo "fail:${provider} (source changed after planning; no changes applied)" >&2
        return 1
    fi
    if [[ ! -f "$policy_path" ]]; then
        echo "fail:${provider} (policy disappeared after planning)" >&2
        return 1
    fi
    actual_policy_hash=$(sha256_file "$policy_path")
    if [[ "$actual_policy_hash" != "$expected_policy_hash" ]]; then
        echo "fail:${provider} (policy changed after planning; no changes applied)" >&2
        return 1
    fi
    validate_policy "$policy_path" "$provider" || return 1

    if [[ "$deployment" == 'chezmoi' ]]; then
        if ! command -v chezmoi >/dev/null 2>&1; then
            echo "fail:${provider} (chezmoi not on PATH)" >&2
            return 1
        fi
        if [[ ! -f "$managed_source" \
            || "$(sha256_file "$managed_source")" != "$expected_managed_source_hash" ]]; then
            echo "fail:${provider} (chezmoi source changed after planning)" >&2
            return 1
        fi
    elif [[ "$deployment" != 'direct' ]]; then
        echo "fail:${provider} (unsupported deployment: ${deployment})" >&2
        return 1
    elif [[ "$format" != 'json' ]]; then
        echo "fail:${provider} (direct deployment supports JSON fixtures only)" >&2
        return 1
    fi

    backup="${WORK}/${provider}.backup"
    base="${WORK}/${provider}.base.json"
    if [[ -f "$source_path" ]]; then
        validate_provider_file "$format" "$source_path" "$provider" || return 1
        source_exists=1
        original_mode=$(file_mode "$source_path")
        command cp "$source_path" "$backup" || return 1
        chmod 600 "$backup"
        normalize_provider_file "$format" "$source_path" "$base"
    else
        printf '%s\n' '{}' > "$base"
    fi

    source_dir="${source_path%/*}"
    if ! mkdir -p "$source_dir"; then
        echo "fail:${provider} (could not create ${source_dir})" >&2
        return 1
    fi
    if [[ "$deployment" == 'chezmoi' ]]; then
        if ! chezmoi \
            --source "$CHEZMOI_SOURCE" \
            --destination "$SETTINGS_HOME" \
            --cache "${WORK}/chezmoi-cache" \
            --persistent-state "${WORK}/chezmoi-state.boltdb" \
            --no-tty \
            --force \
            --refresh-externals=never \
            apply "$source_path"; then
            restore_provider "$source_path" "$source_exists" "$backup" "$original_mode"
            command rm -f "$backup"
            echo "fail:${provider} (chezmoi apply failed; provider rolled back)" >&2
            return 1
        fi
    else
        rendered=$(mktemp "${source_dir}/.harness-settings.XXXXXX") || {
            echo "fail:${provider} (could not create provider-local temporary file)" >&2
            return 1
        }

        if ! jq -s '.[0] * .[1]' "$base" "$policy_path" > "$rendered" \
            || ! jq -e 'type == "object"' "$rendered" >/dev/null 2>&1 \
            || ! command mv "$rendered" "$source_path"; then
            command rm -f "$rendered"
            echo "fail:${provider} (render or atomic replace failed)" >&2
            return 1
        fi
    fi

    if [[ "$source_exists" -eq 1 ]]; then
        chmod "$original_mode" "$source_path"
    else
        chmod 600 "$source_path"
    fi

    if [[ "${HARNESS_SETTINGS_TESTING:-}" == '1' \
        && "${HARNESS_SETTINGS_TEST_FAIL_PROVIDER:-}" == "$provider" ]]; then
        restore_provider "$source_path" "$source_exists" "$backup" "$original_mode"
        command rm -f "$backup"
        echo "fail:${provider} (test failpoint; provider rolled back)" >&2
        return 1
    fi

    if ! validate_provider_file "$format" "$source_path" "$provider" \
        || ! provider_matches_policy "$format" "$source_path" "$policy_path" \
            "${WORK}/${provider}.post-apply.json"; then
        restore_provider "$source_path" "$source_exists" "$backup" "$original_mode"
        command rm -f "$backup"
        echo "fail:${provider} (post-apply policy verification failed; provider rolled back)" >&2
        return 1
    fi

    command rm -f "$backup"
    echo "ok:${provider} (declared fields converged)"
    return 0
}

command_apply() {
    local plan=''
    local approved=''
    local recorded
    local calculated
    local provider_count
    local index=0
    local failures=0
    local entry

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --plan)
                plan="${2:-}"
                shift
                ;;
            --approve-sha256)
                approved="${2:-}"
                shift
                ;;
            *)
                echo "fail:harness-settings (unknown apply option: $1)" >&2
                return 2
                ;;
        esac
        shift
    done

    if [[ -z "$plan" || ! -f "$plan" || -z "$approved" ]]; then
        echo 'fail:harness-settings (apply requires --plan and --approve-sha256)' >&2
        return 2
    fi
    if ! jq -e '.schema_version == 1 and (.providers | type) == "array"' \
        "$plan" >/dev/null 2>&1; then
        echo 'fail:harness-settings (invalid plan schema)' >&2
        return 1
    fi

    recorded=$(jq -r '.approval_sha256 // ""' "$plan")
    calculated=$(jq -S -c 'del(.approval_sha256)' "$plan" | shasum -a 256 | awk '{print $1}')
    if [[ "$approved" != "$recorded" || "$recorded" != "$calculated" ]]; then
        echo 'fail:harness-settings (approval hash does not match the exact plan)' >&2
        return 1
    fi
    if [[ "$(source_sha256 "$(jq -r '.registry' "$plan")")" \
        != "$(jq -r '.registry_sha256' "$plan")" ]]; then
        echo 'fail:harness-settings (registry changed after planning)' >&2
        return 1
    fi

    make_work_dir || return 1
    provider_count=$(jq '.providers | length' "$plan")
    while [[ "$index" -lt "$provider_count" ]]; do
        entry="${WORK}/apply-${index}.json"
        jq ".providers[${index}]" "$plan" > "$entry"
        if ! apply_provider "$entry"; then
            failures=$((failures + 1))
        fi
        index=$((index + 1))
    done

    if [[ "$failures" -gt 0 ]]; then
        echo "fail:harness-settings-apply (${failures} provider transaction(s) failed)" >&2
        return 1
    fi
    echo "ok:harness-settings-apply (${provider_count} provider transaction(s))"
}

verify_provider() {
    local registry_file="$1"
    local provider="$2"
    local definition="${WORK}/verify-${provider}-definition.json"
    local source_path
    local policy_path
    local policy_root
    local format
    local merged="${WORK}/verify-${provider}-merged.json"

    if ! provider_entry "$registry_file" "$provider" > "$definition"; then
        echo "fail:${provider} (provider is not declared)"
        return 1
    fi
    source_path=$(resolve_source_path "$(jq -r '.source // ""' "$definition")")
    format=$(jq -r '.format // ""' "$definition")
    policy_root=$(jq -r '.policy_root // "registry"' "$definition")
    policy_path=$(resolve_policy_path \
        "$(jq -r '.policy // ""' "$definition")" "$policy_root")

    if [[ ! -f "$source_path" ]]; then
        echo "fail:${provider} (settings file missing at ${source_path})"
        return 1
    fi
    validate_provider_file "$format" "$source_path" "$provider" || return 1
    validate_policy "$policy_path" "$provider" || return 1
    if ! provider_matches_policy "$format" "$source_path" "$policy_path" "$merged"; then
        echo "fail:${provider} (declared fields have drifted)"
        return 1
    fi

    echo "ok:${provider} (declared fields match policy)"
    return 0
}

command_verify() {
    local strict=0
    local registry_file
    local failures=0
    local provider
    local providers=()
    local capture_debt_dir="${HARNESS_CAPTURE_DEBT_DIR:-${HOME}/.local/state/harness-run/capture-debt}"
    local capture_debt_count=0

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --strict) strict=1 ;;
            --provider)
                providers+=("${2:-}")
                shift
                ;;
            *)
                echo "fail:harness-settings (unknown verify option: $1)" >&2
                return 2
                ;;
        esac
        shift
    done

    make_work_dir || return 1
    registry_file="${WORK}/verify-registry.json"
    registry_json "$registry_file" || return 1

    while IFS= read -r provider; do
        [[ -n "$provider" ]] || continue
        if ! verify_provider "$registry_file" "$provider"; then
            failures=$((failures + 1))
        fi
    done < <(provider_names "$registry_file" "${providers[@]}")

    if [[ -d "$capture_debt_dir" ]]; then
        capture_debt_count=$(find "$capture_debt_dir" -type f -name '*.json' | wc -l | tr -d ' ')
    fi
    if [[ "$capture_debt_count" -gt 0 ]]; then
        echo "fail:capture-debt (${capture_debt_count} failed capture(s) require recovery)"
        failures=$((failures + 1))
    else
        echo 'ok:capture-debt (none)'
    fi

    if [[ "$failures" -gt 0 ]]; then
        echo "fail:harness-settings-verify (${failures} provider(s) need attention)"
        [[ "$strict" -eq 1 ]] && return 1
        return 0
    fi
    echo 'ok:harness-settings-verify'
}

command_scaffold() {
    local repo=''
    local policy_source="${FORGE_PROVISION_ROOT}/manifests/harness-project/policy.json"
    local policy_target
    local temporary

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --repo)
                repo="${2:-}"
                shift
                ;;
            *)
                echo "fail:harness-settings (unknown scaffold option: $1)" >&2
                return 2
                ;;
        esac
        shift
    done

    if [[ -z "$repo" || ! -d "$repo" ]]; then
        echo 'fail:harness-settings (scaffold requires an existing --repo)' >&2
        return 2
    fi
    if [[ ! -d "$repo/.git" && ! -d "$repo/.jj" ]]; then
        echo "fail:harness-settings (${repo} is not a Git or jj repository)" >&2
        return 1
    fi
    validate_json_file "$policy_source" 'harness-project-policy' || return 1

    policy_target="${repo}/.harness/policy.json"
    mkdir -p "${policy_target%/*}" || return 1
    temporary=$(mktemp "${policy_target%/*}/.policy.XXXXXX") || return 1
    command cp "$policy_source" "$temporary" || {
        command rm -f "$temporary"
        return 1
    }

    if [[ -f "$policy_target" ]] && cmp -s "$temporary" "$policy_target"; then
        command rm -f "$temporary"
        echo "skip:harness-scaffold (${repo} already matches policy)"
    else
        command mv "$temporary" "$policy_target"
        echo "ok:harness-scaffold (${policy_target})"
    fi

    if ! jq -e \
        '.schema_version == 1
         and .gui.finder == "deny"
         and .artifact.required_dynamic_test_unavailable == "fail"' \
        "$policy_target" >/dev/null 2>&1; then
        echo 'fail:harness-scaffold (offline policy verification failed)' >&2
        return 1
    fi
    echo 'ok:harness-scaffold-verify (offline; no model calls)'
}

main() {
    local command_name="${1:-}"
    [[ -n "$command_name" ]] && shift

    case "$command_name" in
        plan|apply|verify|scaffold) : ;;
        -h|--help|'')
            usage
            return 0
            ;;
        *)
            echo "fail:harness-settings (unknown command: ${command_name})" >&2
            usage
            return 2
            ;;
    esac

    require_tools || return 1

    case "$command_name" in
        plan) command_plan "$@" ;;
        apply) command_apply "$@" ;;
        verify) command_verify "$@" ;;
        scaffold) command_scaffold "$@" ;;
    esac
}

main "$@"

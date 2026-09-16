#!/bin/bash
# Regression tests for the GnuPG colon-format parsers behind
# scripts/configure/gpg-signing.sh and scripts/verify/signing.sh. The fixtures
# are recorded gpg output with synthetic identities and fingerprints: two cards
# with a signing subkey each, an offline primary key, an on-disk signing key,
# and an expired one.
# Source: https://github.com/N4M3Z/forge-provision

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
FIXTURES="${ROOT}/tests/fixtures/gpg"
source "${ROOT}/scripts/lib/gpg.sh"

failures=0

fail() {
    echo "FAIL: $1"
    failures=$((failures + 1))
}

pass() {
    echo "PASS: $1"
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local label="$3"

    if [[ "${expected}" == "${actual}" ]]; then
        pass "${label}"
    else
        fail "${label}"
        echo "      expected: ${expected}"
        echo "      actual:   ${actual}"
    fi
}

CARD_B_SIGNING="B2B2B2B2B2B2B2B2B2B2B2B20B0B0B0B0B0B0B02"
CARD_A_SIGNING_LINE="A3A3A3A3A3A3A3A3A3A3A3A30A0A0A0A0A0A0A03 D2760001240102010006100000010000 Alice Example <alice@example.com>"
CARD_B_SIGNING_LINE="${CARD_B_SIGNING} D2760001240100000006200000020000 Alice Example <alice@work.example.com>"

test_card_signature_fingerprint() {
    assert_equals "${CARD_B_SIGNING}" \
        "$(gpg_card_signature_fingerprint < "${FIXTURES}/card-status.txt")" \
        'Card signature fingerprint is read from the fpr record'
    assert_equals "" \
        "$(gpg_card_signature_fingerprint < /dev/null)" \
        'No card present yields no fingerprint'
}

test_usable_signing_keys() {
    assert_equals "$(cat "${FIXTURES}/usable-signing-keys.txt")" \
        "$(gpg_usable_signing_keys < "${FIXTURES}/secret-keys.txt")" \
        'Usable signing keys keep card and disk signing keys and drop offline, expired, and non-signing ones'
}

test_match_signing_key() {
    local usable
    usable="$(cat "${FIXTURES}/usable-signing-keys.txt")"

    assert_equals "${CARD_B_SIGNING_LINE}" \
        "$(printf '%s\n' "${usable}" | gpg_match_signing_key "0x${CARD_B_SIGNING}!")" \
        'A pinned 0x<fingerprint>! resolves to its key'
    assert_equals "${CARD_A_SIGNING_LINE}" \
        "$(printf '%s\n' "${usable}" | gpg_match_signing_key "0a0a0a0a0a0a0a03")" \
        'A lowercase long key id resolves to its key'
    assert_equals "" \
        "$(printf '%s\n' "${usable}" | gpg_match_signing_key "0xEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE")" \
        'A key id from another machine resolves to nothing'
    assert_equals "" \
        "$(printf '%s\n' "${usable}" | gpg_match_signing_key "")" \
        'An empty key id resolves to nothing'
}

test_key_location_label() {
    assert_equals "card 20000002" \
        "$(gpg_key_location_label D2760001240100000006200000020000)" \
        'Card serial is read from the application id'
    assert_equals "disk" \
        "$(gpg_key_location_label +)" \
        'On-disk keys are labelled disk'
}

test_card_signature_fingerprint
test_usable_signing_keys
test_match_signing_key
test_key_location_label

if (( failures > 0 )); then
    echo "${failures} test(s) failed"
    exit 1
fi

echo 'All GnuPG signing tests passed'

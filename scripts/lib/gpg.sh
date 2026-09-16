#!/bin/bash
# GnuPG colon-format parsers shared by scripts/configure/gpg-signing.sh and
# scripts/verify/signing.sh. Every function reads gpg --with-colons output from
# stdin, so the tests feed recorded output and never need a card or a keyring.
# Field positions follow doc/DETAILS in the GnuPG source tree.
# Source: https://github.com/N4M3Z/forge-provision

# Fingerprint in the signature slot of the card gpg currently sees.
# Input: gpg --card-status --with-colons
# Output: the fingerprint, or nothing when no card is present or the slot is empty.
gpg_card_signature_fingerprint() {
    awk -F: '$1 == "fpr" { print $2; exit }'
}

# Signing keys whose private material gpg can reach: stored on disk ("+") or on
# a card (reported as the card's application id). A "#" marks a secret that is
# absent, which is how an offline primary key appears next to its card-resident
# subkeys. Expired keys are left out because gpg refuses to sign with them.
# Input: gpg --list-secret-keys --with-colons
# Output: one line per key, "<fingerprint> <location> <primary user id>".
gpg_usable_signing_keys() {
    awk -F: -v current_time="$(date +%s)" '
        function flush() {
            for (position = 1; position <= count; position++) {
                print candidates[position], primary_uid
            }
            count = 0
            primary_uid = ""
        }
        $1 == "sec" { flush() }
        $1 == "sec" || $1 == "ssb" {
            expiry = $7
            capability = $12
            location = $15
            awaiting_fingerprint = 1
            next
        }
        $1 == "fpr" && awaiting_fingerprint {
            awaiting_fingerprint = 0
            unexpired = (expiry == "" || expiry + 0 > current_time + 0)
            if (capability ~ /s/ && location != "#" && unexpired) {
                candidates[++count] = $10 " " location
            }
            next
        }
        $1 == "uid" && primary_uid == "" { primary_uid = $10 }
        END { flush() }
    '
}

# The line of gpg_usable_signing_keys output whose fingerprint ends with the
# given key id, so a full fingerprint, a long id and a short id all resolve. A
# leading "0x" and a trailing "!" are accepted as git and gpg write them.
# Input: gpg_usable_signing_keys output
# Output: the first matching line, or nothing.
gpg_match_signing_key() {
    local key_id="$1"
    key_id="${key_id#0x}"
    key_id="${key_id%!}"
    key_id="$(printf '%s' "${key_id}" | tr '[:lower:]' '[:upper:]')"
    awk -v key_id="${key_id}" '
        key_id != "" && substr($1, length($1) - length(key_id) + 1) == key_id { print; exit }
    '
}

# Human-readable form of the location field of gpg_usable_signing_keys: "disk",
# or "card <serial>" read from the OpenPGP application id, where the serial
# number occupies bytes 11 to 14.
gpg_key_location_label() {
    case "$1" in
        +) printf 'disk' ;;
        *) printf 'card %s' "${1:20:8}" ;;
    esac
}

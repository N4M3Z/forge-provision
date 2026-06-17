GitHub publishes every key registered on an account at unauthenticated public endpoints: GPG keys at `github.com/<user>.gpg`, SSH public keys at `github.com/<user>.keys`. Anything embedded in those keys is public — GPG UID names and email addresses included. Committing with a `noreply` address hides nothing while the key UID carries the real email.

Consequences for key hygiene:

- Treat GPG UIDs as public identity statements. Only put names and addresses there that may appear on the open web.
- Commit verification requires the committer email to match a UID on the signing key AND a verified account email. A mismatch shows "Unverified" with reason `bad_email` even when the signature is cryptographically valid. Check with: `gh api repos/<owner>/<repo>/commits/<sha> --jq '.commit.verification'`.
- Adding a UID requires the primary certify key `[C]`. With a YubiKey setup the card holds only subkeys (`ssb>`); a `sec#` stub means the primary lives in the offline backup, and UID changes are an offline ceremony: add UID there, `gpg --armor --export`, re-add the block on GitHub, import the updated block into the daily keyring. GitHub re-verifies existing commits retroactively once the key matches.
- Key blocks have no sync: every keyring and GitHub each hold an independent copy. An update is only visible where the updated block was explicitly imported or pasted.

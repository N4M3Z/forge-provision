"""Stage and verify the existing pass store. Password bytes never reach logs or files."""

import argparse
import fcntl
import hashlib
import hmac
import json
import os
import re
import resource
import shutil
import stat
import subprocess
import sys
import tempfile
from pathlib import Path, PurePosixPath

SOURCE = Path.home() / ".password-store"
GPG_HOME = Path.home() / ".gnupg"
VAULTS = Path.home() / ".local/share/keyvaults"
OUTPUT = VAULTS / "openpgp-public"
PUBLIC = OUTPUT / "openpgp-public.asc"
PRIMARY = NEW = OLD = OLD_PRIMARY = TARGET_CARD = SOURCE_CARD = TARGET_SERIAL = ""
CONFIG = {}
GPG = [
    "gpg",
    "--homedir",
    str(GPG_HOME),
    "--batch",
    "--no-auto-key-retrieve",
    "--auto-key-locate",
    "clear",
    "--no-auto-key-import",
]


class MigrationError(Exception):
    pass


def configure(config):
    """Load explicit operator settings; saved runs retain the same configuration."""
    global SOURCE, GPG_HOME, VAULTS, OUTPUT, PUBLIC, GPG, CONFIG
    global PRIMARY, NEW, OLD, OLD_PRIMARY, TARGET_CARD, SOURCE_CARD, TARGET_SERIAL
    if not isinstance(config, dict):
        raise MigrationError("Configuration must be a JSON object.")
    required = {
        "old_primary",
        "old_encryption",
        "old_card",
        "new_primary",
        "new_encryption",
        "new_card",
        "new_serial",
        "public_certificate",
    }
    paths = {
        "source": SOURCE,
        "gpg_home": GPG_HOME,
        "vaults": VAULTS,
        "output_dir": OUTPUT,
    }
    if required - config.keys() or config.keys() - (required | paths.keys()):
        raise MigrationError(
            "Configuration has missing or unknown fields; see the migration guide."
        )
    normalized = dict(config)
    for name in ("old_primary", "old_encryption", "new_primary", "new_encryption"):
        value = str(config[name]).upper()
        if not re.fullmatch(r"[0-9A-F]{40}", value):
            raise MigrationError(f"{name} must be a full 40-character fingerprint.")
        normalized[name] = value
    if (
        len(
            {
                normalized[n]
                for n in (
                    "old_primary",
                    "old_encryption",
                    "new_primary",
                    "new_encryption",
                )
            }
        )
        != 4
    ):
        raise MigrationError(
            "Old and new primary/encryption fingerprints must be distinct."
        )
    for name in ("old_card", "new_card"):
        value = str(config[name]).upper()
        if not re.fullmatch(r"D27600012401[0-9A-F]{20}", value):
            raise MigrationError(
                f"{name} must be the full OpenPGP application ID, not a decimal serial."
            )
        normalized[name] = value
    if normalized["old_card"] == normalized["new_card"]:
        raise MigrationError("The staged migration requires two distinct cards.")
    if not re.fullmatch(r"[0-9]{1,10}", str(config["new_serial"])):
        raise MigrationError(
            "new_serial must be the decimal serial from ykman list --serials."
        )
    normalized["new_serial"] = str(config["new_serial"])
    for name, default in {**paths, "public_certificate": None}.items():
        raw = config.get(name, default)
        if not isinstance(raw, (str, Path)) or not str(raw):
            raise MigrationError(f"{name} must be a filesystem path.")
        path = Path(os.path.abspath(Path(raw).expanduser()))
        if any(p.is_symlink() for p in (path, *path.parents)):
            raise MigrationError(f"Resolve symlinks in {name} before migrating.")
        normalized[name] = str(path)
    source = Path(normalized["source"])
    if source == Path(source.anchor):
        raise MigrationError("The store cannot be the filesystem root.")
    for name in ("vaults", "output_dir", "gpg_home", "public_certificate"):
        path = Path(normalized[name])
        if path.is_relative_to(source) or source.is_relative_to(path):
            raise MigrationError(f"{name} must be separate from the password store.")
    SOURCE, GPG_HOME, VAULTS, OUTPUT, PUBLIC = (
        Path(normalized[n])
        for n in ("source", "gpg_home", "vaults", "output_dir", "public_certificate")
    )
    PRIMARY, NEW, OLD_PRIMARY, OLD = (
        normalized[n]
        for n in ("new_primary", "new_encryption", "old_primary", "old_encryption")
    )
    TARGET_CARD, SOURCE_CARD, TARGET_SERIAL = (
        normalized[n] for n in ("new_card", "old_card", "new_serial")
    )
    GPG = [
        "gpg",
        "--homedir",
        str(GPG_HOME),
        "--batch",
        "--no-auto-key-retrieve",
        "--auto-key-locate",
        "clear",
        "--no-auto-key-import",
    ]
    CONFIG = normalized


def notice(message):
    print(message, flush=True)


def invoke(args, data=None, env=None):
    try:
        result = subprocess.run(
            [str(a) for a in args],
            input=data,
            capture_output=True,
            env=env,
            check=False,
        )
    except FileNotFoundError:
        raise MigrationError(
            f"Required tool '{Path(args[0]).name}' is missing. Restore it on PATH and retry."
        ) from None
    if result.returncode:
        # Do not log stdout, stderr, input, or entry names: these can contain secrets.
        details = []
        for line in result.stderr.splitlines():
            match = re.fullmatch(
                rb"\[GNUPG:\] (ERROR|FAILURE) ([A-Za-z_][A-Za-z0-9_.-]*) ([0-9]+)", line
            )
            if match:
                details.append(
                    match.group(1).decode()
                    + " "
                    + match.group(2).decode()
                    + " "
                    + match.group(3).decode()
                )
        for label in (
            "Timeout",
            "Operation cancelled",
            "No secret key",
            "Card error",
            "Bad PIN",
            "No pinentry",
            "Permission denied",
        ):
            if label.lower().encode() in result.stderr.lower():
                details.append(label)
        suffix = " " + "; ".join(details) if details else ""
        raise MigrationError(
            f"{Path(args[0]).name} failed (exit {result.returncode}).{suffix}"
        )
    return result


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def snapshot(root):
    if root.is_symlink() or not root.is_dir():
        raise MigrationError("The store must be a regular directory.")
    result = {}
    for path in sorted(root.rglob("*")):
        rel = path.relative_to(root).as_posix()
        info = path.lstat()
        if stat.S_ISREG(info.st_mode):
            result[rel] = {
                "kind": "file",
                "mode": stat.S_IMODE(info.st_mode),
                "hash": digest(path),
            }
        elif stat.S_ISDIR(info.st_mode):
            result[rel] = {"kind": "directory", "mode": stat.S_IMODE(info.st_mode)}
        else:
            raise MigrationError(
                "Symlinks and special files require separate inspection."
            )
        if rel.endswith(".lock") and ".git/" in rel:
            raise MigrationError(
                "A Git lock is present; stop other store operations first."
            )
    return result


def save_json(path, value):
    replace_bytes(path, (json.dumps(value, indent=2) + "\n").encode())


def sync_directory(path):
    descriptor = os.open(path, os.O_RDONLY)
    try:
        sync_descriptor(descriptor)
    finally:
        os.close(descriptor)


def sync_descriptor(descriptor):
    os.fsync(descriptor)
    if sys.platform == "darwin":
        fcntl.fcntl(descriptor, fcntl.F_FULLFSYNC)


def replace_bytes(path, data, mode=0o600):
    descriptor, name = tempfile.mkstemp(prefix=".openpgp-pass-write-", dir=path.parent)
    temporary = Path(name)
    try:
        with os.fdopen(descriptor, "wb") as stream:
            stream.write(data)
            os.fchmod(stream.fileno(), mode)
            sync_descriptor(stream.fileno())
        temporary.replace(path)
        sync_directory(path.parent)
    finally:
        temporary.unlink(missing_ok=True)


def read_journal(path):
    """Journals are private local input, never arbitrary paths to follow."""
    if path.is_symlink() or not path.is_file():
        raise MigrationError(
            "Missing or symlinked migration journal; preserve the run for inspection."
        )
    info = path.stat()
    if info.st_uid != os.getuid() or info.st_mode & 0o022:
        raise MigrationError(
            "Migration journals must be owned by you and not writable by others."
        )
    try:
        return json.loads(path.read_text())
    except (ValueError, UnicodeError) as exc:
        raise MigrationError(
            "Unreadable migration journal; preserve the run for inspection."
        ) from exc


def validate_run_directory(run):
    if run.is_symlink() or not run.is_dir() or any(p.is_symlink() for p in run.parents):
        raise MigrationError(
            "The migration directory must be a regular directory without symlinked parents."
        )
    info = run.stat()
    if info.st_uid != os.getuid() or info.st_mode & 0o077:
        raise MigrationError(
            "The migration directory must be owned by you with mode 0700."
        )
    for name in ("staged-store", "original-store"):
        path = run / name
        if path.is_symlink() or (path.exists() and not path.is_dir()):
            raise MigrationError(
                "A migration store directory was replaced; preserve the run for inspection."
            )


def validate_manifest(manifest):
    if not isinstance(manifest, dict):
        raise MigrationError("Invalid journal manifest.")
    for rel, metadata in manifest.items():
        if not isinstance(rel, str) or not rel or "\\" in rel or "\x00" in rel:
            raise MigrationError("Unsafe journal entry path.")
        path = PurePosixPath(rel)
        if (
            path.is_absolute()
            or path.as_posix() != rel
            or any(p in ("", ".", "..") for p in rel.split("/"))
        ):
            raise MigrationError("Unsafe journal entry path.")
        if not isinstance(metadata, dict) or metadata.get("kind") not in (
            "file",
            "directory",
        ):
            raise MigrationError("Invalid journal entry metadata.")
        expected = (
            {"kind", "mode", "hash"} if metadata["kind"] == "file" else {"kind", "mode"}
        )
        if (
            set(metadata) != expected
            or type(metadata["mode"]) is not int
            or not 0 <= metadata["mode"] <= 0o7777
        ):
            raise MigrationError("Invalid journal entry mode or fields.")
        if "hash" in metadata and (
            not isinstance(metadata["hash"], str)
            or not re.fullmatch(r"[0-9a-f]{64}", metadata["hash"])
        ):
            raise MigrationError("Invalid journal ciphertext digest.")


def load_run(run):
    validate_run_directory(run)
    baseline = read_journal(run / "baseline.json")
    state = read_journal(run / "state.json")
    required = {
        "source",
        "recipient",
        "original",
        "entries",
        "verified",
        "phase",
        "configuration",
    }
    optional = {
        "staged_manifest",
        "gpg_config_edit",
        "normal_pass_read_passed",
        "pass_read_entry_count",
        "target_only_present_for_pass_check",
    }
    if (
        not isinstance(state, dict)
        or required - state.keys()
        or state.keys() - (required | optional)
    ):
        raise MigrationError("Migration journal has missing or unknown fields.")
    if not isinstance(baseline, dict) or set(baseline) != {"configuration", "original"}:
        raise MigrationError("Invalid preparation baseline.")
    if (
        state["configuration"] != CONFIG
        or baseline["configuration"] != CONFIG
        or state["original"] != baseline["original"]
    ):
        raise MigrationError(
            "Journal configuration or original manifest differs from the preparation baseline."
        )
    if state["source"] != str(SOURCE) or state["recipient"] != PRIMARY:
        raise MigrationError(
            "Saved migration belongs to a different store or recipient."
        )
    if state["phase"] not in (
        "prepared",
        "finalizing",
        "verified",
        "activating",
        "activated",
    ):
        raise MigrationError("Unknown migration phase.")
    for name in ("original", "verified", "staged_manifest"):
        if name in state:
            validate_manifest(state[name])
    entries = state["entries"]
    expected = [
        rel
        for rel, meta in state["original"].items()
        if meta["kind"] == "file"
        and rel.endswith(".gpg")
        and ".git" not in PurePosixPath(rel).parts
    ]
    if (
        not isinstance(entries, list)
        or not entries
        or entries != expected
        or set(state["verified"]) - set(entries)
    ):
        raise MigrationError(
            "Encrypted journal entries differ from the original manifest."
        )
    for name in ("normal_pass_read_passed", "target_only_present_for_pass_check"):
        if name in state and type(state[name]) is not bool:
            raise MigrationError("Invalid verification flag in journal.")
    if "pass_read_entry_count" in state and (
        type(state["pass_read_entry_count"]) is not int
        or state["pass_read_entry_count"] not in (0, 1)
    ):
        raise MigrationError("Invalid pass verification count.")
    if "gpg_config_edit" in state:
        edit = state["gpg_config_edit"]
        if (
            not isinstance(edit, dict)
            or set(edit) != {"existed", "mode", "before", "after"}
            or type(edit["existed"]) is not bool
            or type(edit["mode"]) is not int
            or not 0 <= edit["mode"] <= 0o7777
        ):
            raise MigrationError("Invalid GPG configuration journal.")
        if any(
            not isinstance(edit[n], str) or not re.fullmatch(r"[0-9a-f]{64}", edit[n])
            for n in ("before", "after")
        ):
            raise MigrationError("Invalid GPG configuration digest.")
    return state


def unchanged_source(state):
    if snapshot(SOURCE) != state["original"]:
        raise MigrationError(
            "The live store changed since staging. It has not been replaced."
        )


def prepare():
    original = snapshot(SOURCE)
    ids = [rel for rel in original if Path(rel).name == ".gpg-id"]
    recipients = (SOURCE / ".gpg-id").read_text().split() if ids == [".gpg-id"] else []
    recipient = recipients[0].removeprefix("0x").upper() if len(recipients) == 1 else ""
    if not re.fullmatch(
        r"(?:[0-9A-F]{8}|[0-9A-F]{16}|[0-9A-F]{40})", recipient
    ) or not any(fpr.endswith(recipient) for fpr in (OLD_PRIMARY, OLD)):
        raise MigrationError(
            "Recipient configuration changed; inspect before migration."
        )
    if any(rel.endswith(".gpg-id.sig") for rel in original):
        raise MigrationError("Signed recipients require a separate signing step.")
    if (
        not (SOURCE / ".git").is_dir()
        or (SOURCE / ".git/objects/info/alternates").exists()
    ):
        raise MigrationError("Expected a self-contained Git repository.")
    for key in (
        "PASSWORD_STORE_DIR",
        "PASSWORD_STORE_KEY",
        "PASSWORD_STORE_GPG_OPTS",
        "PASSWORD_STORE_SIGNING_KEY",
        "GNUPGHOME",
    ):
        if os.environ.get(key):
            raise MigrationError(f"Unexpected environment override: {key}.")
    VAULTS.mkdir(parents=True, mode=0o700, exist_ok=True)
    if SOURCE.stat().st_dev != VAULTS.stat().st_dev:
        raise MigrationError(
            "Staging and the source must be on the same filesystem for activation."
        )
    run = Path(tempfile.mkdtemp(prefix="password-store-migration-", dir=VAULTS))
    stage = run / "staged-store"
    shutil.copytree(SOURCE, stage, symlinks=True)
    if snapshot(stage) != original or snapshot(SOURCE) != original:
        raise MigrationError(
            "Store changed during copying; the live store is preserved."
        )
    entries = [
        rel
        for rel, metadata in original.items()
        if metadata["kind"] == "file"
        and rel.endswith(".gpg")
        and ".git" not in Path(rel).parts
    ]
    if not entries:
        raise MigrationError("No encrypted entries found.")
    state = {
        "source": str(SOURCE),
        "recipient": PRIMARY,
        "original": original,
        "entries": entries,
        "verified": {},
        "phase": "prepared",
        "configuration": CONFIG,
    }
    save_json(run / "baseline.json", {"configuration": CONFIG, "original": original})
    save_json(run / "state.json", state)
    notice(
        f"Prepared {len(entries)} encrypted entries, including all Git and uncommitted files."
    )
    notice(f"Migration directory: {run}")


def prepare_key(run):
    state = load_run(run)
    unchanged_source(state)
    public = PUBLIC
    listing = invoke(
        [*GPG, "--with-colons", "--with-subkey-fingerprint", "--show-keys", public]
    ).stdout.decode()
    keys = []
    record = None
    for line in listing.splitlines():
        fields = line.split(":")
        if fields[0] in ("pub", "sub"):
            record = fields
        elif fields[0] == "fpr" and record:
            keys.append((record[0], fields[9], record[11]))
            record = None
    if [fpr for kind, fpr, _ in keys if kind == "pub"] != [PRIMARY] or not any(
        kind == "sub" and fpr == NEW and "e" in usage for kind, fpr, usage in keys
    ):
        raise MigrationError("Unexpected public certificate.")
    trust_backup = run / "ownertrust-before.txt"
    if not trust_backup.exists():
        trust_backup.write_bytes(invoke([*GPG, "--export-ownertrust"]).stdout)
    invoke([*GPG, "--import", public])
    invoke([*GPG, "--import-ownertrust"], f"{PRIMARY}:6:\n".encode())
    learn_card(TARGET_CARD)
    verify_bindings()
    notice(
        "New public certificate imported, own-key trust set, target card references learned."
    )


def learn_card(serial):
    result = invoke(
        ["gpg-connect-agent", "--homedir", GPG_HOME, f"LEARN {serial}", "/bye"]
    )
    if any(line.startswith(b"ERR ") for line in result.stdout.splitlines()):
        raise MigrationError(
            "The required card is not available to GPG. No PIN guess was attempted."
        )


def verify_bindings():
    text = invoke(
        [
            *GPG,
            "--with-colons",
            "--with-subkey-fingerprint",
            "--list-secret-keys",
            OLD_PRIMARY,
            PRIMARY,
        ]
    ).stdout.decode()
    found = {}
    record = None
    for line in text.splitlines():
        fields = line.split(":")
        if fields[0] in ("sec", "ssb"):
            record = fields
        elif fields[0] == "fpr" and record:
            if fields[9] in (OLD, NEW):
                found[fields[9]] = record[14] if len(record) > 14 else ""
            record = None
    if found != {OLD: SOURCE_CARD, NEW: TARGET_CARD}:
        raise MigrationError(
            "Encryption keys must reference the expected old key and target cards."
        )


def decrypt(path, fingerprint):
    result = invoke(
        [
            *GPG,
            "--status-fd",
            "2",
            "--default-key",
            fingerprint + "!",
            "--try-secret-key",
            fingerprint + "!",
            "--output",
            "-",
            "--decrypt",
            path,
        ]
    )
    lines = result.stderr.splitlines()
    actual = [
        line.split()[2].decode()
        for line in lines
        if line.startswith(b"[GNUPG:] DECRYPTION_KEY ")
    ]
    if actual != [fingerprint] or b"[GNUPG:] DECRYPTION_OKAY" not in lines:
        raise MigrationError("Decryption did not report success with the intended key.")
    return result.stdout


def verify_stage(run, state, complete=False):
    actual = snapshot(run / "staged-store")
    if set(actual) != set(state["original"]):
        raise MigrationError("Staged store inventory changed unexpectedly.")
    for rel, original in state["original"].items():
        if rel in state["entries"]:
            if rel in state["verified"] and actual[rel] != state["verified"][rel]:
                raise MigrationError("A previously verified ciphertext changed.")
            if complete and rel not in state["verified"]:
                raise MigrationError("Not every entry has been verified.")
        elif rel == ".gpg-id" and (
            complete or set(state["verified"]) == set(state["entries"])
        ):
            recipient = (run / "staged-store" / rel).read_text()
            if recipient == PRIMARY + "\n":
                continue
            if complete or actual[rel] != original:
                raise MigrationError(
                    "Staged recipient differs from the new primary fingerprint."
                )
        elif actual[rel] != original:
            raise MigrationError(
                "Non-password content or Git metadata changed in staging."
            )
    return actual


def finalize_staging(run, state):
    if set(state["verified"]) != set(state["entries"]):
        raise MigrationError("Not every entry has been verified.")
    unchanged_source(state)
    verify_stage(run, state)
    state["phase"] = "finalizing"
    save_json(run / "state.json", state)
    # Keep the temporary outside the store so interruption cannot add an entry.
    temporary = run / "recipient.tmp"
    with temporary.open("w") as stream:
        stream.write(PRIMARY + "\n")
        stream.flush()
        sync_descriptor(stream.fileno())
    temporary.chmod(0o600)
    temporary.replace(run / "staged-store/.gpg-id")
    sync_directory(run / "staged-store")
    state["staged_manifest"] = verify_stage(run, state, complete=True)
    state["phase"] = "verified"
    save_json(run / "state.json", state)
    notice(
        f"READY: all {len(state['entries'])} entries verified. Live store is still unchanged."
    )


def migrate(run):
    state = load_run(run)
    if state["phase"] == "activated":
        raise MigrationError("This migration is already active.")
    unchanged_source(state)
    if state["phase"] == "verified":
        verify_stage(run, state, complete=True)
        notice("All entries are already verified; activation is the next step.")
        return
    verify_stage(run, state)
    if set(state["verified"]) == set(state["entries"]):
        finalize_staging(run, state)
        return
    learn_card(SOURCE_CARD)
    learn_card(TARGET_CARD)
    verify_bindings()
    total = len(state["entries"])
    stage = run / "staged-store"
    for index, rel in enumerate(state["entries"], 1):
        if rel in state["verified"]:
            notice(f"✓ {index}/{total} already verified")
            continue
        notice(
            f"→ {index}/{total}: decrypting original with old key; enter its PIN locally if requested."
        )
        plain = decrypt(SOURCE / rel, OLD)
        destination = stage / rel
        invoke(
            [
                *GPG,
                "--yes",
                "--trust-model",
                "always",
                "--no-encrypt-to",
                "--throw-keyids",
                "--armor",
                "--cipher-algo",
                "AES256",
                "--compress-algo",
                "none",
                "--recipient",
                NEW + "!",
                "--output",
                destination,
                "--encrypt",
            ],
            plain,
        )
        destination.chmod(0o600)
        notice(f"→ {index}/{total}: touch target to verify the new ciphertext.")
        recovered = decrypt(destination, NEW)
        if not hmac.compare_digest(plain, recovered):
            raise MigrationError(
                "Decrypted bytes differ; the live store remains unchanged."
            )
        del plain, recovered
        with destination.open("rb") as stream:
            sync_descriptor(stream.fileno())
        sync_directory(destination.parent)
        state["verified"][rel] = {
            "kind": "file",
            "mode": 0o600,
            "hash": digest(destination),
        }
        save_json(run / "state.json", state)
        notice(f"✓ {index}/{total}: exact contents verified with the target key")
    finalize_staging(run, state)


def prefer_new_key(run):
    state = load_run(run)
    if state["phase"] != "verified":
        raise MigrationError("Verify the migration first.")
    config = GPG_HOME / "gpg.conf"
    if config.is_symlink():
        raise MigrationError(
            "GPG config is symlinked; inspect its source before changing it."
        )
    existed = config.exists()
    current = config.read_bytes() if existed else b""
    mode = stat.S_IMODE(config.stat().st_mode) if existed else 0o600
    line = f"try-secret-key {NEW}"
    if line.encode() not in current.splitlines():
        backup = run / "gpg.conf.before"
        replace_bytes(backup, current)
        # This affects hidden-recipient decryption, not default signing or PIV.
        updated = (
            current
            + (
                "\n# Prefer the OpenPGP target encryption key for hidden recipients (pass).\n"
                + line
                + "\n"
            ).encode()
        )
        state["gpg_config_edit"] = {
            "existed": existed,
            "mode": mode,
            "before": hashlib.sha256(current).hexdigest(),
            "after": hashlib.sha256(updated).hexdigest(),
        }
        save_json(run / "state.json", state)
        replace_bytes(config, updated, mode)
    notice("GPG now tries the target encryption key first for hidden recipients.")


def restore_gpg_preference(run):
    state = load_run(run)
    edit = state.get("gpg_config_edit")
    if not edit:
        return
    config = GPG_HOME / "gpg.conf"
    current = digest(config) if config.is_file() and not config.is_symlink() else None
    before = edit["before"] if edit["existed"] else None
    if current != before:
        if (
            current != edit["after"]
            or stat.S_IMODE(config.stat().st_mode) != edit["mode"]
        ):
            notice(
                f"GPG config changed separately; it was left intact. Prior copy: {run / 'gpg.conf.before'}"
            )
            return
        if edit["existed"]:
            backup = run / "gpg.conf.before"
            if digest(backup) != edit["before"]:
                raise MigrationError(
                    "GPG config backup changed; current config was preserved."
                )
            replace_bytes(config, backup.read_bytes(), edit["mode"])
        else:
            config.unlink()
            sync_directory(config.parent)
    state.pop("gpg_config_edit")
    save_json(run / "state.json", state)
    notice("Restored the prior GPG preference after the incomplete migration.")


def pass_check(run):
    state = load_run(run)
    if state["phase"] != "verified":
        raise MigrationError("Verify the migration first.")
    verify_stage(run, state, complete=True)
    env = dict(os.environ, PASSWORD_STORE_DIR=str(run / "staged-store"))
    for name in (
        "PASSWORD_STORE_KEY",
        "PASSWORD_STORE_GPG_OPTS",
        "PASSWORD_STORE_SIGNING_KEY",
        "GNUPGHOME",
    ):
        env.pop(name, None)
    env["GNUPGHOME"] = str(GPG_HOME)
    entry = state["entries"][0][:-4]
    state.update(normal_pass_read_passed=False, pass_read_entry_count=0)
    save_json(run / "state.json", state)
    notice(
        "Touch target for a normal pass read. Password contents will not be displayed."
    )
    result = invoke(["pass", "show", "--", entry], env=env)
    del result
    state["normal_pass_read_passed"] = True
    state["pass_read_entry_count"] = 1
    save_json(run / "state.json", state)
    notice("✓ Normal pass read succeeded.")


def check_target_only(run):
    invoke(["gpgconf", "--homedir", GPG_HOME, "--kill", "scdaemon"])
    serials = invoke(["ykman", "list", "--serials"]).stdout.decode().split()
    if serials != [TARGET_SERIAL]:
        raise MigrationError(
            "Leave only the target YubiKey connected, then rerun finish. The live store is unchanged."
        )
    state = load_run(run)
    state["target_only_present_for_pass_check"] = True
    save_json(run / "state.json", state)
    notice("✓ Only the target YubiKey is connected.")


def finish(run):
    if not sys.stdin.isatty():
        raise MigrationError("Run finish interactively in your Terminal.")
    state = load_run(run)
    if state["phase"] == "activating":
        if recover_activation(run, state):
            return
        state = load_run(run)
    if state["phase"] == "activated":
        complete_activation(run, state)
        notice("This migration is already complete; the target store is active.")
        return
    notice(
        "Keep both YubiKeys connected for migration. Leave pass unused until completion."
    )
    notice(
        "Enter only OpenPGP user PINs in local prompts; touch target whenever it flashes."
    )
    notice("No passwords will be displayed. Completed entries are skipped on resume.")
    migrate(run)
    notice(
        "\nAll entries match. Unplug the old key now; leave the target YubiKey connected."
    )
    input(
        "Press Enter for the target-only pass check and automatic switch (Ctrl+C to pause): "
    )
    check_target_only(run)
    try:
        prefer_new_key(run)
        pass_check(run)
        activate(run)
    except BaseException:
        # After a switch may have occurred, preserve the new preference for recovery.
        if load_run(run)["phase"] not in ("activating", "activated"):
            restore_gpg_preference(run)
        raise


def activate(run):
    state = load_run(run)
    if state["phase"] != "verified" or not state.get("normal_pass_read_passed"):
        raise MigrationError(
            "All verification and the normal pass read must finish first."
        )
    unchanged_source(state)
    state["staged_manifest"] = verify_stage(run, state, complete=True)
    stage, backup = run / "staged-store", run / "original-store"
    if backup.exists() or SOURCE.stat().st_dev != run.stat().st_dev:
        raise MigrationError("Expected an unused rollback path on the same filesystem.")
    # Flush the staged data and journal intent before either directory rename.
    for rel, entry in state["staged_manifest"].items():
        if entry["kind"] == "file":
            with (stage / rel).open("rb") as stream:
                sync_descriptor(stream.fileno())
    for path in sorted(
        (p for p in stage.rglob("*") if p.is_dir()),
        key=lambda p: len(p.parts),
        reverse=True,
    ):
        sync_directory(path)
    sync_directory(stage)
    state["phase"] = "activating"
    save_json(run / "state.json", state)
    # Preserve the entire original, including its Git index, history and untracked files.
    try:
        SOURCE.rename(backup)
        if snapshot(backup) != state["original"]:
            raise MigrationError(
                "The live store changed during the switch; restoring it without replacement."
            )
        sync_directory(SOURCE.parent)
        sync_directory(run)
        stage.rename(SOURCE)
        sync_directory(SOURCE.parent)
        sync_directory(run)
    except BaseException:
        if not SOURCE.exists() and backup.exists():
            backup.rename(SOURCE)
            sync_directory(SOURCE.parent)
            sync_directory(run)
            state["phase"] = "verified"
            save_json(run / "state.json", state)
        raise
    complete_activation(run, state)


def recover_activation(run, state):
    """Reconcile only exact journaled directory states; never overwrite newer data."""
    stage, backup = run / "staged-store", run / "original-store"
    expected = state.get("staged_manifest")
    if not expected:
        raise MigrationError(
            "Activation journal is incomplete. Preserve all store directories."
        )
    if backup.exists():
        if snapshot(backup) != state["original"]:
            raise MigrationError(
                "Rollback store differs from its journal. Preserve all directories."
            )
        if SOURCE.exists():
            if stage.exists() or snapshot(SOURCE) != expected:
                raise MigrationError(
                    "Store state is ambiguous after interruption. No directory was replaced."
                )
            complete_activation(run, state)
            return True
        if not stage.exists() or snapshot(stage) != expected:
            raise MigrationError(
                "Verified staging copy is missing or changed. Preserve the rollback store."
            )
        backup.rename(SOURCE)
        sync_directory(SOURCE.parent)
        sync_directory(run)
        notice("Recovered the original live store after an interrupted switch.")
    elif (
        not SOURCE.exists()
        or snapshot(SOURCE) != state["original"]
        or not stage.exists()
        or snapshot(stage) != expected
    ):
        raise MigrationError(
            "Store state differs from the activation journal. No directory was replaced."
        )
    state["phase"] = "verified"
    save_json(run / "state.json", state)
    return False


def complete_activation(run, state):
    all_verified = set(state["verified"]) == set(state["entries"])
    if not all_verified or not state.get("normal_pass_read_passed"):
        raise MigrationError(
            "The activation journal lacks successful verification checks."
        )
    if not SOURCE.is_dir() or (SOURCE / ".gpg-id").read_text() != PRIMARY + "\n":
        raise MigrationError("The journaled migration is not the current live store.")
    backup = run / "original-store"
    state["phase"] = "activated"
    save_json(run / "state.json", state)
    report = {
        "entry_count": len(state["entries"]),
        "all_entries_exact_match": all_verified,
        "old_encryption_fingerprint": OLD,
        "new_encryption_fingerprint": NEW,
        "recipient": PRIMARY,
        "normal_pass_read_passed": state.get("normal_pass_read_passed", False),
        "pass_read_entry_count": state.get("pass_read_entry_count"),
        "target_only_present_for_pass_check": state.get(
            "target_only_present_for_pass_check", False
        ),
        "source": str(SOURCE),
        "rollback_store": str(backup),
        "git_history_preserved": True,
        "automatic_commit_created": False,
        "historical_ciphertext_still_requires_old_key": True,
    }
    OUTPUT.mkdir(parents=True, mode=0o700, exist_ok=True)
    save_json(OUTPUT / "password-store-migration.json", report)
    notice(
        f"SUCCESS: {len(state['entries'])} entries now use the target encryption key."
    )
    notice(f"Rollback store: {backup}")
    notice("Git history and uncommitted files preserved; no commit or push created.")
    notice(
        "New password ciphertext decrypts with target. Keep the old key for rollback and older history."
    )
    notice("Git commit-signing configuration is unchanged and needs its own check.")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "action",
        choices=(
            "prepare",
            "prepare-key",
            "migrate",
            "prefer-new-key",
            "pass-check",
            "activate",
            "finish",
        ),
    )
    parser.add_argument("run", type=Path, nargs="?")
    parser.add_argument(
        "--config", type=Path, help="operator JSON configuration (prepare only)"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="validate configuration without card access or writes",
    )
    args = parser.parse_args(argv)
    if args.action == "prepare" and (args.config is None or args.run is not None):
        parser.error("prepare requires --config and does not take a saved run")
    if args.action != "prepare" and args.run is None:
        parser.error("a migration directory is required")
    if args.action != "prepare" and args.config is not None:
        parser.error("resume uses the configuration saved in the migration directory")
    try:
        if args.action == "prepare":
            configure(json.loads(args.config.read_text()))
        else:
            args.run = Path(os.path.abspath(args.run.expanduser()))
            validate_run_directory(args.run)
            configure(read_journal(args.run / "baseline.json")["configuration"])
            if args.run.parent != VAULTS:
                raise MigrationError(
                    "Saved migration is outside its configured staging directory."
                )
            load_run(args.run)
        if args.dry_run:
            notice(f"Dry run: {args.action}; no card access or files changed.")
            notice(f"Store: {SOURCE}; staging parent: {VAULTS}")
            return 0
        os.umask(0o077)
        resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
        if sys.stdin.isatty():
            os.environ["GPG_TTY"] = os.ttyname(sys.stdin.fileno())
        if args.action == "prepare":
            prepare()
        else:
            {
                "prepare-key": prepare_key,
                "migrate": migrate,
                "prefer-new-key": prefer_new_key,
                "pass-check": pass_check,
                "activate": activate,
                "finish": finish,
            }[args.action](args.run)
    except (Exception, KeyboardInterrupt) as exc:  # noqa: BLE001 - never expose plaintext in tracebacks
        # Avoid exception tracebacks or locals containing any decrypted bytes.
        if isinstance(exc, MigrationError):
            notice(f"STOPPED: {exc}")
        else:
            notice(
                f"STOPPED: {type(exc).__name__}. Preserve the migration directory for inspection."
            )
        raise SystemExit(1)


if __name__ == "__main__":
    main()

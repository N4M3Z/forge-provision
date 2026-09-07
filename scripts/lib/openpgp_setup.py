"""Run locally in a native terminal; offline by default. Never prints private key material.

--check performs read-only prerequisite and device checks. Normal execution
creates a fresh encrypted image, refuses existing images/output files, backs up
before card writes, and leaves keytocard selection to the operator.
--resume reuses saved exports and repeats recovery checks without generating keys.
--allow-online skips the OFFLINE confirmation and all network-route checks.
"""

import argparse
import json
import os
import plistlib
import re
import resource
import shutil
import signal
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import ClassVar

IDENTITY = ""
SERIAL = ""
IMAGE = Path.home() / ".local/share/keyvaults/openpgp.gpg.dmg"
MOUNT = Path("/Volumes/OpenPGP Vault")
OUTPUT = Path.home() / ".local/share/keyvaults/openpgp-public"
DEPENDENCIES = (
    "gpg",
    "gpgconf",
    "ykman",
    "paperkey",
    "qrencode",
    "pinentry-mac",
    "hdiutil",
)


class SetupError(Exception):
    pass


class TerminalUI:
    """Small terminal presentation layer; never changes child-process output."""

    COLORS: ClassVar[dict[str, str]] = {
        "title": "1;35",
        "heading": "1;36",
        "ok": "32",
        "skip": "33",
        "action": "36",
        "error": "1;31",
        "note": "2",
        "bold": "1",
    }
    SYMBOLS: ClassVar[dict[str, str]] = {
        "ok": "✓",
        "skip": "↷",
        "action": "→",
        "error": "✗",
        "note": "·",
    }

    def paint(self, text, color, stream=None):
        stream = sys.stdout if stream is None else stream
        if (
            stream.isatty()
            and "NO_COLOR" not in os.environ
            and os.environ.get("TERM") != "dumb"
        ):
            return f"\033[{self.COLORS[color]}m{text}\033[0m"
        return str(text)

    def section(self, title, stream=None, color="heading"):
        stream = sys.stdout if stream is None else stream
        print("\n  " + self.paint(title, color, stream), file=stream, flush=True)
        print("  " + self.paint("─" * 52, "note", stream), file=stream, flush=True)

    def status(self, message, kind="ok", stream=None):
        stream = sys.stdout if stream is None else stream
        symbol = self.paint(self.SYMBOLS[kind], kind, stream)
        print(f"  {symbol} {message}", file=stream, flush=True)

    def detail(self, label, value, stream=None):
        stream = sys.stdout if stream is None else stream
        print(
            f"    {self.paint(label.ljust(11), 'note', stream)} {value}",
            file=stream,
            flush=True,
        )

    def command(self, command, explanation=""):
        print(
            f"    {self.paint(command.ljust(14), 'action')} {explanation}", flush=True
        )

    def prompt(self, message):
        return input("  " + self.paint("›", "action") + " " + message)

    def choose(self, question, options):
        self.status(question, "action")
        for number, option in enumerate(options, 1):
            print(f"    {self.paint(str(number) + ')', 'action')} {option}", flush=True)
        while True:
            answer = self.prompt(
                "Choose "
                + " / ".join(str(n) for n in range(1, len(options) + 1))
                + ": "
            ).strip()
            if answer in {str(n) for n in range(1, len(options) + 1)}:
                return int(answer)
            self.status(
                "Enter one of the numbers above, or press Ctrl+C to stop.", "skip"
            )


ui = TerminalUI()


def run(args, *, capture=False, stdout=None, diagnostics_on_error=False):
    # Captured commands below emit only public metadata, not private exports.
    # Defer stderr only for routine GPG checks whose prompts use pinentry-mac.
    # Native terminal prompts (hdiutil, ykman, gpg --edit-key) stay connected.
    result = subprocess.run(
        [str(x) for x in args],
        check=False,
        text=True,
        stdout=subprocess.PIPE if capture else stdout,
        stderr=subprocess.PIPE if diagnostics_on_error else None,
    )
    if result.returncode:
        if diagnostics_on_error and result.stderr:
            print(
                result.stderr,
                end="" if result.stderr.endswith("\n") else "\n",
                file=sys.stderr,
                flush=True,
            )
        raise SetupError(
            f"{args[0]} {args[1] if len(args) > 1 else ''} failed (exit {result.returncode})."
        )
    return result.stdout if capture else None


def key_fingerprints(listing):
    """Extract public fingerprints from GnuPG's colon-delimited metadata."""
    return [
        line.split(":")[9] for line in listing.splitlines() if line.startswith("fpr:")
    ]


def card_fingerprints(info):
    if not re.search(r"^OpenPGP version:\s*\d+\.\d+\s*$", info, re.MULTILINE):
        raise SetupError(
            "Unrecognized ykman OpenPGP information; cannot establish whether slots are empty."
        )
    slots = {}
    slot = None
    labels = {
        "Signature key:": "sig",
        "Decryption key:": "dec",
        "Encryption key:": "dec",
        "Authentication key:": "aut",
    }
    for line in info.splitlines():
        stripped = line.strip()
        if stripped in labels:
            slot = labels[stripped]
            if slot in slots:
                raise SetupError("Duplicate OpenPGP slot metadata.")
            slots[slot] = None
        elif stripped.endswith("key:"):
            if stripped != "Attestation key:":
                raise SetupError("Unrecognized OpenPGP key-slot label.")
            slot = None
        elif stripped.startswith("Fingerprint:") and slot:
            fingerprint = re.sub(r"[\s:]", "", stripped.split(":", 1)[1]).upper()
            if not re.fullmatch(r"[0-9A-F]{40}", fingerprint):
                raise SetupError(
                    "An occupied OpenPGP slot has missing or invalid fingerprint metadata."
                )
            slots[slot] = fingerprint
    if any(value is None for value in slots.values()):
        raise SetupError(
            "An OpenPGP slot has incomplete metadata; refusing to treat it as empty."
        )
    return slots


def compatible_slots(info, expected):
    present = card_fingerprints(info)
    if any(expected.get(slot) != fingerprint for slot, fingerprint in present.items()):
        raise SetupError(
            "An occupied OpenPGP slot differs from this saved identity. No overwrite or reset will be attempted."
        )
    return present


def publish_public(name, content):
    """Publish complete public artifacts without replacing another identity's files."""
    destination = OUTPUT / name
    if destination.exists():
        if destination.read_bytes() == content:
            return
        raise SetupError(f"Existing {name} differs; preserved for inspection.")
    fd, temporary = tempfile.mkstemp(prefix=".openpgp-public-", dir=OUTPUT)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(content)
            stream.flush()
            os.fsync(stream.fileno())
        os.link(temporary, destination)
    finally:
        Path(temporary).unlink(missing_ok=True)


def piv_certificates(info):
    certificates = {}
    slot = None
    for line in info.splitlines():
        match = re.match(r"Slot ([0-9A-Fa-f]{2})\b", line)
        if match:
            slot = match.group(1).upper()
            if slot in certificates:
                raise SetupError("Duplicate PIV slot metadata.")
            certificates[slot] = None
        elif slot and line.strip().startswith("Fingerprint:"):
            value = re.sub(r"\s+", "", line.split(":", 1)[1]).lower()
            if not re.fullmatch(r"[0-9a-f]+", value):
                raise SetupError("Unreadable PIV certificate fingerprint.")
            certificates[slot] = value
    if any(value is None for value in certificates.values()):
        raise SetupError("A PIV slot has incomplete certificate metadata.")
    if not certificates and "PIV version:" not in info:
        raise SetupError("Could not read the PIV certificate inventory.")
    return certificates


def target_only():
    serials = run(["ykman", "list", "--serials"], capture=True).split()
    if serials != [SERIAL]:
        raise SetupError(
            f"Leave only target YubiKey {SERIAL} connected. Detected: {', '.join(serials) or 'none'}."
        )
    return run(["ykman", "--device", SERIAL, "openpgp", "info"], capture=True)


def no_default_routes():
    # This is an additional check, not a substitute for physical disconnection.
    for family in ("-inet", "-inet6"):
        result = subprocess.run(
            ["/sbin/route", "-n", "get", family, "default"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )
        if result.returncode == 0:
            raise SetupError(
                "A default network route is still present. Disconnect Wi-Fi, Ethernet and VPNs first."
            )


def prerequisites(resume=False):
    ui.section("1 · Preflight")
    missing = [name for name in DEPENDENCIES if not shutil.which(name)]
    if missing:
        raise SetupError("Missing tools: " + ", ".join(missing))
    ui.status("Required tools available")
    if resume and not IMAGE.is_file():
        raise SetupError("No existing image to resume.")
    if IMAGE.exists() and not resume:
        raise SetupError(
            f"{IMAGE} already exists. It has been preserved; do not rerun a fresh setup over it."
        )
    for path in (MOUNT,):
        if path.exists():
            raise SetupError(
                f"{path} already exists. Resolve the existing mount before starting."
            )
    for name in ("openpgp-public.asc", "openpgp-auth.pub", "openpgp-result.json"):
        if (OUTPUT / name).exists() and not resume:
            raise SetupError(
                f"Output {name} already exists; preserved to avoid mixing identities."
            )
    info = target_only()
    ui.status(f"target YubiKey {SERIAL} is the only YubiKey connected")
    if card_fingerprints(info) and not resume:
        raise SetupError(
            "The target key already has OpenPGP keys. No keys will be overwritten."
        )
    ui.status("OpenPGP slot metadata readable" if resume else "OpenPGP slots empty")
    certs = piv_certificates(
        run(["ykman", "--device", SERIAL, "piv", "info"], capture=True)
    )
    for slot in sorted(certs):
        ui.status(f"PIV {slot} certificate found; will preserve it")
    if not certs:
        ui.status("PIV inventory read; no certificates found", "note")
    return certs


class Ceremony:
    def __init__(self, allow_online=False):
        self.allow_online = allow_online
        self.mounts = []
        self.homes = []
        self.image_created = False
        self.fingerprints = []
        self.key_backup = None
        self.state = {}

    def checkpoint(self, **changes):
        self.state.update(changes)
        self.state["network_checks_bypassed"] = self.allow_online or self.state.get(
            "network_checks_bypassed", False
        )
        temporary = MOUNT / "ceremony-state.tmp"
        with temporary.open("w") as stream:
            json.dump(self.state, stream, indent=2)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        temporary.replace(MOUNT / "ceremony-state.json")

    def check_network(self, confirm=False):
        if self.allow_online:
            if confirm:
                ui.status("Network availability ignored (--allow-online)", "skip")
            return
        if confirm:
            ui.status("Disconnect Wi-Fi, Ethernet and VPNs.", "action")
            if ui.prompt("After disconnecting, type OFFLINE: ").strip() != "OFFLINE":
                raise SetupError("Offline setup was not started.")
        no_default_routes()
        if confirm:
            ui.status("Offline confirmation received; no default network routes found")

    def resume(self, piv_now):
        ui.section("3 · Open saved vault")
        ui.status("Opening the existing encrypted image.", "action")
        self.image_created = (
            True  # An existing image needs the same preservation notice.
        )
        self.attach(IMAGE, MOUNT)
        self.homes = [
            MOUNT / "generation-keyring",
            *MOUNT.glob("backup-restore-check-*"),
            *MOUNT.glob("card-check-*"),
        ]
        state_file = MOUNT / "ceremony-state.json"
        if not state_file.is_file():
            raise SetupError(
                "No checkpoint was saved. Follow the early-interruption steps in docs/guides/openpgp-recovery.md."
            )
        self.state = json.loads(state_file.read_text())
        if self.state.get("identity") != IDENTITY or self.state.get("serial") != SERIAL:
            raise SetupError(
                "The checkpoint belongs to a different identity or device."
            )
        if self.state.get("piv_before") != piv_now:
            raise SetupError(
                "PIV certificates differ from the original setup snapshot."
            )
        self.fingerprints = self.state.get("fingerprints", [])
        if self.state.get("phase") not in ("exports_ready", "card_keys_verified"):
            raise SetupError(
                "Generation or exports were interrupted. Preserve the image and use the early-interruption recovery steps."
            )
        if len(self.fingerprints) != 4 or not all(
            re.fullmatch(r"[0-9A-F]{40}", fpr) for fpr in self.fingerprints
        ):
            raise SetupError("The checkpoint has invalid fingerprints.")
        primary = self.fingerprints[0]
        self.key_backup = MOUNT / "gpg" / primary
        for name in ("cert.asc", "cert.gpg", "paperkey.txt"):
            path = self.key_backup / name
            if not path.is_file() or not path.stat().st_size:
                raise SetupError(
                    f"Missing or empty recovery export: {name}. See docs/guides/openpgp-recovery.md."
                )
        generation = MOUNT / "generation-keyring"
        if not generation.is_dir():
            raise SetupError(
                "The saved generation keyring is missing; use the recovery guide."
            )
        listing = self.gpg(
            generation,
            "--with-colons",
            "--with-subkey-fingerprint",
            "--show-keys",
            self.key_backup / "cert.asc",
            capture=True,
        )
        if key_fingerprints(listing) != self.fingerprints:
            raise SetupError(
                "The saved public certificate differs from the checkpoint."
            )
        self.checkpoint()
        ui.status("Saved identity, recovery exports and PIV snapshot checked")
        self.kill_agents()
        compatible_slots(
            target_only(), dict(zip(("sig", "dec", "aut"), self.fingerprints[1:]))
        )
        self.finish(self.state["piv_before"], generation, primary, resume=True)

    def attach(self, image, mount, readonly=False):
        args = [
            "hdiutil",
            "attach",
            image,
            "-mountpoint",
            mount,
            "-nobrowse",
            "-owners",
            "on",
        ]
        if readonly:
            args.append("-readonly")
        self.mounts.append(mount)
        try:
            # Password interaction stays attached to the user's terminal.
            run(args)
        except SetupError:
            if not mount.exists():
                self.mounts.remove(mount)
            raise
        try:
            metadata = plistlib.loads(
                run(["hdiutil", "info", "-plist"], capture=True).encode()
            )
            images = []
            for entry in metadata["images"]:
                try:
                    if entry.get("image-path") and os.path.samefile(
                        entry["image-path"], image
                    ):
                        images.append(entry)
                except OSError:
                    # Other mounted images may refer to files already moved or removed.
                    continue
            if len(images) != 1:
                raise SetupError(
                    "Could not identify the attached encrypted image uniquely."
                )
            entities = images[0]["system-entities"]
        except (ValueError, KeyError, TypeError, plistlib.InvalidFileException) as exc:
            raise SetupError(
                "Could not verify the newly attached encrypted image."
            ) from exc
        if str(mount) not in [entity.get("mount-point") for entity in entities]:
            raise SetupError(
                f"The image did not mount at the expected location {mount}."
            )

    def kill_agents(self):
        errors = []
        for home in self.homes:
            if home.exists():
                try:
                    run(["gpgconf", "--homedir", home, "--kill", "all"])
                except Exception as exc:  # noqa: BLE001 - continue cleanup of every tracked resource
                    errors.append(f"{home}: {exc}")
        if errors:
            raise SetupError("; ".join(errors))

    def detach(self, mount):
        run(["hdiutil", "detach", mount], stdout=subprocess.DEVNULL)
        self.mounts.remove(mount)

    def cleanup(self):
        try:
            self.kill_agents()
        except Exception as exc:  # noqa: BLE001 - continue cleanup of every tracked resource
            ui.status(f"Agent cleanup: {exc}", "error", stream=sys.stderr)
        for mount in list(reversed(self.mounts)):
            try:
                self.detach(mount)
            except Exception:  # noqa: BLE001 - report each mount that still needs cleanup
                advice = (
                    "Eject it before retrying."
                    if self.allow_online
                    else "Keep networking off and eject it before reconnecting."
                )
                ui.status(
                    f"STILL MOUNTED: {mount}. {advice}", "error", stream=sys.stderr
                )

    def new_home(self, name, card=False):
        if name == "generation-keyring":
            home = MOUNT / name
            home.mkdir(mode=0o700)
        else:
            home = Path(tempfile.mkdtemp(prefix=name + "-", dir=MOUNT))
        self.homes.append(home)
        (home / "gpg-agent.conf").write_text(
            f"pinentry-program {shutil.which('pinentry-mac')}\n"
            "no-allow-external-cache\nenforce-passphrase-constraints\n"
            "min-passphrase-len 12\nmin-passphrase-nonalpha 0\n"
        )
        (home / "gpg.conf").write_text(
            "no-auto-key-retrieve\nauto-key-locate clear\ndisable-dirmngr\n"
        )
        if card:
            (home / "scdaemon.conf").write_text("disable-ccid\npcsc-shared\n")
        return home

    def gpg(self, home, *args, capture=False, stdout=None, diagnostics_on_error=False):
        return run(
            ["gpg", "--homedir", home, *args],
            capture=capture,
            stdout=stdout,
            diagnostics_on_error=diagnostics_on_error,
        )

    def set_pins(self):
        ui.status(
            "Set the OpenPGP user PIN and Admin PIN in the local prompts.", "action"
        )
        ui.status(
            "Factory values, only if unchanged: user 123456; admin 12345678.", "note"
        )
        ui.status("Use the known current PIN. If unsure, press Ctrl+C to stop.", "note")
        for kind, command in (("user", "change-pin"), ("admin", "change-admin-pin")):
            label = "User PIN" if kind == "user" else "Admin PIN"
            status = self.state.get(kind + "_pin")
            if status == "done":
                ui.status(f"{label} change already completed")
                continue
            if status == "started":
                answer = ui.choose(
                    f"The previous {label} change was interrupted.",
                    (
                        "Retry the change — the previous attempt failed.",
                        "Already changed successfully — skip this step.",
                    ),
                )
                if answer == 2:
                    self.checkpoint(**{kind + "_pin": "done"})
                    ui.status(f"{label} change confirmed complete")
                    continue
            ui.status(f"Change {label} using its known current value.", "action")
            self.checkpoint(**{kind + "_pin": "started"})
            run(["ykman", "--device", SERIAL, "openpgp", "access", command])
            self.checkpoint(**{kind + "_pin": "done"})
            ui.status(f"{label} changed")

    def transfer_subkeys(self, generation, primary, missing):
        if not missing:
            return
        # Read card metadata before the guide so it cannot scroll the guide away.
        self.gpg(generation, "--card-status", capture=True)
        ui.section("Transfer guide · commands for gpg>")
        ui.status(
            "Read this guide before opening GPG. Enter commands one at a time.",
            "action",
        )
        ui.status(
            "key N toggles selection. Only the intended subkey should have *.", "note"
        )
        ui.command("At gpg>", "Action")
        for slot in missing:
            number, label, capability = {
                "sig": (1, "Signature", "S"),
                "dec": (2, "Encryption", "E"),
                "aut": (3, "Authentication", "A"),
            }[slot]
            usage = {"sig": "signing", "dec": "encryption", "aut": "authentication"}[
                slot
            ]
            ui.command(f"key {number}", f"Select {usage} [{capability}]")
            ui.command("keytocard", f"Choose {label}, normally option {number}")
            ui.command(f"key {number}", f"Deselect {usage}")
        ui.command("save", "Save card-backed stubs and return to this helper")
        ui.status(
            "Never transfer the primary. Stop if GPG asks to replace a key.", "note"
        )
        ui.status(
            "On resume, this guide lists only missing slots. Scroll up to refer to it.",
            "note",
        )
        ui.prompt("Press Enter to open gpg> (Ctrl+C to stop): ")
        self.gpg(generation, "--edit-key", primary)
        run(["gpgconf", "--homedir", generation, "--kill", "all"])

    def set_touch_policies(self):
        ui.section("Touch policies · OpenPGP")
        ui.status("SIG = signing; DEC = decryption; AUT = authentication.", "note")
        ui.status(
            "cached = touch reused for 15 seconds; on = touch for each operation.",
            "note",
        )
        ui.status(
            "These policies apply to OpenPGP; macOS PIV login is separate.", "note"
        )
        ui.status("Use the OpenPGP Admin PIN and confirm each policy with y.", "action")
        labels = {
            "sig": "Signing (SIG)",
            "dec": "Decryption (DEC)",
            "aut": "Authentication (AUT)",
        }
        for slot, policy in (("sig", "cached"), ("dec", "on"), ("aut", "on")):
            if self.state.get("touch_" + slot) == "done":
                ui.status(f"{labels[slot]}: {policy} already configured")
                continue
            detail = (
                "touch, then reuse it for 15 seconds"
                if policy == "cached"
                else "touch for every operation"
            )
            ui.status(f"{labels[slot]} → {policy}: {detail}.", "action")
            run(
                [
                    "ykman",
                    "--device",
                    SERIAL,
                    "openpgp",
                    "keys",
                    "set-touch",
                    slot,
                    policy,
                ]
            )
            self.checkpoint(**{"touch_" + slot: "done"})
            ui.status(f"{labels[slot]} touch policy saved")

    def execute(self, piv_before, resume=False):
        if not sys.stdin.isatty():
            raise SetupError("Run this helper interactively in Terminal.app.")
        ui.section("2 · Network mode")
        ui.status("Passwords and PINs are entered only in local prompts.", "note")
        self.check_network(confirm=True)
        if resume:
            self.resume(piv_before)
            return
        IMAGE.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        if shutil.disk_usage(IMAGE.parent).free < 300 * 1024 * 1024:
            raise SetupError(
                "Allow at least 300 MB free for the local encrypted image."
            )

        ui.section("3 · Encrypted vault")
        ui.status("Choose an image password; do not save it in Keychain.", "action")
        run(
            [
                "hdiutil",
                "create",
                "-size",
                "256m",
                "-fs",
                "APFS",
                "-encryption",
                "AES-256",
                "-volname",
                MOUNT.name,
                IMAGE,
            ]
        )
        self.image_created = True
        self.attach(IMAGE, MOUNT)
        ui.status("Encrypted volume created and mounted")
        generation = self.new_home("generation-keyring", card=True)
        self.state = {"identity": IDENTITY, "serial": SERIAL, "piv_before": piv_before}
        self.checkpoint(phase="generation_started")
        ui.section("4 · Generate ECC keys")
        ui.status(
            "Choose a GPG backup passphrase of at least 12 characters in pinentry.",
            "action",
        )
        ui.status("Keep the passphrase separately from the image.", "note")
        self.gpg(
            generation, "--quick-generate-key", IDENTITY, "ed25519", "cert", "never"
        )
        listing = self.gpg(
            generation, "--with-colons", "--list-secret-keys", IDENTITY, capture=True
        )
        fprs = key_fingerprints(listing)
        if len(fprs) != 1 or not re.fullmatch(r"[0-9A-F]{40}", fprs[0]):
            raise SetupError(
                "Unexpected primary-key metadata; stopping before any card writes."
            )
        primary = fprs[0]
        for algorithm, usage in (
            ("ed25519", "sign"),
            ("cv25519", "encr"),
            ("ed25519", "auth"),
        ):
            self.gpg(generation, "--quick-add-key", primary, algorithm, usage, "2y")
        listing = self.gpg(
            generation, "--with-colons", "--list-secret-keys", primary, capture=True
        )
        self.fingerprints = key_fingerprints(listing)
        if len(self.fingerprints) != 4:
            raise SetupError("Expected a primary and exactly three subkeys.")
        records = [
            line.split(":")
            for line in listing.splitlines()
            if line.startswith(("sec:", "ssb:"))
        ]
        expected = [("22", "c"), ("22", "s"), ("18", "e"), ("22", "a")]
        if [
            (r[3], "".join(c for c in r[11] if c.islower())) for r in records
        ] != expected:
            raise SetupError(
                "The generated algorithms or key capabilities are unexpected."
            )
        self.gpg(generation, "--with-subkey-fingerprint", "--list-secret-keys", primary)
        self.checkpoint(phase="generation_complete", fingerprints=self.fingerprints)
        ui.status(
            "Primary key and signing, encryption, authentication subkeys generated"
        )

        self.key_backup = MOUNT / "gpg" / primary
        self.key_backup.mkdir(parents=True)
        revocation = generation / "openpgp-revocs.d" / (primary + ".rev")
        if not revocation.is_file() or not revocation.stat().st_size:
            raise SetupError(
                "The primary-key revocation certificate was not saved. Stopping before card writes."
            )
        shutil.copyfile(revocation, self.key_backup / "revocation-certificate.asc")
        ui.section("5 · Recovery exports")
        ui.status("Saving private backups directly into the encrypted image.", "action")
        exports = (
            ("key.asc", "--export-secret-keys", True),
            ("subkeys.key.asc", "--export-secret-subkeys", True),
            ("cert.asc", "--export", True),
            ("cert.gpg", "--export", False),
            ("secret-backup.gpg", "--export-secret-keys", False),
        )
        for name, action, armor in exports:
            args = ["--output", self.key_backup / name]
            if armor:
                args.append("--armor")
            self.gpg(generation, *args, action, primary)
            if not (self.key_backup / name).stat().st_size:
                raise SetupError(f"Empty backup export: {name}.")
        run(
            [
                "paperkey",
                "--secret-key",
                self.key_backup / "secret-backup.gpg",
                "--output",
                self.key_backup / "paperkey.txt",
            ]
        )
        run(
            [
                "paperkey",
                "--secret-key",
                self.key_backup / "secret-backup.gpg",
                "--output-type",
                "raw",
                "--output",
                self.key_backup / "paperkey.raw",
            ]
        )
        # Encode directly into a file; private material never passes through stdout.
        import base64

        (self.key_backup / "paperkey.b64").write_bytes(
            base64.b64encode((self.key_backup / "paperkey.raw").read_bytes())
        )
        run(
            [
                "qrencode",
                "-r",
                self.key_backup / "paperkey.b64",
                "-o",
                self.key_backup / "paperkey-qr.png",
            ]
        )
        self.checkpoint(phase="exports_ready")
        ui.status("Recovery exports and revocation certificate saved")
        self.finish(piv_before, generation, primary)

    def finish(self, piv_before, generation, primary, resume=False):
        ui.section("6 · Verify recovery")
        self.kill_agents()
        if not resume:
            self.detach(MOUNT)
            ui.status(
                "Reopening the encrypted image to test its saved recovery material.",
                "action",
            )
            self.attach(IMAGE, MOUNT)
        backup_source = self.key_backup
        restore = self.new_home("backup-restore-check")
        run(
            [
                "paperkey",
                "--pubring",
                backup_source / "cert.gpg",
                "--secrets",
                backup_source / "paperkey.txt",
                "--output",
                restore / "restored-private.gpg",
            ]
        )
        ui.status(
            "Checking the saved recovery keys; unlock them in pinentry when asked.",
            "action",
        )
        self.gpg(
            restore,
            "--import",
            restore / "restored-private.gpg",
            diagnostics_on_error=True,
        )
        recovered = self.gpg(
            restore,
            "--with-colons",
            "--list-secret-keys",
            primary,
            capture=True,
            diagnostics_on_error=True,
        )
        if key_fingerprints(recovered) != self.fingerprints:
            raise SetupError(
                "Backup-restored fingerprints do not match the generated identity."
            )
        sample = restore / "check.txt"
        sample.write_text("OpenPGP work GPG recovery test\n")
        self.gpg(
            restore,
            "--local-user",
            primary,
            "--output",
            restore / "backup-check.sig",
            "--detach-sign",
            sample,
        )
        self.gpg(
            restore,
            "--verify",
            restore / "backup-check.sig",
            sample,
            diagnostics_on_error=True,
        )
        self.gpg(
            restore,
            "--trust-model",
            "always",
            "--recipient",
            primary,
            "--output",
            restore / "check.gpg",
            "--encrypt",
            sample,
        )
        self.gpg(
            restore,
            "--output",
            restore / "backup-recovered.txt",
            "--decrypt",
            restore / "check.gpg",
            diagnostics_on_error=True,
        )
        if sample.read_bytes() != (restore / "backup-recovered.txt").read_bytes():
            raise SetupError("Backup decryption verification failed.")
        run(["gpgconf", "--homedir", restore, "--kill", "all"])
        ui.status("Local paperkey recovery verified")
        ui.status("Recovered key signing and decryption verified")
        ui.status("your backup destination copy has not been made or verified.", "note")

        ui.section("7 · YubiKey setup")
        self.check_network()
        expected_slots = dict(zip(("sig", "dec", "aut"), self.fingerprints[1:]))
        compatible_slots(target_only(), expected_slots)
        self.set_pins()
        # Probe before starting scdaemon, then let GPG keep the card until it exits.
        present = compatible_slots(target_only(), expected_slots)
        missing = [slot for slot in ("sig", "dec", "aut") if slot not in present]
        self.transfer_subkeys(generation, primary, missing)
        if card_fingerprints(target_only()) != expected_slots:
            raise SetupError(
                "Card transfer is incomplete or fingerprints differ. The saved exports are preserved; see the recovery guide."
            )
        self.checkpoint(phase="card_keys_verified")
        ui.status("All three card fingerprints match")
        self.set_touch_policies()

        ui.section("8 · Verify hardware")
        ui.status("Testing the target key using only its public certificate.", "action")
        card = self.new_home("card-check", card=True)
        self.gpg(
            card, "--import", self.key_backup / "cert.asc", diagnostics_on_error=True
        )
        self.gpg(card, "--card-status", capture=True)
        self.gpg(
            card,
            "--local-user",
            primary,
            "--output",
            card / "card-check.sig",
            "--detach-sign",
            sample,
        )
        self.gpg(
            card, "--verify", card / "card-check.sig", sample, diagnostics_on_error=True
        )
        self.gpg(
            card,
            "--output",
            card / "card-recovered.txt",
            "--decrypt",
            restore / "check.gpg",
            diagnostics_on_error=True,
        )
        if sample.read_bytes() != (card / "card-recovered.txt").read_bytes():
            raise SetupError("target decryption verification failed.")
        run(["gpgconf", "--homedir", card, "--kill", "all"])
        piv_after = piv_certificates(
            run(["ykman", "--device", SERIAL, "piv", "info"], capture=True)
        )
        if piv_after != piv_before:
            raise SetupError(
                "PIV certificate metadata differs from the initial snapshot. Review before relying on login."
            )
        ui.status("Card signing and decryption verified")
        ui.status("PIV certificates match the original snapshot")

        publish_public(
            "openpgp-public.asc", (self.key_backup / "cert.asc").read_bytes()
        )
        ssh_public = self.gpg(
            card, "--export-ssh-key", self.fingerprints[3] + "!", capture=True
        )
        publish_public("openpgp-auth.pub", ssh_public.encode())
        self.kill_agents()
        self.detach(MOUNT)
        result = {
            "identity": IDENTITY,
            "card_serial": SERIAL,
            "fingerprints": dict(
                zip(
                    ("primary", "signing", "encryption", "authentication"),
                    self.fingerprints,
                )
            ),
            "image": str(IMAGE),
            "local_paperkey_restore_passed": True,
            "network_checks_bypassed": self.state.get(
                "network_checks_bypassed", self.allow_online
            ),
            "external_backup_created": False,
            "external_backup_verified": False,
            "card_signing_passed": True,
            "card_decryption_passed": True,
            "authentication_slot_fingerprint_verified": True,
            "piv_certificates_unchanged": True,
            "macos_login_tested": False,
            "ssh_authentication_tested": False,
            "password_store_migrated": False,
        }
        publish_public(
            "openpgp-result.json", (json.dumps(result, indent=2) + "\n").encode()
        )
        ui.section("9 · Complete")
        ui.status("SUCCESS — setup passed")
        ui.status("Encrypted volume unmounted")
        ui.detail("Fingerprint", primary)
        ui.detail("Image", IMAGE)
        ui.status(f"Public certificates and result report: {OUTPUT}", "note")
        ui.section("Next steps")
        ui.status(
            "Continue with your agent using the public report, or do these yourself:",
            "action",
        )
        ui.command(
            "1. Back up",
            f"Copy the closed {IMAGE.name} to your backup destination when ready.",
        )
        ui.command("2. Verify", "Test macOS login with only the target key connected.")
        ui.command(
            "3. Configure", "Set up work signing and SSH authentication; test both."
        )
        ui.command("4. Migrate", "Re-encrypt the password store and verify decryption.")
        ui.status(
            "Keep the old key until migration and the remaining checks are complete.",
            "note",
        )
        ui.status("Keep the encrypted vault unmounted between uses.", "note")


def configure(args):
    """Validate operator configuration before touching a device or creating files."""
    global IDENTITY, SERIAL, IMAGE, MOUNT, OUTPUT
    if not args.name or any(c in args.name for c in "\r\n<>\x00"):
        raise SetupError("Supply --name without control characters or angle brackets.")
    if any(ord(c) < 32 or ord(c) == 127 for c in args.name):
        raise SetupError("The identity name contains a control character.")
    if (
        not args.email
        or any(ord(c) < 32 or ord(c) == 127 for c in args.email)
        or not re.fullmatch(r"[^\s<>@]+@[^\s<>@]+\.[^\s<>@]+", args.email)
    ):
        raise SetupError("Supply a valid --email address.")
    if not args.serial or not re.fullmatch(r"[0-9]{1,10}", args.serial):
        raise SetupError("Supply the decimal --serial from ykman list --serials.")
    IDENTITY = f"{args.name} <{args.email}>"
    SERIAL = args.serial
    IMAGE, MOUNT, OUTPUT = (
        Path(os.path.abspath(Path(p).expanduser()))
        for p in (args.image, args.mount, args.output_dir)
    )
    if IMAGE.suffix != ".dmg":
        raise SetupError("The encrypted image must have a .dmg suffix.")
    if MOUNT.parent != Path("/Volumes") or not MOUNT.name:
        raise SetupError("Use a dedicated mountpoint directly beneath /Volumes.")
    if IMAGE.is_relative_to(MOUNT) or OUTPUT.is_relative_to(MOUNT):
        raise SetupError(
            "Keep the image and public output directory outside the mounted vault."
        )
    if any(
        p.is_symlink() for path in (IMAGE, MOUNT, OUTPUT) for p in (path, *path.parents)
    ):
        raise SetupError(
            "Resolve symlinked image, mount or output paths before provisioning."
        )


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--name", default=os.environ.get("OPENPGP_NAME"))
    parser.add_argument("--email", default=os.environ.get("OPENPGP_EMAIL"))
    parser.add_argument("--serial", default=os.environ.get("OPENPGP_SERIAL"))
    parser.add_argument("--image", default=str(IMAGE))
    parser.add_argument("--mount", default=str(MOUNT))
    parser.add_argument("--output-dir", default=str(OUTPUT))
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="validate settings and show the plan without reading cards or writing files",
    )
    parser.add_argument(
        "--allow-online",
        "--ignore-network",
        dest="allow_online",
        action="store_true",
        help="skip the OFFLINE confirmation and all network-route checks; also works with --resume",
    )
    parser.add_argument(
        "--resume",
        action="store_true",
        help="resume an existing image after its recovery exports were saved",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="read-only prerequisite/device checks; no image or keys created",
    )
    args = parser.parse_args(argv)
    try:
        configure(args)
    except SetupError as exc:
        parser.error(str(exc))
    if args.dry_run:
        ui.status("Dry run: no device access and no files created", "note")
        ui.detail("Identity", IDENTITY)
        ui.detail("YubiKey", SERIAL)
        ui.detail("Image", IMAGE)
        ui.detail("Output", OUTPUT)
        ui.status(
            "Inspect OpenPGP slots and PIV inventory; create or resume an encrypted vault",
            "action",
        )
        ui.status(
            "Verify recovery before interactive keytocard; compare PIV inventory afterward",
            "action",
        )
        return 0
    if sys.platform != "darwin":
        parser.error("The encrypted APFS image workflow requires macOS.")
    os.umask(0o077)
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))

    def interrupted(signum, frame):
        raise KeyboardInterrupt(f"Signal {signum}")

    for signum in (signal.SIGTERM, signal.SIGHUP):
        signal.signal(signum, interrupted)
    # Avoid inheriting an agent/keyring selected in the caller's shell.
    os.environ.pop("GNUPGHOME", None)
    if sys.stdin.isatty():
        os.environ["GPG_TTY"] = os.ttyname(sys.stdin.fileno())
    ceremony = Ceremony(allow_online=args.allow_online)
    try:
        ui.section("OPENPGP · GPG SETUP", color="title")
        ui.detail("Identity", IDENTITY)
        ui.detail("YubiKey", f"target · {SERIAL}")
        ui.detail("Vault", IMAGE)
        ui.detail(
            "Mode",
            "Read-only preflight"
            if args.check
            else "Resume"
            if args.resume
            else "New key",
        )
        piv_before = prerequisites(resume=args.resume)
        if args.check:
            ui.status("Read-only preflight complete (no changes made)")
            return 0
        OUTPUT.mkdir(mode=0o700, parents=True, exist_ok=True)
        ceremony.execute(piv_before, resume=args.resume)
        return 0
    except (Exception, KeyboardInterrupt) as exc:  # noqa: BLE001 - always attempt vault cleanup
        ui.section("Setup stopped", stream=sys.stderr, color="error")
        ui.status(f"STOPPED: {exc or 'Interrupted.'}", "error", stream=sys.stderr)
        ceremony.cleanup()
        if ceremony.image_created:
            ui.status(
                f"The encrypted image is preserved at {IMAGE}. Do not delete it or reset a key to retry.",
                "note",
                stream=sys.stderr,
            )
        ui.status(
            "Recovery steps: docs/guides/openpgp-recovery.md in the repository.",
            "action",
            stream=sys.stderr,
        )
        if ceremony.mounts:
            message = (
                "Unmount the reported volumes before retrying."
                if ceremony.allow_online
                else "Keep networking OFF until the reported volumes have been unmounted."
            )
            ui.status(message, "action", stream=sys.stderr)
        else:
            ui.status(
                "No tracked setup volumes mounted. Confirm the vault is unmounted before sharing the error text.",
                "note",
                stream=sys.stderr,
            )
        return 1


if __name__ == "__main__":
    sys.exit(main())

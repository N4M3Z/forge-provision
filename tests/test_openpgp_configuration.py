"""Configuration boundaries use synthetic identities and temporary directories only."""

import argparse
import importlib.util
import io
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


def load_helper(name):
    path = Path(__file__).resolve().parents[1] / "scripts/lib" / f"{name}.py"
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class ConfigurationTests(unittest.TestCase):
    def test_duplicate_openpgp_slot_fields_are_rejected(self):
        summary = (
            "OpenPGP version: 3.4\nApplication version: 5.7.1\nPIN tries remaining: 3\nReset code tries remaining: 0\nAdmin PIN tries remaining: 3\nRequire PIN for signature: Once\nKDF enabled: False\nSignature key:\n Fingerprint: "
            + "B" * 40
            + "\n"
        )
        for extra in (
            " Fingerprint: " + "C" * 40,
            " Touch policy: On\n Touch policy: Cached",
        ):
            with self.subTest(extra=extra), self.assertRaises(self.setup.SetupError):
                self.setup.card_fingerprints(summary + extra)

    def test_duplicate_piv_slot_fields_are_rejected(self):
        summary = (
            "PIV version: 5.7.1\nPIN tries remaining: 3/3\nManagement key algorithm: AES192\nCHUID: No data available\nCCC: No data available\nSlot 9A (AUTHENTICATION):\n Fingerprint: "
            + "a" * 64
            + "\n"
        )
        for extra in (
            " Fingerprint: " + "b" * 64,
            " Private key type: ECCP256\n Private key type: EMPTY",
        ):
            with self.subTest(extra=extra), self.assertRaises(self.setup.SetupError):
                self.setup.piv_certificates(summary + extra)

    def test_card_parsers_reject_header_only_and_unfamiliar_key_layouts(self):
        for info in (
            "OpenPGP version: 3.4\n",
            "OpenPGP version: 3.4\nSignature fingerprint: " + "B" * 40,
        ):
            with self.subTest(info=info), self.assertRaises(self.setup.SetupError):
                self.setup.card_fingerprints(info)
        for info in (
            "PIV version: 5.7.1\n",
            "PIV version: 5.7.1\nCertificate in slot 9A: " + "a" * 64,
        ):
            with self.subTest(info=info), self.assertRaises(self.setup.SetupError):
                self.setup.piv_certificates(info)

    def test_full_empty_summaries_reject_extra_unrecognized_metadata(self):
        openpgp = "OpenPGP version: 3.4\nApplication version: 5.7.1\nPIN tries remaining: 3\nReset code tries remaining: 0\nAdmin PIN tries remaining: 3\nRequire PIN for signature: Once\nKDF enabled: False\n"
        piv = "PIV version: 5.7.1\nPIN tries remaining: 3/3\nManagement key algorithm: AES192\nCHUID: No data available\nCCC: No data available\n"
        self.assertEqual(self.setup.card_fingerprints(openpgp), {})
        self.assertEqual(self.setup.piv_certificates(piv), {})
        for info, parser in (
            (
                openpgp + "Signature fingerprint: " + "B" * 40,
                self.setup.card_fingerprints,
            ),
            (piv + "Certificate in slot 9A: " + "a" * 64, self.setup.piv_certificates),
        ):
            with self.assertRaises(self.setup.SetupError):
                parser(info)

    def test_unreviewed_ykman_major_stops(self):
        with patch.object(
            self.setup, "run", return_value="YubiKey Manager (ykman) version: 5.9.2"
        ):
            self.setup.check_ykman_version()
        for version in ("YubiKey Manager (ykman) version: 6.0.0", "unrecognized"):
            with (
                patch.object(self.setup, "run", return_value=version),
                self.assertRaises(self.setup.SetupError),
            ):
                self.setup.check_ykman_version()

    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()
        self.setup = load_helper("openpgp_setup")
        self.migration = load_helper("password_store_migrate")
        self.args = argparse.Namespace(
            name="Example Developer",
            email="developer@example.com",
            serial="12345678",
            image=str(self.root / "vault.dmg"),
            mount="/Volumes/Test OpenPGP Vault",
            output_dir=str(self.root / "public"),
        )
        self.config = {
            "old_primary": "e" * 40,
            "old_encryption": "f" * 40,
            "new_primary": "a" * 40,
            "new_encryption": "c" * 40,
            "old_card": "D2760001240100000006876543210000",
            "new_card": "D2760001240100000006123456780000",
            "new_serial": "12345678",
            "source": str(self.root / "store"),
            "gpg_home": str(self.root / "gnupg"),
            "vaults": str(self.root / "runs"),
            "output_dir": str(self.root / "public"),
            "public_certificate": str(self.root / "certificate.asc"),
        }

    def test_setup_validates_identity_controls(self):
        for field, value in (
            ("name", "Person\nInjected"),
            ("name", ""),
            ("email", "a\x1b@example.com"),
            ("email", "missing-at"),
            ("serial", "--help"),
        ):
            with (
                self.subTest(field=field),
                patch.object(self.args, field, value),
                self.assertRaises(self.setup.SetupError),
            ):
                self.setup.configure(self.args)

    def test_setup_rejects_vault_outputs_inside_mount_and_symlinked_parents(self):
        for field, value in (
            ("image", self.args.mount + "/nested.dmg"),
            ("output_dir", self.args.mount + "/public"),
            ("mount", "/Volumes/../elsewhere"),
        ):
            with (
                self.subTest(field=field),
                patch.object(self.args, field, value),
                self.assertRaises(self.setup.SetupError),
            ):
                self.setup.configure(self.args)
        (self.root / "link").symlink_to(self.root, target_is_directory=True)
        self.args.output_dir = str(self.root / "link/public")
        with self.assertRaises(self.setup.SetupError):
            self.setup.configure(self.args)

    def test_setup_dry_run_does_not_probe_or_write(self):
        argv = [
            "--dry-run",
            "--name",
            self.args.name,
            "--email",
            self.args.email,
            "--serial",
            self.args.serial,
            "--image",
            self.args.image,
            "--output-dir",
            self.args.output_dir,
            "--mount",
            self.args.mount,
        ]
        with (
            patch.object(self.setup, "prerequisites") as probe,
            patch.object(self.setup, "Ceremony") as ceremony,
            patch.object(self.setup.sys, "stdout", io.StringIO()),
        ):
            self.assertEqual(self.setup.main(argv), 0)
        probe.assert_not_called()
        ceremony.assert_not_called()
        self.assertEqual(list(self.root.iterdir()), [])

    def test_missing_identity_fails_before_any_hardware_operation(self):
        with (
            patch.dict(self.setup.os.environ, {}, clear=True),
            patch.object(self.setup, "prerequisites") as probe,
            patch.object(self.setup.sys, "stderr", io.StringIO()),
            self.assertRaises(SystemExit) as error,
        ):
            self.setup.main(["--check"])
        self.assertEqual(error.exception.code, 2)
        probe.assert_not_called()

    def test_migration_normalizes_and_pins_gpg_home(self):
        self.migration.configure(self.config)
        self.assertEqual(self.migration.PRIMARY, "A" * 40)
        self.assertEqual(
            self.migration.GPG[1:3], ["--homedir", self.config["gpg_home"]]
        )
        self.assertEqual(self.migration.TARGET_SERIAL, "12345678")
        self.assertEqual(self.migration.CONFIG["new_encryption"], "C" * 40)

    def test_migration_rejects_missing_and_unknown_fields(self):
        missing = dict(self.config)
        del missing["new_card"]
        for config in (missing, {**self.config, "typo": "value"}, []):
            with self.assertRaises(self.migration.MigrationError):
                self.migration.configure(config)

    def test_migration_rejects_short_fingerprint_same_identity_and_bad_cards(self):
        for field, value in (
            ("new_primary", "A" * 16),
            ("new_encryption", "A" * 40),
            ("new_card", "12345678"),
            ("new_card", self.config["old_card"]),
            ("new_serial", "not-a-serial"),
        ):
            with (
                self.subTest(field=field),
                self.assertRaises(self.migration.MigrationError),
            ):
                self.migration.configure({**self.config, field: value})

    def test_migration_rejects_paths_overlapping_store(self):
        for field in ("vaults", "output_dir", "gpg_home", "public_certificate"):
            with (
                self.subTest(field=field),
                self.assertRaises(self.migration.MigrationError),
            ):
                self.migration.configure(
                    {**self.config, field: self.config["source"] + "/nested"}
                )

    def test_migration_dry_run_reads_config_without_touching_store(self):
        path = self.root / "config.json"
        path.write_text(json.dumps(self.config))
        with (
            patch.object(self.migration, "prepare") as prepare,
            patch.object(self.migration, "invoke") as invoke,
            patch.object(self.migration, "notice"),
        ):
            self.assertEqual(
                self.migration.main(["prepare", "--config", str(path), "--dry-run"]), 0
            )
        prepare.assert_not_called()
        invoke.assert_not_called()
        self.assertEqual(list(self.root.iterdir()), [path])

    def test_resume_uses_saved_configuration_and_rejects_overrides(self):
        self.migration.configure(self.config)
        source = Path(self.config["source"])
        source.mkdir()
        (source / ".git").mkdir()
        (source / ".gpg-id").write_text("FFFFFFFF\n")
        (source / "entry.gpg").write_bytes(b"ciphertext fixture")
        with (
            patch.dict(self.migration.os.environ, {}, clear=True),
            patch.object(self.migration, "notice"),
        ):
            self.migration.prepare()
        run = next(Path(self.config["vaults"]).iterdir())
        fresh = load_helper("password_store_migrate")
        with patch.object(fresh, "invoke") as invoke, patch.object(fresh, "notice"):
            self.assertEqual(fresh.main(["finish", str(run), "--dry-run"]), 0)
        self.assertEqual(fresh.SOURCE, Path(self.config["source"]))
        invoke.assert_not_called()
        with (
            patch.object(fresh.sys, "stderr", io.StringIO()),
            self.assertRaises(SystemExit),
        ):
            fresh.main(
                ["finish", str(run), "--config", str(self.root / "different.json")]
            )


if __name__ == "__main__":
    unittest.main()

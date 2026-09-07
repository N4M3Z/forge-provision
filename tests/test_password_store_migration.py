import importlib.util
import tempfile
import unittest
from pathlib import Path
from unittest.mock import Mock, patch

spec = importlib.util.spec_from_file_location(
    "migration",
    Path(__file__).resolve().parents[1] / "scripts/lib/password_store_migrate.py",
)
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


class MigrationTests(unittest.TestCase):
    def test_modified_entry_paths_are_rejected_before_gpg(self):
        victim = self.root / "victim.gpg"
        victim.write_bytes(b"untouched ciphertext")
        original = m.load_run(self.run)
        for rel in ("../../victim.gpg", str(victim), "./entry.gpg", "sub/../entry.gpg"):
            state = dict(original, entries=[rel])
            m.save_json(self.run / "state.json", state)
            with (
                self.subTest(rel=rel),
                patch.object(m, "learn_card") as card,
                patch.object(m, "invoke") as invoke,
                self.assertRaises(m.MigrationError),
            ):
                m.migrate(self.run)
            card.assert_not_called()
            invoke.assert_not_called()
            self.assertEqual(victim.read_bytes(), b"untouched ciphertext")

    def test_mutated_configuration_and_original_manifest_are_rejected(self):
        original = m.load_run(self.run)
        for update in (
            {"configuration": {"source": str(self.root / "elsewhere")}},
            {"original": {"../entry.gpg": original["original"]["entry.gpg"]}},
        ):
            m.save_json(self.run / "state.json", {**original, **update})
            with (
                patch.object(m, "learn_card") as card,
                self.assertRaises(m.MigrationError),
            ):
                m.migrate(self.run)
            card.assert_not_called()

    def test_unrecognized_phase_and_invalid_verified_digest_are_rejected(self):
        original = m.load_run(self.run)
        for update in (
            {"phase": "unknown"},
            {
                "verified": {
                    "entry.gpg": {"kind": "file", "mode": 0o600, "hash": "invalid"}
                }
            },
        ):
            m.save_json(self.run / "state.json", {**original, **update})
            with self.assertRaises(m.MigrationError):
                m.load_run(self.run)

    def test_symlinked_state_and_staging_directory_are_rejected(self):
        state = self.run / "state.json"
        saved = self.root / "saved-state.json"
        state.rename(saved)
        state.symlink_to(saved)
        with self.assertRaises(m.MigrationError):
            m.load_run(self.run)
        state.unlink()
        saved.rename(state)
        stage = self.run / "staged-store"
        moved = self.root / "moved-stage"
        stage.rename(moved)
        stage.symlink_to(moved, target_is_directory=True)
        with self.assertRaises(m.MigrationError):
            m.load_run(self.run)

    def test_old_fixed_temporary_name_cannot_redirect_journal_writes(self):
        victim = self.root / "victim"
        victim.write_bytes(b"untouched")
        (self.run / "state.tmp").symlink_to(victim)
        state = m.load_run(self.run)
        m.save_json(self.run / "state.json", state)
        self.assertEqual(victim.read_bytes(), b"untouched")

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.source = self.root / "store"
        self.vaults = self.root / "vaults"
        self.output = self.root / "output"
        self.gpg_home = self.root / "gnupg"
        for p in (self.source, self.vaults, self.output, self.gpg_home):
            p.mkdir()
        (self.source / ".git").mkdir()
        (self.source / ".git/index").write_bytes(b"original index fixture")
        (self.source / ".gpg-id").write_text("FFFFFFFF\n")
        (self.source / "entry.gpg").write_bytes(b"old ciphertext fixture")
        (self.source / "untracked.txt").write_text("keep this fixture")
        for name, value in (
            ("SOURCE", self.source),
            ("VAULTS", self.vaults),
            ("OUTPUT", self.output),
            ("GPG_HOME", self.gpg_home),
            ("PRIMARY", "A" * 40),
            ("NEW", "C" * 40),
            ("OLD_PRIMARY", "E" * 40),
            ("OLD", "F" * 40),
            ("TARGET_CARD", "D2760001240100000006123456780000"),
            ("SOURCE_CARD", "D2760001240100000006876543210000"),
            ("TARGET_SERIAL", "12345678"),
            ("CONFIG", {}),
        ):
            p = patch.object(m, name, value)
            p.start()
            self.addCleanup(p.stop)
        p = patch.dict(m.os.environ, {}, clear=True)
        p.start()
        self.addCleanup(p.stop)
        m.prepare()
        self.run = next(self.vaults.iterdir())

    def perform_migration(self, mismatch=False):
        def encrypt(args, data=None):
            self.assertEqual(data, b"sensitive fixture")
            Path(args[args.index("--output") + 1]).write_bytes(
                b"new ciphertext fixture"
            )
            return Mock(returncode=0)

        with (
            patch.object(m, "learn_card"),
            patch.object(m, "verify_bindings"),
            patch.object(m, "invoke", side_effect=encrypt),
            patch.object(
                m,
                "decrypt",
                side_effect=[
                    b"sensitive fixture",
                    b"wrong" if mismatch else b"sensitive fixture",
                ],
            ),
        ):
            m.migrate(self.run)

    def test_snapshot_rejects_symlinks(self):
        (self.source / "link").symlink_to(self.source / "entry.gpg")
        with self.assertRaises(m.MigrationError):
            m.snapshot(self.source)

    def test_source_changes_block_before_any_card_operation(self):
        (self.source / "entry.gpg").write_bytes(b"concurrent update")
        with (
            patch.object(m, "learn_card") as card,
            self.assertRaises(m.MigrationError),
        ):
            m.migrate(self.run)
        card.assert_not_called()

    def test_wrong_decryption_key_is_rejected_without_exposing_plaintext(self):
        result = Mock(
            stdout=b"sensitive fixture",
            stderr=f"[GNUPG:] DECRYPTION_KEY {m.OLD} {m.OLD_PRIMARY} -\n[GNUPG:] DECRYPTION_OKAY\n".encode(),
        )
        with (
            patch.object(m, "invoke", return_value=result),
            self.assertRaises(m.MigrationError) as error,
        ):
            m.decrypt(Path("fixture"), m.NEW)
        self.assertNotIn("sensitive", str(error.exception))

    def test_mismatch_does_not_change_live_store_or_mark_entry_verified(self):
        original = m.snapshot(self.source)
        with self.assertRaises(m.MigrationError):
            self.perform_migration(mismatch=True)
        self.assertEqual(m.snapshot(self.source), original)
        self.assertEqual(m.load_run(self.run)["verified"], {})

    def test_success_is_staged_and_resume_does_not_repeat_decryption(self):
        original = m.snapshot(self.source)
        self.perform_migration()
        self.assertEqual(m.snapshot(self.source), original)
        self.assertEqual(m.load_run(self.run)["phase"], "verified")
        self.assertEqual(
            m.stat.S_IMODE((self.run / "staged-store/.gpg-id").stat().st_mode), 0o600
        )
        with patch.object(m, "decrypt") as decrypt:
            m.migrate(self.run)
        decrypt.assert_not_called()

    def test_modified_verified_ciphertext_blocks_activation(self):
        self.perform_migration()
        state = m.load_run(self.run)
        state["normal_pass_read_passed"] = True
        m.save_json(self.run / "state.json", state)
        (self.run / "staged-store/entry.gpg").write_bytes(b"tampered fixture")
        with self.assertRaises(m.MigrationError):
            m.activate(self.run)
        self.assertEqual(
            (self.source / "entry.gpg").read_bytes(), b"old ciphertext fixture"
        )

    def test_activation_requires_normal_pass_check(self):
        self.perform_migration()
        with self.assertRaises(m.MigrationError):
            m.activate(self.run)
        self.assertFalse((self.run / "original-store").exists())

    def test_failed_second_rename_restores_original(self):
        self.perform_migration()
        state = m.load_run(self.run)
        state["normal_pass_read_passed"] = True
        m.save_json(self.run / "state.json", state)
        rename = Path.rename

        def interrupted(path, target):
            if path == self.run / "staged-store":
                raise OSError("simulated rename failure")
            return rename(path, target)

        with (
            patch.object(Path, "rename", interrupted),
            self.assertRaises(OSError),
        ):
            m.activate(self.run)
        self.assertEqual(m.snapshot(self.source), state["original"])
        self.assertFalse((self.run / "original-store").exists())

    def test_activation_keeps_exact_rollback_and_git_metadata(self):
        self.perform_migration()
        state = m.load_run(self.run)
        state["normal_pass_read_passed"] = True
        m.save_json(self.run / "state.json", state)
        m.activate(self.run)
        self.assertEqual(m.snapshot(self.run / "original-store"), state["original"])
        self.assertEqual(
            (self.source / ".git/index").read_bytes(), b"original index fixture"
        )
        self.assertEqual(
            (self.source / "untracked.txt").read_text(), "keep this fixture"
        )
        self.assertEqual((self.source / ".gpg-id").read_text(), m.PRIMARY + "\n")

    def test_finish_checks_target_only_before_pass_read_and_activation(self):
        order = []
        with (
            patch.object(m.sys.stdin, "isatty", return_value=True),
            patch(
                "builtins.input",
                side_effect=lambda _: order.append("operator-unplugged"),
            ),
            patch.object(m, "migrate", side_effect=lambda _: order.append("migrate")),
            patch.object(
                m,
                "check_target_only",
                side_effect=lambda _: order.append("target-only"),
            ),
            patch.object(
                m, "prefer_new_key", side_effect=lambda _: order.append("prefer")
            ),
            patch.object(
                m, "pass_check", side_effect=lambda _: order.append("pass-read")
            ),
            patch.object(m, "activate", side_effect=lambda _: order.append("activate")),
        ):
            m.finish(self.run)
        self.assertEqual(
            order,
            [
                "migrate",
                "operator-unplugged",
                "target-only",
                "prefer",
                "pass-read",
                "activate",
            ],
        )

    def test_two_connected_cards_prevent_target_only_check_from_passing(self):
        with (
            patch.object(
                m,
                "invoke",
                side_effect=[Mock(stdout=b""), Mock(stdout=b"12345678\n87654321\n")],
            ),
            self.assertRaises(m.MigrationError),
        ):
            m.check_target_only(self.run)
        self.assertNotIn("target_only_present_for_pass_check", m.load_run(self.run))

    def test_error_diagnostics_never_include_captured_password_bytes(self):
        result = Mock(
            returncode=2,
            stdout=b"private stdout fixture",
            stderr=b"private stderr fixture\n[GNUPG:] ERROR pkdecrypt_failed 12345\ngpg: decryption failed: Timeout\n",
        )
        with (
            patch.object(m.subprocess, "run", return_value=result),
            self.assertRaises(m.MigrationError) as error,
        ):
            m.invoke(["gpg", "--decrypt", "fixture"])
        self.assertIn("ERROR pkdecrypt_failed 12345", str(error.exception))
        self.assertIn("Timeout", str(error.exception))
        self.assertNotIn("private", str(error.exception))

    def test_partial_failure_resumes_only_the_unverified_entry(self):
        (self.source / "second.gpg").write_bytes(b"second old ciphertext fixture")
        old_run = self.run
        m.prepare()
        self.run = next(p for p in self.vaults.iterdir() if p != old_run)

        def encrypt(args, data=None):
            Path(args[args.index("--output") + 1]).write_bytes(
                b"new ciphertext fixture"
            )
            return Mock(returncode=0)

        with (
            patch.object(m, "learn_card"),
            patch.object(m, "verify_bindings"),
            patch.object(m, "invoke", side_effect=encrypt),
            patch.object(
                m,
                "decrypt",
                side_effect=[
                    b"first",
                    b"first",
                    b"second",
                    m.MigrationError("Timeout"),
                ],
            ),
            self.assertRaises(m.MigrationError),
        ):
            m.migrate(self.run)
        self.assertEqual(len(m.load_run(self.run)["verified"]), 1)
        with (
            patch.object(m, "learn_card"),
            patch.object(m, "verify_bindings"),
            patch.object(m, "invoke", side_effect=encrypt),
            patch.object(m, "decrypt", side_effect=[b"second", b"second"]) as decrypt,
        ):
            m.migrate(self.run)
        self.assertEqual(decrypt.call_count, 2)
        self.assertEqual(len(m.load_run(self.run)["verified"]), 2)
        self.assertEqual(m.snapshot(self.source), m.load_run(self.run)["original"])

    def journal_activation(self):
        self.perform_migration()
        state = m.load_run(self.run)
        state.update(phase="activating", normal_pass_read_passed=True)
        m.save_json(self.run / "state.json", state)
        return state

    def test_interrupted_recipient_finalization_resumes_without_cards(self):
        save = m.save_json

        def interrupted(path, value):
            if value.get("phase") == "verified":
                raise OSError("simulated final checkpoint failure")
            return save(path, value)

        with (
            patch.object(m, "save_json", side_effect=interrupted),
            self.assertRaises(OSError),
        ):
            self.perform_migration()
        self.assertEqual(m.load_run(self.run)["phase"], "finalizing")
        self.assertEqual(
            (self.run / "staged-store/.gpg-id").read_text(), m.PRIMARY + "\n"
        )
        with (
            patch.object(m, "learn_card") as learn,
            patch.object(m, "decrypt") as decrypt,
        ):
            m.migrate(self.run)
        learn.assert_not_called()
        decrypt.assert_not_called()
        self.assertEqual(m.load_run(self.run)["phase"], "verified")

    def test_crash_between_renames_restores_original_from_journal(self):
        state = self.journal_activation()
        self.source.rename(self.run / "original-store")
        self.assertFalse(m.recover_activation(self.run, state))
        self.assertEqual(m.snapshot(self.source), state["original"])
        self.assertEqual(m.load_run(self.run)["phase"], "verified")

    def test_crash_after_switch_completes_journal_and_report(self):
        state = self.journal_activation()
        self.source.rename(self.run / "original-store")
        (self.run / "staged-store").rename(self.source)
        self.assertTrue(m.recover_activation(self.run, state))
        self.assertEqual(m.load_run(self.run)["phase"], "activated")
        self.assertTrue((self.output / "password-store-migration.json").is_file())
        self.assertEqual(m.snapshot(self.run / "original-store"), state["original"])

    def test_recovery_refuses_to_overwrite_a_changed_live_store(self):
        state = self.journal_activation()
        self.source.rename(self.run / "original-store")
        (self.run / "staged-store").rename(self.source)
        (self.source / "entry.gpg").write_bytes(b"new concurrent edit")
        with self.assertRaises(m.MigrationError):
            m.recover_activation(self.run, state)
        self.assertEqual(
            (self.source / "entry.gpg").read_bytes(), b"new concurrent edit"
        )
        self.assertEqual(m.snapshot(self.run / "original-store"), state["original"])

    def test_interruption_immediately_after_first_rename_rolls_back(self):
        self.perform_migration()
        state = m.load_run(self.run)
        state["normal_pass_read_passed"] = True
        m.save_json(self.run / "state.json", state)
        rename = Path.rename

        def interrupted(path, target):
            result = rename(path, target)
            if path == self.source:
                raise KeyboardInterrupt()
            return result

        with (
            patch.object(Path, "rename", interrupted),
            self.assertRaises(KeyboardInterrupt),
        ):
            m.activate(self.run)
        self.assertEqual(m.snapshot(self.source), state["original"])
        self.assertEqual(m.load_run(self.run)["phase"], "verified")

    def test_report_failure_can_be_retried_after_successful_switch(self):
        self.perform_migration()
        state = m.load_run(self.run)
        state["normal_pass_read_passed"] = True
        m.save_json(self.run / "state.json", state)
        save = m.save_json

        def fail_report(path, value):
            if path.name == "password-store-migration.json":
                raise OSError("report write failure")
            return save(path, value)

        with (
            patch.object(m, "save_json", side_effect=fail_report),
            self.assertRaises(OSError),
        ):
            m.activate(self.run)
        self.assertEqual(m.load_run(self.run)["phase"], "activated")
        with patch.object(m.sys.stdin, "isatty", return_value=True):
            m.finish(self.run)
        self.assertTrue((self.output / "password-store-migration.json").is_file())
        self.assertEqual(m.snapshot(self.run / "original-store"), state["original"])

    def test_change_during_first_rename_is_preserved_and_blocks_switch(self):
        self.perform_migration()
        state = m.load_run(self.run)
        state["normal_pass_read_passed"] = True
        m.save_json(self.run / "state.json", state)
        rename = Path.rename

        def concurrent_edit(path, target):
            result = rename(path, target)
            if path == self.source:
                (Path(target) / "entry.gpg").write_bytes(b"concurrent ciphertext edit")
            return result

        with (
            patch.object(Path, "rename", concurrent_edit),
            self.assertRaises(m.MigrationError),
        ):
            m.activate(self.run)
        self.assertEqual(
            (self.source / "entry.gpg").read_bytes(), b"concurrent ciphertext edit"
        )
        self.assertEqual(m.load_run(self.run)["phase"], "verified")
        self.assertTrue((self.run / "staged-store").exists())

    def test_missing_gpg_config_is_created_and_removed_on_rollback(self):
        self.perform_migration()
        m.prefer_new_key(self.run)
        config = self.gpg_home / "gpg.conf"
        self.assertIn(m.NEW, config.read_text())
        m.restore_gpg_preference(self.run)
        self.assertFalse(config.exists())

    def test_failed_pass_check_restores_exact_previous_config(self):
        self.perform_migration()
        config = self.gpg_home / "gpg.conf"
        before = b"# existing config fixture\nthrow-keyids\n"
        config.write_bytes(before)
        with (
            patch.object(m.sys.stdin, "isatty", return_value=True),
            patch("builtins.input", return_value=""),
            patch.object(m, "check_target_only"),
            patch.object(
                m, "pass_check", side_effect=m.MigrationError("simulated read failure")
            ),
            patch.object(m, "activate") as activate,
            self.assertRaises(m.MigrationError),
        ):
            m.finish(self.run)
        activate.assert_not_called()
        self.assertEqual(config.read_bytes(), before)
        self.assertNotIn("gpg_config_edit", m.load_run(self.run))

    def test_config_rollback_preserves_separate_user_edits(self):
        self.perform_migration()
        config = self.gpg_home / "gpg.conf"
        config.write_text("throw-keyids\n")
        m.prefer_new_key(self.run)
        newer = config.read_bytes() + b"# separate user edit\n"
        config.write_bytes(newer)
        m.restore_gpg_preference(self.run)
        self.assertEqual(config.read_bytes(), newer)

    def test_missing_tool_has_actionable_error_without_a_traceback(self):
        with (
            patch.object(m.subprocess, "run", side_effect=FileNotFoundError()),
            self.assertRaisesRegex(
                m.MigrationError, "Required tool 'ykman' is missing"
            ),
        ):
            m.invoke(["ykman", "list", "--serials"])

    def test_normal_pass_read_records_single_entry_and_failed_retry_clears_success(
        self,
    ):
        self.perform_migration()
        with patch.object(
            m, "invoke", return_value=Mock(stdout=b"private fixture")
        ) as invoke:
            m.pass_check(self.run)
        self.assertEqual(invoke.call_args.args[0], ["pass", "show", "--", "entry"])
        self.assertEqual(m.load_run(self.run)["pass_read_entry_count"], 1)
        with (
            patch.object(
                m, "invoke", side_effect=m.MigrationError("simulated failure")
            ),
            self.assertRaises(m.MigrationError),
        ):
            m.pass_check(self.run)
        self.assertFalse(m.load_run(self.run)["normal_pass_read_passed"])
        with self.assertRaises(m.MigrationError):
            m.activate(self.run)

    def test_ciphertext_is_flushed_before_verified_checkpoint(self):
        flushed = []
        sync = m.sync_descriptor
        save = m.save_json

        def record_sync(descriptor):
            flushed.append(m.os.fstat(descriptor).st_ino)
            sync(descriptor)

        def check_checkpoint(path, value):
            if value.get("verified"):
                self.assertIn(
                    (self.run / "staged-store/entry.gpg").stat().st_ino, flushed
                )
            return save(path, value)

        with (
            patch.object(m, "sync_descriptor", side_effect=record_sync),
            patch.object(m, "save_json", side_effect=check_checkpoint),
        ):
            self.perform_migration()

    def test_activation_report_distinguishes_all_crypto_checks_from_one_pass_read(self):
        self.perform_migration()
        with patch.object(m, "invoke", return_value=Mock(stdout=b"private fixture")):
            m.pass_check(self.run)
        m.activate(self.run)
        report = m.json.loads(
            (self.output / "password-store-migration.json").read_text()
        )
        self.assertTrue(report["all_entries_exact_match"])
        self.assertTrue(report["normal_pass_read_passed"])
        self.assertEqual(report["pass_read_entry_count"], 1)


if __name__ == "__main__":
    unittest.main()

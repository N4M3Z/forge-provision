import importlib.util
import io
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import Mock, patch

source = Path(__file__).resolve().parents[1] / "scripts/lib/openpgp_setup.py"
spec = importlib.util.spec_from_file_location("openpgp_setup", source)
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


class GuardTests(unittest.TestCase):
    def setUp(self):
        patcher = patch.multiple(
            m, SERIAL="12345678", IDENTITY="Example Developer <developer@example.com>"
        )
        patcher.start()
        self.addCleanup(patcher.stop)
        version_check = patch.object(m, "check_ykman_version")
        version_check.start()
        self.addCleanup(version_check.stop)

    def test_fingerprint_parser_ignores_other_records(self):
        listing = "sec:u:255:22:X:0:0::::cESCA:\nfpr:::::::::AAA:\nuid:u::::::::Someone:\nsub:u:255:18:Y:0:0::::e:\nfpr:::::::::BBB:"
        self.assertEqual(m.key_fingerprints(listing), ["AAA", "BBB"])

    def test_card_slots_are_distinct_and_attestation_is_excluded(self):
        info = (
            "OpenPGP version: 3.4\nApplication version: 5.7.1\nPIN tries remaining: 3\nReset code tries remaining: 0\nAdmin PIN tries remaining: 3\nRequire PIN for signature: Once\nKDF enabled: False\nSignature key:\n  Fingerprint: "
            + "AA " * 20
            + "\nDecryption key:\n  Fingerprint: "
            + "BB " * 20
            + "\nAuthentication key:\n  Fingerprint: "
            + "CC " * 20
            + "\nAttestation key:\n  Fingerprint: "
            + "DD " * 20
            + "\n"
        )
        self.assertEqual(
            m.card_fingerprints(info),
            {"sig": "AA" * 20, "dec": "BB" * 20, "aut": "CC" * 20},
        )
        self.assertEqual(
            m.card_fingerprints(
                "OpenPGP version: 3.4\nApplication version: 5.7.1\nPIN tries remaining: 3\nReset code tries remaining: 0\nAdmin PIN tries remaining: 3\nRequire PIN for signature: Once\nKDF enabled: False"
            ),
            {},
        )

    def test_unreadable_piv_inventory_is_not_accepted(self):
        for info in (
            "unrecognized output",
            "PIV version: 5.7.1\nPIN tries remaining: 3/3\nManagement key algorithm: AES192\nCHUID: No data available\nCCC: No data available\nSlot 9A (AUTHENTICATION):",
        ):
            with self.assertRaises(m.SetupError):
                m.piv_certificates(info)

    def test_piv_does_not_require_key_management_certificate(self):
        self.assertEqual(
            m.piv_certificates(
                "PIV version: 5.7.1\nPIN tries remaining: 3/3\nManagement key algorithm: AES192\nCHUID: No data available\nCCC: No data available\nSlot 9A (AUTHENTICATION):\n Fingerprint: "
                + "aa" * 32
            ),
            {"9A": "aa" * 32},
        )
        self.assertEqual(
            m.piv_certificates(
                "PIV version: 5.7.1\nPIN tries remaining: 3/3\nManagement key algorithm: AES192\nCHUID: No data available\nCCC: No data available"
            ),
            {},
        )

    def test_piv_fingerprints_match_slots(self):
        self.assertEqual(
            m.piv_certificates(
                "PIV version: 5.7.1\nPIN tries remaining: 3/3\nManagement key algorithm: AES192\nCHUID: No data available\nCCC: No data available\nSlot 9A (AUTHENTICATION):\n Fingerprint: "
                + "AA " * 32
                + "\nSlot 9D (KEY_MANAGEMENT):\n Fingerprint: "
                + "BB " * 32
            ),
            {"9A": "aa" * 32, "9D": "bb" * 32},
        )

    def test_multiple_wrong_or_missing_devices_stop_before_card_access(self):
        for devices in ("12345678\n87654321\n", "87654321\n", ""):
            with (
                self.subTest(devices=devices),
                patch.object(m, "run", return_value=devices) as run,
            ):
                with self.assertRaises(m.SetupError):
                    m.target_only()
                self.assertEqual(run.call_count, 1)

    def test_existing_image_stops_before_hardware_and_is_preserved(self):
        with TemporaryDirectory() as tmp:
            image = Path(tmp) / "openpgp.gpg.dmg"
            image.write_bytes(b"existing encrypted image fixture")
            with (
                patch.object(m, "IMAGE", image),
                patch.object(m.shutil, "which", return_value="tool"),
                patch.object(m, "target_only") as device,
            ):
                with self.assertRaises(m.SetupError):
                    m.prerequisites()
                device.assert_not_called()
            self.assertEqual(image.read_bytes(), b"existing encrypted image fixture")

    def test_populated_openpgp_slot_stops_setup(self):
        with TemporaryDirectory() as tmp:
            root = Path(tmp)
            with (
                patch.multiple(
                    m, IMAGE=root / "new.dmg", MOUNT=root / "mount", OUTPUT=root
                ),
                patch.object(m.shutil, "which", return_value="tool"),
                patch.object(
                    m,
                    "target_only",
                    return_value="OpenPGP version: 3.4\nApplication version: 5.7.1\nPIN tries remaining: 3\nReset code tries remaining: 0\nAdmin PIN tries remaining: 3\nRequire PIN for signature: Once\nKDF enabled: False\nSignature key:\n Fingerprint: "
                    + "A" * 40,
                ),
                self.assertRaises(m.SetupError),
            ):
                m.prerequisites()

    def test_existing_public_output_is_preserved(self):
        with TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "openpgp-public.asc").write_text("old public certificate")
            with (
                patch.multiple(
                    m, IMAGE=root / "new.dmg", MOUNT=root / "mount", OUTPUT=root
                ),
                patch.object(m.shutil, "which", return_value="tool"),
                patch.object(m, "target_only") as device,
            ):
                with self.assertRaises(m.SetupError):
                    m.prerequisites()
                device.assert_not_called()

    def test_default_network_route_blocks_offline_setup(self):
        with (
            patch.object(m.subprocess, "run", return_value=Mock(returncode=0)),
            self.assertRaises(m.SetupError),
        ):
            m.no_default_routes()
        with patch.object(m.subprocess, "run", return_value=Mock(returncode=1)) as run:
            m.no_default_routes()
            self.assertEqual(run.call_count, 2)

    def test_allow_online_skips_confirmation_and_every_network_probe(self):
        ceremony = m.Ceremony(allow_online=True)
        with (
            patch("builtins.input") as prompt,
            patch.object(m.subprocess, "run") as probe,
            patch.object(m.sys, "stdout", new_callable=io.StringIO) as output,
        ):
            ceremony.check_network(confirm=True)
            ceremony.check_network()
            prompt.assert_not_called()
            probe.assert_not_called()
            self.assertIn("↷ Network availability ignored", output.getvalue())

    def test_default_mode_still_checks_routes_at_both_stages(self):
        ceremony = m.Ceremony()
        for confirm in (True, False):
            with (
                self.subTest(confirm=confirm),
                patch("builtins.input", return_value="OFFLINE"),
                patch.object(m.subprocess, "run", return_value=Mock(returncode=0)),
                patch.object(m.sys, "stdout", new_callable=io.StringIO),
                self.assertRaises(m.SetupError),
            ):
                ceremony.check_network(confirm=confirm)

    def test_online_resume_reaches_resume_without_prompting_or_probing(self):
        ceremony = m.Ceremony(allow_online=True)
        with (
            patch.object(m.sys.stdin, "isatty", return_value=True),
            patch("builtins.input") as prompt,
            patch.object(m.subprocess, "run") as probe,
            patch.object(ceremony, "resume") as resume,
            patch.object(m.sys, "stdout", new_callable=io.StringIO),
        ):
            ceremony.execute({}, resume=True)
            resume.assert_called_once_with({})
            prompt.assert_not_called()
            probe.assert_not_called()

    def test_bypass_history_does_not_enable_online_mode_on_later_runs(self):
        with TemporaryDirectory() as tmp, patch.object(m, "MOUNT", Path(tmp)):
            ceremony = m.Ceremony(allow_online=True)
            ceremony.checkpoint(phase="exports_ready")
            resumed = m.Ceremony()
            resumed.state = m.json.loads(
                (Path(tmp) / "ceremony-state.json").read_text()
            )
            resumed.checkpoint()
            self.assertTrue(resumed.state["network_checks_bypassed"])
            self.assertFalse(resumed.allow_online)

    def test_partial_attach_failure_remains_tracked_for_cleanup(self):
        with TemporaryDirectory() as tmp:
            mount = Path(tmp) / "mount"
            ceremony = m.Ceremony()

            def partial(*args, **kwargs):
                mount.mkdir()
                raise m.SetupError("attach failed after mounting")

            with (
                patch.object(m, "run", side_effect=partial),
                self.assertRaises(m.SetupError),
            ):
                ceremony.attach(Path(tmp) / "image.dmg", mount)
            self.assertEqual(ceremony.mounts, [mount])

    def test_attach_validates_image_identity_and_mountpoint(self):
        with TemporaryDirectory() as tmp:
            image = Path(tmp) / "image.dmg"
            image.touch()
            mount = Path(tmp) / "mounted"
            metadata = {
                "images": [
                    {
                        "image-path": str(image),
                        "system-entities": [{"mount-point": str(mount)}],
                    }
                ]
            }
            ceremony = m.Ceremony()
            with patch.object(
                m, "run", side_effect=[None, m.plistlib.dumps(metadata).decode()]
            ) as calls:
                ceremony.attach(image, mount)
                self.assertNotIn("capture", calls.call_args_list[0].kwargs)
            self.assertEqual(ceremony.mounts, [mount])

    def test_attach_rejects_unexpected_mountpoint(self):
        with TemporaryDirectory() as tmp:
            image = Path(tmp) / "image.dmg"
            image.touch()
            mount = Path(tmp) / "mounted"
            metadata = {
                "images": [
                    {
                        "image-path": str(image),
                        "system-entities": [{"mount-point": "/unexpected"}],
                    }
                ]
            }
            ceremony = m.Ceremony()
            with (
                patch.object(
                    m, "run", side_effect=[None, m.plistlib.dumps(metadata).decode()]
                ),
                self.assertRaises(m.SetupError),
            ):
                ceremony.attach(image, mount)
            self.assertEqual(ceremony.mounts, [mount])

    def test_stale_unrelated_image_does_not_break_mount_verification(self):
        with TemporaryDirectory() as tmp:
            image = Path(tmp) / "image.dmg"
            image.touch()
            mount = Path(tmp) / "mounted"
            metadata = {
                "images": [
                    {
                        "image-path": str(Path(tmp) / "removed.dmg"),
                        "system-entities": [],
                    },
                    {
                        "image-path": str(image),
                        "system-entities": [{"mount-point": str(mount)}],
                    },
                ]
            }
            ceremony = m.Ceremony()
            with patch.object(
                m, "run", side_effect=[None, m.plistlib.dumps(metadata).decode()]
            ):
                ceremony.attach(image, mount)
            self.assertEqual(ceremony.mounts, [mount])

    def test_failed_unmount_remains_reported(self):
        ceremony = m.Ceremony()
        ceremony.mounts = [Path("/example/mount")]
        with (
            patch.object(m, "run", side_effect=m.SetupError("busy")),
            patch.object(m.sys, "stderr", new_callable=io.StringIO) as stderr,
        ):
            ceremony.cleanup()
            self.assertIn("STILL MOUNTED", stderr.getvalue())
        self.assertEqual(ceremony.mounts, [Path("/example/mount")])

    def test_cleanup_attempts_unmount_even_if_agent_cleanup_fails(self):
        ceremony = m.Ceremony()
        ceremony.mounts = [Path("/example/mount")]
        with (
            patch.object(
                ceremony, "kill_agents", side_effect=m.SetupError("agent error")
            ),
            patch.object(m, "run"),
            patch.object(m.sys, "stderr", new_callable=io.StringIO),
        ):
            ceremony.cleanup()
        self.assertEqual(ceremony.mounts, [])

    def test_agent_cleanup_attempts_every_home(self):
        with TemporaryDirectory() as tmp:
            ceremony = m.Ceremony()
            ceremony.homes = [Path(tmp) / "first", Path(tmp) / "second"]
            for home in ceremony.homes:
                home.mkdir()
            with patch.object(
                m, "run", side_effect=[OSError("first agent failed"), None]
            ) as run:
                with self.assertRaises(m.SetupError):
                    ceremony.kill_agents()
                self.assertEqual(run.call_count, 2)

    def test_cleanup_continues_after_oserror(self):
        ceremony = m.Ceremony()
        ceremony.mounts = [Path("/example/first"), Path("/example/second")]
        with (
            patch.object(ceremony, "kill_agents", side_effect=OSError("agent error")),
            patch.object(m, "run", side_effect=[OSError("busy"), None]),
            patch.object(m.sys, "stderr", new_callable=io.StringIO) as stderr,
        ):
            ceremony.cleanup()
            self.assertIn("STILL MOUNTED: /example/second", stderr.getvalue())
        self.assertEqual(ceremony.mounts, [Path("/example/second")])

    def test_unexpected_exception_still_invokes_cleanup(self):
        ceremony = m.Ceremony()
        with (
            TemporaryDirectory() as tmp,
            patch.object(m, "OUTPUT", Path(tmp)),
            patch.object(m, "configure"),
            patch.object(m.resource, "setrlimit"),
            patch.object(m.sys, "platform", "darwin"),
            patch.object(m, "Ceremony", return_value=ceremony),
            patch.object(m, "prerequisites", return_value={}),
            patch.object(
                ceremony, "execute", side_effect=ValueError("unexpected metadata")
            ),
            patch.object(ceremony, "cleanup") as cleanup,
            patch.object(m.sys, "argv", [str(source)]),
            patch.object(m.signal, "signal"),
            patch.object(m.os, "umask"),
            patch.object(m.sys.stdin, "isatty", return_value=False),
            patch.object(m.sys, "stderr", new_callable=io.StringIO),
        ):
            self.assertEqual(m.main(), 1)
            cleanup.assert_called_once()

    def test_bare_ctrl_c_reports_interruption_and_cleans_up(self):
        ceremony = m.Ceremony()
        with (
            TemporaryDirectory() as tmp,
            patch.object(m, "OUTPUT", Path(tmp)),
            patch.object(m, "configure"),
            patch.object(m.resource, "setrlimit"),
            patch.object(m.sys, "platform", "darwin"),
            patch.object(m, "Ceremony", return_value=ceremony),
            patch.object(m, "prerequisites", return_value={}),
            patch.object(ceremony, "execute", side_effect=KeyboardInterrupt()),
            patch.object(ceremony, "cleanup") as cleanup,
            patch.object(m.sys, "argv", [str(source)]),
            patch.object(m.signal, "signal"),
            patch.object(m.os, "umask"),
            patch.object(m.sys.stdin, "isatty", return_value=False),
            patch.object(m.sys, "stderr", new_callable=io.StringIO) as stderr,
        ):
            self.assertEqual(m.main(), 1)
            cleanup.assert_called_once()
            self.assertIn("STOPPED: Interrupted.", stderr.getvalue())

    def test_generated_homes_disable_external_cache_and_network_lookup(self):
        with (
            TemporaryDirectory() as tmp,
            patch.object(m, "MOUNT", Path(tmp)),
            patch.object(m.shutil, "which", return_value="/pinentry-mac"),
        ):
            home = m.Ceremony().new_home("fixture")
            config = (home / "gpg-agent.conf").read_text()
            self.assertIn("no-allow-external-cache\n", config)
            self.assertIn("enforce-passphrase-constraints\n", config)
            self.assertIn("disable-dirmngr\n", (home / "gpg.conf").read_text())

    def test_parser_rejects_unknown_or_incomplete_layout(self):
        for text in (
            "something else",
            "OpenPGP version: 3.4\nApplication version: 5.7.1\nPIN tries remaining: 3\nReset code tries remaining: 0\nAdmin PIN tries remaining: 3\nRequire PIN for signature: Once\nKDF enabled: False\nSignature key:",
            "OpenPGP version: 3.4\nApplication version: 5.7.1\nPIN tries remaining: 3\nReset code tries remaining: 0\nAdmin PIN tries remaining: 3\nRequire PIN for signature: Once\nKDF enabled: False\nSignature key:\n Fingerprint: invalid",
            "OpenPGP version: 3.4\nApplication version: 5.7.1\nPIN tries remaining: 3\nReset code tries remaining: 0\nAdmin PIN tries remaining: 3\nRequire PIN for signature: Once\nKDF enabled: False\nUnexpected key:",
        ):
            with self.subTest(text=text), self.assertRaises(m.SetupError):
                m.card_fingerprints(text)

    def test_colon_separated_encryption_fingerprint_is_supported(self):
        self.assertEqual(
            m.card_fingerprints(
                "OpenPGP version: 3.4\nApplication version: 5.7.1\nPIN tries remaining: 3\nReset code tries remaining: 0\nAdmin PIN tries remaining: 3\nRequire PIN for signature: Once\nKDF enabled: False\nEncryption key:\n Fingerprint: "
                + ":".join(["AB"] * 20)
            ),
            {"dec": "AB" * 20},
        )

    def test_resume_slot_check_accepts_only_matching_subset(self):
        expected = {"sig": "AA" * 20, "dec": "BB" * 20, "aut": "CC" * 20}
        info = (
            "OpenPGP version: 3.4\nApplication version: 5.7.1\nPIN tries remaining: 3\nReset code tries remaining: 0\nAdmin PIN tries remaining: 3\nRequire PIN for signature: Once\nKDF enabled: False\nSignature key:\n Fingerprint: "
            + "AA" * 20
        )
        self.assertEqual(m.compatible_slots(info, expected), {"sig": "AA" * 20})
        with self.assertRaises(m.SetupError):
            m.compatible_slots(info.replace("AA" * 20, "DD" * 20), expected)

    def test_public_outputs_are_complete_repeatable_and_never_replace_different_data(
        self,
    ):
        with TemporaryDirectory() as tmp, patch.object(m, "OUTPUT", Path(tmp)):
            m.publish_public("public.asc", b"public fixture")
            m.publish_public("public.asc", b"public fixture")
            with self.assertRaises(m.SetupError):
                m.publish_public("public.asc", b"different identity")
            self.assertEqual((Path(tmp) / "public.asc").read_bytes(), b"public fixture")
            self.assertEqual([p.name for p in Path(tmp).iterdir()], ["public.asc"])

    def test_resume_refuses_generation_that_has_no_complete_exports(self):
        with TemporaryDirectory() as tmp, patch.object(m, "MOUNT", Path(tmp)):
            ceremony = m.Ceremony()
            ceremony.state = {
                "identity": m.IDENTITY,
                "serial": m.SERIAL,
                "piv_before": {},
            }
            ceremony.checkpoint(phase="generation_complete")
            with (
                patch.object(ceremony, "attach"),
                patch.object(ceremony, "finish") as finish,
            ):
                with self.assertRaises(m.SetupError):
                    ceremony.resume({})
                finish.assert_not_called()
            self.assertEqual(
                m.json.loads((Path(tmp) / "ceremony-state.json").read_text())["phase"],
                "generation_complete",
            )

    def test_resume_refuses_changed_piv_snapshot(self):
        with TemporaryDirectory() as tmp, patch.object(m, "MOUNT", Path(tmp)):
            ceremony = m.Ceremony()
            ceremony.state = {
                "identity": m.IDENTITY,
                "serial": m.SERIAL,
                "piv_before": {"9A": "old"},
            }
            ceremony.checkpoint(phase="exports_ready")
            with (
                patch.object(ceremony, "attach"),
                patch.object(ceremony, "finish") as finish,
            ):
                with self.assertRaises(m.SetupError):
                    ceremony.resume({"9A": "new"})
                finish.assert_not_called()

    def test_resume_reuses_saved_identity_and_original_piv_snapshot(self):
        with TemporaryDirectory() as tmp, patch.object(m, "MOUNT", Path(tmp)):
            (Path(tmp) / "generation-keyring").mkdir()
            ceremony = m.Ceremony()
            fprs = [character * 40 for character in "ABCD"]
            piv = {"9A": "certificate-a", "9D": "certificate-d"}
            ceremony.state = {
                "identity": m.IDENTITY,
                "serial": m.SERIAL,
                "piv_before": piv,
            }
            ceremony.checkpoint(phase="exports_ready", fingerprints=fprs)
            backup = Path(tmp) / "gpg" / fprs[0]
            backup.mkdir(parents=True)
            for name in ("cert.asc", "cert.gpg", "paperkey.txt"):
                (backup / name).write_text("dummy fixture")
            listing = "\n".join("fpr:::::::::" + fpr + ":" for fpr in fprs)
            with (
                patch.object(ceremony, "attach"),
                patch.object(ceremony, "kill_agents"),
                patch.object(ceremony, "gpg", return_value=listing) as gpg,
                patch.object(
                    m,
                    "target_only",
                    return_value="OpenPGP version: 3.4\nApplication version: 5.7.1\nPIN tries remaining: 3\nReset code tries remaining: 0\nAdmin PIN tries remaining: 3\nRequire PIN for signature: Once\nKDF enabled: False",
                ),
                patch.object(ceremony, "finish") as finish,
            ):
                ceremony.resume(piv)
                finish.assert_called_once_with(
                    piv, Path(tmp) / "generation-keyring", fprs[0], resume=True
                )
                self.assertTrue(
                    all(
                        "--quick-generate-key" not in call.args
                        for call in gpg.call_args_list
                    )
                )

    def test_resume_rejects_mismatched_export_before_card_access(self):
        with TemporaryDirectory() as tmp, patch.object(m, "MOUNT", Path(tmp)):
            (Path(tmp) / "generation-keyring").mkdir()
            ceremony = m.Ceremony()
            ceremony.state = {
                "identity": m.IDENTITY,
                "serial": m.SERIAL,
                "piv_before": {},
            }
            ceremony.checkpoint(
                phase="exports_ready",
                fingerprints=[character * 40 for character in "ABCD"],
            )
            backup = Path(tmp) / "gpg" / ("A" * 40)
            backup.mkdir(parents=True)
            for name in ("cert.asc", "cert.gpg", "paperkey.txt"):
                (backup / name).write_text("dummy fixture")
            with (
                patch.object(ceremony, "attach"),
                patch.object(
                    ceremony, "gpg", return_value="fpr:::::::::" + "E" * 40 + ":"
                ),
                patch.object(m, "target_only") as card,
                patch.object(ceremony, "finish") as finish,
            ):
                with self.assertRaises(m.SetupError):
                    ceremony.resume({})
                card.assert_not_called()
                finish.assert_not_called()

    def test_resume_names_missing_recovery_file_before_gpg_access(self):
        with TemporaryDirectory() as tmp, patch.object(m, "MOUNT", Path(tmp)):
            ceremony = m.Ceremony()
            ceremony.state = {
                "identity": m.IDENTITY,
                "serial": m.SERIAL,
                "piv_before": {},
            }
            ceremony.checkpoint(
                phase="exports_ready",
                fingerprints=[character * 40 for character in "ABCD"],
            )
            backup = Path(tmp) / "gpg" / ("A" * 40)
            backup.mkdir(parents=True)
            (backup / "cert.asc").write_text("dummy public cert")
            with patch.object(ceremony, "attach"), patch.object(ceremony, "gpg") as gpg:
                with self.assertRaisesRegex(m.SetupError, "cert.gpg"):
                    ceremony.resume({})
                gpg.assert_not_called()

    def test_partial_touch_update_does_not_repeat_completed_slot(self):
        with TemporaryDirectory() as tmp, patch.object(m, "MOUNT", Path(tmp)):
            ceremony = m.Ceremony()
            with (
                patch.object(m, "run", side_effect=[None, m.SetupError("interrupted")]),
                self.assertRaises(m.SetupError),
            ):
                ceremony.set_touch_policies()
            resumed = m.Ceremony()
            resumed.state = m.json.loads(
                (Path(tmp) / "ceremony-state.json").read_text()
            )
            with patch.object(m, "run") as run:
                resumed.set_touch_policies()
                self.assertEqual(
                    [call.args[0][-2] for call in run.call_args_list], ["dec", "aut"]
                )

    def test_resume_does_not_close_and_reopen_an_already_opened_image(self):
        ceremony = m.Ceremony()
        with (
            patch.object(ceremony, "kill_agents"),
            patch.object(ceremony, "detach") as detach,
            patch.object(ceremony, "attach") as attach,
            patch.object(
                ceremony, "new_home", side_effect=m.SetupError("stop at restore test")
            ),
        ):
            with self.assertRaises(m.SetupError):
                ceremony.finish({}, Path("unused"), "A" * 40, resume=True)
            detach.assert_not_called()
            attach.assert_not_called()

    def test_pin_retry_runs_once_with_checkpoint_before_native_prompt(self):
        with TemporaryDirectory() as tmp, patch.object(m, "MOUNT", Path(tmp)):
            ceremony = m.Ceremony()
            ceremony.state = {"user_pin": "started", "admin_pin": "done"}

            def native_prompt(args, **kwargs):
                saved = m.json.loads((Path(tmp) / "ceremony-state.json").read_text())
                self.assertEqual(saved["user_pin"], "started")
                self.assertEqual(
                    args,
                    ["ykman", "--device", m.SERIAL, "openpgp", "access", "change-pin"],
                )

            with (
                patch("builtins.input", return_value="1"),
                patch.object(m, "run", side_effect=native_prompt) as run,
            ):
                ceremony.set_pins()
            run.assert_called_once()
            self.assertEqual(ceremony.state["user_pin"], "done")

    def test_pin_confirmed_success_skips_native_change(self):
        with TemporaryDirectory() as tmp, patch.object(m, "MOUNT", Path(tmp)):
            ceremony = m.Ceremony()
            ceremony.state = {"user_pin": "started", "admin_pin": "done"}
            with (
                patch("builtins.input", return_value="2"),
                patch.object(m, "run") as run,
            ):
                ceremony.set_pins()
            run.assert_not_called()
            saved = m.json.loads((Path(tmp) / "ceremony-state.json").read_text())
            self.assertEqual(saved["user_pin"], "done")

    def test_failed_pin_retry_stays_interrupted_and_does_not_retry_again(self):
        with TemporaryDirectory() as tmp, patch.object(m, "MOUNT", Path(tmp)):
            ceremony = m.Ceremony()
            ceremony.state = {"user_pin": "started"}
            with (
                patch("builtins.input", return_value="1"),
                patch.object(m, "run", side_effect=m.SetupError("Invalid PIN")) as run,
                self.assertRaises(m.SetupError),
            ):
                ceremony.set_pins()
            run.assert_called_once()
            self.assertEqual(ceremony.state["user_pin"], "started")
            self.assertNotIn("admin_pin", ceremony.state)

    def test_blank_or_invalid_pin_choice_never_attempts_a_pin(self):
        ceremony = m.Ceremony()
        ceremony.state = {"user_pin": "started"}
        with (
            patch("builtins.input", side_effect=["", "3", "DONE", KeyboardInterrupt]),
            patch.object(m, "run") as run,
            patch.object(ceremony, "checkpoint") as checkpoint,
            self.assertRaises(KeyboardInterrupt),
        ):
            ceremony.set_pins()
        run.assert_not_called()
        checkpoint.assert_not_called()

    def test_full_guide_is_printed_and_acknowledged_before_gpg_edit(self):
        ceremony = m.Ceremony()
        acknowledged = False
        output = io.StringIO()

        def read_guide(prompt):
            nonlocal acknowledged
            text = output.getvalue()
            for line in (
                "Select signing [S]",
                "Select encryption [E]",
                "Select authentication [A]",
                "Save card-backed stubs",
            ):
                self.assertIn(line, text)
            self.assertIn("Press Enter", prompt)
            acknowledged = True
            return ""

        def gpg(home, *args, **kwargs):
            if "--edit-key" in args:
                self.assertTrue(acknowledged)
                self.assertEqual(kwargs, {})  # Interactive I/O must remain connected.
            else:
                self.assertFalse(acknowledged)

        with (
            patch.object(m.sys, "stdout", output),
            patch("builtins.input", side_effect=read_guide),
            patch.object(ceremony, "gpg", side_effect=gpg) as gpg_call,
            patch.object(m, "run"),
        ):
            ceremony.transfer_subkeys(Path("fixture"), "A" * 40, ["sig", "dec", "aut"])
        self.assertEqual(gpg_call.call_count, 2)

    def test_partial_transfer_guide_omits_completed_slots_and_cancel_prevents_edit(
        self,
    ):
        ceremony = m.Ceremony()
        with (
            patch.object(m.sys, "stdout", new_callable=io.StringIO) as output,
            patch("builtins.input", side_effect=KeyboardInterrupt),
            patch.object(ceremony, "gpg") as gpg,
            patch.object(m, "run"),
            self.assertRaises(KeyboardInterrupt),
        ):
            ceremony.transfer_subkeys(Path("fixture"), "A" * 40, ["aut"])
        self.assertNotIn("key 1", output.getvalue())
        self.assertNotIn("key 2", output.getvalue())
        self.assertIn("key 3", output.getvalue())
        self.assertIn("normally option 3", output.getvalue())
        self.assertTrue(
            all("--edit-key" not in call.args for call in gpg.call_args_list)
        )

    def test_completed_transfers_do_not_open_gpg_or_prompt(self):
        with patch.object(m.Ceremony, "gpg") as gpg, patch("builtins.input") as prompt:
            m.Ceremony().transfer_subkeys(Path("fixture"), "A" * 40, [])
        gpg.assert_not_called()
        prompt.assert_not_called()

    def test_deferred_diagnostics_remain_visible_on_failure(self):
        result = Mock(returncode=1, stderr="gpg: verification failed\n")
        with (
            patch.object(m.subprocess, "run", return_value=result) as run,
            patch.object(m.sys, "stderr", new_callable=io.StringIO) as stderr,
            self.assertRaises(m.SetupError),
        ):
            m.run(["gpg", "--verify", "fixture.sig"], diagnostics_on_error=True)
        self.assertIn("verification failed", stderr.getvalue())
        self.assertEqual(run.call_args.kwargs["stderr"], m.subprocess.PIPE)
        self.assertNotIn("stdin", run.call_args.kwargs)

    def test_native_terminal_streams_are_inherited_by_default(self):
        with patch.object(m.subprocess, "run", return_value=Mock(returncode=0)) as run:
            m.run(["ykman", "--device", m.SERIAL, "openpgp", "access", "change-pin"])
        self.assertIsNone(run.call_args.kwargs["stdout"])
        self.assertIsNone(run.call_args.kwargs["stderr"])
        self.assertNotIn("stdin", run.call_args.kwargs)


if __name__ == "__main__":
    unittest.main()

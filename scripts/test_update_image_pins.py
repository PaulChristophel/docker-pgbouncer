"""Regression checks for base-only updates and failure handling."""

import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
import update_image_pins as updater


class PinTests(unittest.TestCase):
    """Keep source pins and independently configured build images intact."""

    def test_independent_base_and_builder(self):
        """Refresh both tagged references without changing source metadata."""
        config = {
            "pgbouncer": [{"version": "1.26.1", "commit": "keep", "sha256": "keep"}],
            "distributions": {"alma": {"base": "runtime", "build_base": "builder"}},
        }
        with patch.object(
            updater, "current_base_digest", side_effect=lambda ref: ref + "-new"
        ) as resolve:
            self.assertEqual(len(updater.update_base_images(config)), 2)
        self.assertEqual(
            [c.args[0] for c in resolve.call_args_list], ["runtime", "builder"]
        )
        self.assertEqual(
            config["pgbouncer"][0],
            {"version": "1.26.1", "commit": "keep", "sha256": "keep"},
        )

    def test_invalid_registry_digest(self):
        """Reject truncated registry digest responses."""
        with patch.object(
            updater,
            "fetch_response",
            return_value=("{}", {"docker-content-digest": "sha256:aa"}),
        ):
            with self.assertRaises(RuntimeError):
                updater.current_base_digest("docker.io/almalinux:10@sha256:" + "a" * 64)

    def test_check_and_failure_never_write(self):
        """Leave the manifest intact in check mode and after a failed lookup."""
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "images.json"
            original = json.dumps(
                {
                    "distributions": {
                        "alma": {"base": "runtime", "build_base": "builder"}
                    }
                }
            )
            path.write_text(original)
            with patch(
                "sys.argv", ["updater", "--config", str(path), "--check"]
            ), patch.object(updater, "current_base_digest", return_value="new"):
                self.assertEqual(updater.main(), 1)
            self.assertEqual(path.read_text(), original)
            with patch("sys.argv", ["updater", "--config", str(path)]), patch.object(
                updater,
                "current_base_digest",
                side_effect=["new", RuntimeError("unavailable")],
            ):
                with self.assertRaises(RuntimeError):
                    updater.main()
            self.assertEqual(path.read_text(), original)


if __name__ == "__main__":
    unittest.main()

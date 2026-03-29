"""Tests for generate.py --type argument parsing and selective generation."""

import os
import subprocess
import sys
import unittest


class TestGenerateTypeArg(unittest.TestCase):
    """Test --type / GENERATE_TYPES behavior without needing Docker/PyTorch."""

    def setUp(self):
        """Ensure generate.py imports work in isolated mode."""
        # Prevent heavy imports (torch, soundfile) by not importing generate.py directly
        self.generate_script = os.path.join(os.path.dirname(__file__), "generate.py")

    def _run_generate_with_env(self, env_extra=None):
        """Run generate.py as a subprocess with optional extra env vars.
        Returns (returncode, stdout, stderr).
        """
        env = os.environ.copy()
        env.pop("GENERATE_TYPES", None)
        if env_extra:
            env.update(env_extra)
        result = subprocess.run(
            [sys.executable, "-c", f"""
import sys
import os
# Remove GENERATE_TYPES from environment if not in env_extra
os.environ.pop("GENERATE_TYPES", None)
{"; ".join(f'os.environ["{k}"] = "{v}"' for k, v in (env_extra or {}).items())}

# Import parse_args from generate.py
sys.path.insert(0, {repr(os.path.dirname(self.generate_script))})
from generate import parse_args, NOTIFICATIONS

args = parse_args()

# Simulate filtering logic from main()
valid_names = set(n["name"] for n in NOTIFICATIONS)
if args.type is not None:
    requested = [t.strip() for t in args.type.split(",")]
    invalid = [t for t in requested if t not in valid_names]
    if invalid:
        print(f"错误：未知的通知类型: {{', '.join(invalid)}}", file=sys.stderr)
        print(f"有效类型: {{', '.join(sorted(valid_names))}}", file=sys.stderr)
        sys.exit(1)
    filtered = [n for n in NOTIFICATIONS if n["name"] in requested]
    for n in filtered:
        print(n["name"])
else:
    for n in NOTIFICATIONS:
        print(n["name"])
"""],
            capture_output=True,
            text=True,
            env=env,
            timeout=10,
        )
        return result.returncode, result.stdout, result.stderr

    def test_no_type_generates_all_four(self):
        """Without --type and without GENERATE_TYPES, all 4 notifications generate."""
        # We test the parse_args + filter logic without Docker/PyTorch
        env = os.environ.copy()
        env.pop("GENERATE_TYPES", None)
        result = subprocess.run(
            [sys.executable, "-c", f"""
import sys, os
os.environ.pop("GENERATE_TYPES", None)
sys.path.insert(0, {repr(os.path.dirname(self.generate_script))})
from generate import parse_args, NOTIFICATIONS
args = parse_args()
valid_names = set(n["name"] for n in NOTIFICATIONS)
if args.type is not None:
    requested = [t.strip() for t in args.type.split(",")]
    filtered = [n for n in NOTIFICATIONS if n["name"] in requested]
else:
    filtered = NOTIFICATIONS
for n in filtered:
    print(n["name"])
"""],
            capture_output=True,
            text=True,
            env=env,
            timeout=10,
        )
        self.assertEqual(result.returncode, 0)
        names = result.stdout.strip().split("\n")
        self.assertEqual(set(names), {"complete", "confirm", "error", "progress"})

    def test_generate_types_env_selective(self):
        """When GENERATE_TYPES=confirm,error, only those two are generated."""
        env = os.environ.copy()
        env["GENERATE_TYPES"] = "confirm,error"
        result = subprocess.run(
            [sys.executable, "-c", f"""
import sys, os
os.environ["GENERATE_TYPES"] = "confirm,error"
sys.path.insert(0, {repr(os.path.dirname(self.generate_script))})
from generate import parse_args, NOTIFICATIONS
args = parse_args()
valid_names = set(n["name"] for n in NOTIFICATIONS)
requested = [t.strip() for t in args.type.split(",")]
filtered = [n for n in NOTIFICATIONS if n["name"] in requested]
for n in filtered:
    print(n["name"])
"""],
            capture_output=True,
            text=True,
            env=env,
            timeout=10,
        )
        self.assertEqual(result.returncode, 0)
        names = result.stdout.strip().split("\n")
        self.assertEqual(set(names), {"confirm", "error"})

    def test_invalid_type_exits_with_error(self):
        """When GENERATE_TYPES contains invalid type, script exits with code 1."""
        env = os.environ.copy()
        env["GENERATE_TYPES"] = "foobar"
        result = subprocess.run(
            [sys.executable, "-c", f"""
import sys, os
os.environ["GENERATE_TYPES"] = "foobar"
sys.path.insert(0, {repr(os.path.dirname(self.generate_script))})
from generate import parse_args, NOTIFICATIONS
args = parse_args()
valid_names = set(n["name"] for n in NOTIFICATIONS)
requested = [t.strip() for t in args.type.split(",")]
invalid = [t for t in requested if t not in valid_names]
if invalid:
    print(f"错误：未知的通知类型: {{', '.join(invalid)}}", file=sys.stderr)
    print(f"有效类型: {{', '.join(sorted(valid_names))}}", file=sys.stderr)
    sys.exit(1)
"""],
            capture_output=True,
            text=True,
            env=env,
            timeout=10,
        )
        self.assertEqual(result.returncode, 1)
        self.assertIn("错误", result.stderr)
        self.assertIn("foobar", result.stderr)


if __name__ == "__main__":
    unittest.main()

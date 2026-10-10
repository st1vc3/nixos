"""Exercise the upgrade shell function with isolated Git repositories."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ALIASES = Path(__file__).resolve().parents[1] / "config/zsh/aliases.zsh"

SHELL = r"""
compdef() { :; }
source "$UPGRADE_ALIASES"
git() {
  print -r -- "git $*" >> "$UPGRADE_EVENTS"
  shift 2
  command git -C "$UPGRADE_FIXTURE" "$@"
}
nix() {
  print -r -- "nix $*" >> "$UPGRADE_EVENTS"
  case "$1" in
    flake)
      if [[ "$UPGRADE_CHANGE" == 1 ]]; then
        print -r -- updated-lock > "$UPGRADE_FIXTURE/flake.lock"
      fi
      ;;
    run)
      (( UPGRADE_REFRESH_RESULT == 0 )) || return "$UPGRADE_REFRESH_RESULT"
      if [[ "$UPGRADE_CHANGE" == 1 ]]; then
        print -r -- updated-package > "$UPGRADE_FIXTURE/pkgs/curseforge.nix"
      fi
      ;;
    build) return "$UPGRADE_BUILD_RESULT" ;;
  esac
}
sudo() {
  print -r -- "sudo $*" >> "$UPGRADE_EVENTS"
  if [[ "$1" == nix-collect-garbage ]]; then
    return "$UPGRADE_GC_RESULT"
  fi
}
upgrade
exit $?
"""


class UpgradeWorkflowTests(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory()
        self.addCleanup(self.scratch.cleanup)
        self.repo = Path(self.scratch.name)
        (self.repo / "pkgs").mkdir()
        (self.repo / "flake.lock").write_text("old-lock\n")
        (self.repo / "pkgs/curseforge.nix").write_text("old-package\n")
        (self.repo / "unrelated.txt").write_text("original\n")
        self.git("init", "-q")
        self.git("config", "user.name", "Upgrade test")
        self.git("config", "user.email", "upgrade-test@example.invalid")
        self.git("config", "commit.gpgsign", "false")
        self.git("add", ".")
        self.git("commit", "-qm", "initial")
        self.before = self.git("rev-parse", "HEAD")
        (self.repo / "unrelated.txt").write_text("user change\n")
        self.git("add", "unrelated.txt")
        self.events = self.repo / "events"

    def git(self, *args):
        return subprocess.check_output(
            ["git", "-C", str(self.repo), *args], text=True
        ).strip()

    def run_upgrade(self, **overrides):
        environment = {
            **os.environ,
            "UPGRADE_ALIASES": str(ALIASES),
            "UPGRADE_FIXTURE": str(self.repo),
            "UPGRADE_EVENTS": str(self.events),
            "UPGRADE_CHANGE": "1",
            "UPGRADE_REFRESH_RESULT": "0",
            "UPGRADE_BUILD_RESULT": "0",
            "UPGRADE_GC_RESULT": "0",
            **overrides,
        }
        result = subprocess.run(
            ["zsh", "-f", "-c", SHELL], env=environment, text=True, capture_output=True
        )
        return result, self.events.read_text()

    def test_success_commits_only_updates_after_build(self):
        result, events = self.run_upgrade()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertLess(events.index("nix run"), events.index("nix build"))
        self.assertLess(events.index("nix build"), events.index("commit -m"))
        self.assertLess(events.index("commit -m"), events.index("sudo nixos-rebuild"))
        self.assertEqual(
            self.git("diff-tree", "--no-commit-id", "--name-only", "-r", "HEAD"),
            "flake.lock\npkgs/curseforge.nix",
        )
        self.assertEqual(self.git("diff", "--cached", "--name-only"), "unrelated.txt")

    def test_failed_build_does_not_commit_or_install(self):
        result, events = self.run_upgrade(UPGRADE_BUILD_RESULT="42")
        self.assertEqual(result.returncode, 42)
        self.assertEqual(self.git("rev-parse", "HEAD"), self.before)
        self.assertNotIn("git ", events)
        self.assertNotIn("sudo ", events)
        self.assertIn(
            "updated-package", (self.repo / "pkgs/curseforge.nix").read_text()
        )

    def test_failed_refresh_does_not_build_or_commit(self):
        result, events = self.run_upgrade(UPGRADE_REFRESH_RESULT="43")
        self.assertEqual(result.returncode, 43)
        self.assertNotIn("nix build", events)
        self.assertNotIn("git ", events)
        self.assertNotIn("sudo ", events)

    def test_no_changes_skips_commit_and_preserves_user_index(self):
        result, events = self.run_upgrade(UPGRADE_CHANGE="0")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("commit -m", events)
        self.assertEqual(self.git("rev-parse", "HEAD"), self.before)
        self.assertEqual(self.git("diff", "--cached", "--name-only"), "unrelated.txt")

    def test_failed_cleanup_returns_failure(self):
        result, events = self.run_upgrade(UPGRADE_GC_RESULT="44")
        self.assertEqual(result.returncode, 44)
        self.assertIn("sudo nixos-rebuild", events)
        self.assertNotIn("Upgrade staged as boot default", result.stdout)


if __name__ == "__main__":
    unittest.main()

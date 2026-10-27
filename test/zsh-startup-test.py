#!/usr/bin/env python3
import os
from pathlib import Path
import shlex
import shutil
import socket
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[1]


class ZshStartupTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.zsh = shutil.which("zsh")
        cls.script = shutil.which("script")
        if not cls.zsh or not cls.script:
            raise RuntimeError("Tests require Zsh and util-linux script.")
        cls.fpath = subprocess.check_output(
            [cls.zsh, "-fc", 'print -r -- "${(j.:.)fpath}"'], text=True
        ).strip()

    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="dotfiles-zsh-test-")
        self.addCleanup(temporary.cleanup)
        self.home = Path(temporary.name)
        self.calls = self.home / "calls"
        self.bin = self.home / "bin"
        self.bin.mkdir()
        self.config = self.home / ".config/zsh"
        (self.config / "scripts").mkdir(parents=True)
        for source, destination in (
            ("env/env-linux", self.home / ".env"),
            ("zsh/zsh-envs", self.home / ".zshenv"),
            ("zsh/zsh-config", self.config / ".zshrc"),
            ("zsh/scripts/keychain-setup.zsh", self.config / "scripts/keychain-setup.zsh"),
        ):
            destination.write_text((SOURCE / source).read_text())

        # Exercise the real startup files without network, plugins, or real agents.
        (self.config / "scripts/update-plugins.zsh").write_text(
            "cloneOrUpdatePlugin() { :; }\n"
        )
        for plugin in (
            "zsh-autosuggestions/zsh-autosuggestions.zsh",
            "zsh-syntax-highlighting/zsh-syntax-highlighting.zsh",
            "fzf-tab/fzf-tab.plugin.zsh",
            "zsh-ssh/zsh-ssh.zsh",
            "zsh-active-cheatsheet/zsh-active-cheatsheet.plugin.zsh",
        ):
            path = self.config / "plugins" / plugin
            path.parent.mkdir(parents=True)
            path.write_text("")
        aliases = self.home / ".config/aliases"
        aliases.mkdir()
        (aliases / "aliases").write_text("")
        functions = self.home / "functions"
        functions.mkdir()
        (functions / "compinit").write_text("compdef() { :; }\n_comp_options=()\n")
        self.stub("keychain", 'printf "export TEST_AGENT_LOADED=yes\\n"\n')
        self.stub("tty", "exec /usr/bin/tty\n")
        self.stub("oh-my-posh")
        self.stub("fastfetch")
        self.stub("git", 'echo "Unexpected git invocation" >&2\nexit 1\n')
        self.env = {
            "HOME": str(self.home),
            "PATH": f"{self.bin}:/usr/bin:/bin",
            "TERM": "dumb",
            "LANG": "C.UTF-8",
            "LC_ALL": "C.UTF-8",
            "FPATH": f"{functions}:{self.fpath}",
        }
        if "LD_LIBRARY_PATH" in os.environ:
            self.env["LD_LIBRARY_PATH"] = os.environ["LD_LIBRARY_PATH"]

    def stub(self, name, body=""):
        path = self.bin / name
        path.write_text(
            '#!/bin/sh\nprintf "%s|%s|%s\\n" "${0##*/}" "$*" "${GPG_TTY-}"'
            ' >> "$HOME/calls"\n' + body
        )
        path.chmod(0o700)

    def add_keys(self):
        keys = self.home / ".ssh/keys"
        keys.mkdir(parents=True)
        (keys / "test_ed25519").write_text("dummy key, never passed to a real agent\n")
        self.add_gpg_id()

    def add_gpg_id(self):
        store = self.home / ".password-store"
        store.mkdir()
        (store / ".gpg-id").write_text("dummy-gpg-id\n")

    def run_shell(self, flags, terminal=False, command=None):
        command = command or (
            'print -r -- "SESSION_READY|${GPG_TTY-unset}|'
            '${SSH_AUTH_SOCK-unset}|${TEST_AGENT_LOADED-unset}"'
        )
        args = [self.zsh, flags, command]
        if terminal:
            args = [self.script, "-qec", shlex.join(args), "/dev/null"]
        result = subprocess.run(
            args, env=self.env, stdin=subprocess.DEVNULL,
            capture_output=True, text=True, timeout=10,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stderr, "")
        self.assertIn("SESSION_READY", result.stdout)
        self.assertNotIn("no matches found", result.stdout)
        self.assertNotIn("not a tty", result.stdout)
        self.assertNotIn("command not found", result.stdout)
        self.assertNotIn("failed to load module", result.stdout)
        if any(call.startswith("keychain|") for call in self.read_calls()):
            self.assertIn("|yes", result.stdout)
        return result.stdout

    def read_calls(self):
        return self.calls.read_text().splitlines() if self.calls.exists() else []

    def assert_terminal_agents(self, ssh=True):
        calls = self.read_calls()
        agents = [call for call in calls if call.startswith("keychain|")]
        self.assertEqual(len(agents), 2 if ssh else 1, calls)
        self.assertIn("tty||", calls)
        self.assertTrue(all(call.split("|")[2].startswith("/dev/") for call in agents))
        self.assertTrue(any("--agents gpg" in call for call in agents))
        self.assertEqual(any("--agents ssh" in call for call in agents), ssh)
        self.assertLess(calls.index("tty||"), calls.index(agents[0]))

    def test_desktop_login_without_terminal(self):
        self.add_keys()
        output = self.run_shell("-lc")
        self.assertIn("SESSION_READY|unset|unset|unset", output)
        self.assertEqual(self.read_calls(), [])

    def test_noninteractive_login_even_with_terminal(self):
        self.add_keys()
        self.run_shell("-lc", terminal=True)
        self.assertEqual(self.read_calls(), [])

    def test_noninteractive_remote_command(self):
        self.add_keys()
        self.env["SSH_AUTH_SOCK"] = "/inherited/agent.sock"
        self.env["GPG_TTY"] = "/dev/inherited"
        output = self.run_shell("-c")
        self.assertIn("SESSION_READY|/dev/inherited|/inherited/agent.sock|unset", output)
        self.assertEqual(self.read_calls(), [])

    def test_interactive_without_terminal(self):
        self.add_keys()
        self.run_shell("-ic")
        self.assertFalse(any(call.startswith(("keychain|", "tty|")) for call in self.read_calls()))

    def test_headless_ssh_login(self):
        self.add_keys()
        self.env["SSH_CONNECTION"] = "192.0.2.1 1234 192.0.2.2 22"
        self.run_shell("-lic", terminal=True)
        self.assert_terminal_agents()

    def test_desktop_terminal(self):
        self.add_keys()
        self.env["DISPLAY"] = ":0"
        self.run_shell("-ic", terminal=True)
        self.assert_terminal_agents()

    def test_tmux_terminal(self):
        self.add_keys()
        self.env["TMUX"] = "/tmp/dummy-tmux,123,0"
        self.run_shell("-lic", terminal=True)
        self.assert_terminal_agents()
        self.assertFalse(any(call.startswith("fastfetch|") for call in self.read_calls()))

    def test_missing_and_empty_ssh_key_directory(self):
        self.add_gpg_id()
        for exists in (False, True):
            with self.subTest(directory_exists=exists):
                if exists:
                    (self.home / ".ssh/keys").mkdir(parents=True)
                    self.calls.unlink()
                self.run_shell("-lic", terminal=True)
                self.assert_terminal_agents(ssh=False)

    def test_terminal_without_any_keys(self):
        self.run_shell("-lic", terminal=True)
        self.assertFalse(any(call.startswith("keychain|") for call in self.read_calls()))

    def test_existing_ssh_agent_is_preserved(self):
        self.add_keys()
        with socket.socket(socket.AF_UNIX) as agent:
            address = str(self.home / "agent.sock")
            agent.bind(address)
            self.env["SSH_AUTH_SOCK"] = address
            output = self.run_shell("-lic", terminal=True)
            self.assertIn(address, output)
            self.assert_terminal_agents(ssh=False)

    def test_noninteractive_bash_environment_loading(self):
        result = subprocess.run(
            ["bash", "-c", 'source "$HOME/.env"; printf "%s" "$XDG_DATA_HOME"'],
            env=self.env, stdin=subprocess.DEVNULL, capture_output=True, text=True,
            timeout=10,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, str(self.home / ".config/local/share"))
        self.assertEqual(self.read_calls(), [])


if __name__ == "__main__":
    unittest.main(verbosity=2)

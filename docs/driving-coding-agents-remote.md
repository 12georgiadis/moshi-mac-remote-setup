# Driving coding agents from your phone: Remote Control vs SSH-terminal vs per-tool apps — a field guide

*A practical, hard-won guide to reaching your AI coding-agent sessions (Claude Code, Codex) from a phone or another machine. Field notes, comparison, and the gotchas that cost hours.*

> Licence : texte CC BY-NC-ND 4.0.

## TL;DR
- **Native Remote Control** (the agent's own app: Claude app for Claude Code, ChatGPT app for Codex) = your **daily driver**. The session runs **locally on your machine**; the phone reads output, sends prompts, gets notifications. Zero SSH, zero keys, zero VPN config.
- **SSH terminal** (a mobile SSH/mosh client + `tmux`) = your **power tool and safety net**. It's the only thing that gives you a **full shell** (launch anything, any agent, non-agent commands) and survives crashes/disconnects because the session lives in `tmux`.
- **Per-tool mobile apps** (e.g. a terminal multiplexer's companion app) = often **redundant or paid**. Nice native UI, but rarely a new capability if you already have the two above.

## Where the session actually runs (the thing people get wrong)
| Mode | Where it executes | Reaches your local files? |
|---|---|---|
| Native Remote Control | **your machine** (local) | ✅ full local filesystem, tools, MCP, config |
| Cloud/web sessions | provider's cloud VM | ❌ only the connected git repo |
| SSH terminal | the machine you SSH into | ✅ that machine's everything |

If you want to "tidy my folders" or run local scripts from your phone → **Remote Control or SSH**, never cloud sessions.

## Persistence truth
Persistence does **not** come from the remote tool. It comes from **tmux** (or the agent's own session store + resume).
- Remote Control is a **bridge**. If it drops, you relaunch it — but the underlying session **survives in tmux**.
- An SSH client "survives crashes" only because it reattaches to the persistent `tmux` session underneath.
- So: keep your agent sessions inside `tmux`. The remote tool is just the window.

## The gotchas (the actual gold)
1. **Auto-pairing (QR / mDNS / "easy pair") silently dies behind router *client isolation*.** Many home routers (and guest/mesh setups) block device-to-device traffic. Symptom: your laptop and phone are "on the same Wi-Fi" but can't reach each other; a VPN mesh path even degrades from direct peer-to-peer to a gateway-NAT hairpin. **Fix: stop using the `.local`/mDNS pairing; connect by the VPN IP (Tailscale/WireGuard).**
2. **"Authentication failed" with a valid key = wrong username.** SSH looks for `authorized_keys` *inside the target account*. A short/typo'd username → no match → fail, before the key is even tried. Use the exact OS account name.
3. **"Connection error" with key auth = the auth mode is set to *password* (empty)** while the server only accepts keys. Switch the client to key-file auth and actually load a key.
4. **macOS `sshd` logging is silent by default.** You won't see auth attempts in the unified log. Diagnose key auth with a **loopback self-test**: `ssh -F /dev/null -i <key> -o IdentitiesOnly=yes -o BatchMode=yes user@127.0.0.1 'echo OK'`. `OK` = server side fine, problem is the client. `Permission denied (publickey)` = the public key isn't in `authorized_keys`.
5. **Split "network" from "auth" with a dumb TCP test.** Run a throwaway HTTP server (`python3 -m http.server 8080 --bind 0.0.0.0`) on the host, hit `http://<host>:8080` from the phone. Page loads → the network path works, so any SSH failure is auth, not reachability.

## Auditing your custom hacks against the tool's new native features
Terminals/multiplexers update fast. Before trusting your old workarounds, **diff them against current native features**:
- Many ship **native session restore**, **idle-agent hibernation**, and **per-workspace memory/top** that supersede hand-rolled restore scripts and "close tabs to save RAM" discipline.
- But verify what they *don't* do: e.g. a multiplexer may restore the **layout** after a crash but **not** the agent sessions inside (you still `--resume` manually), and may name underlying `tmux` sessions with raw tty ids (titles don't propagate) — so a renamer script can still be required.
- Watch for **shims on `$PATH`**: a bundled fake `tmux` that routes to the app's own model. Scripts that need the *real* tmux must call its absolute path explicitly.

## Fleet patterns (multi-machine)
- **Run heavy / always-on work on an always-on box; drive it from the laptop and phone.** This dissolves the "my laptop swaps and crashes with too many sessions" problem at the root: the laptop becomes a client, not the workhorse.
- **You don't sync everything.** Sync **config + memory + conversation state** (small) so every machine behaves the same and you can resume anywhere. Keep heavy media where it lives. Use **continuous folder sync over your VPN** (e.g. Syncthing over Tailscale) for the small stuff, git for code.
- **Never sync secrets.** Keys/tokens/credentials stay local or in a vault, excluded from sync.
- **Multi-model orchestration.** One model orchestrates/reflects and delegates heavy execution to another model's CLI (e.g. `codex exec`), then reviews the result. Spreads cost across subscriptions and catches each model's mistakes.

## Verify before you migrate
Before promoting a second machine to "the brain", **run a parity test**: inventory both (agent version, language runtimes, the CLIs you depend on, your config/skills/scripts counts, disk, login state) and diff. "It's also a Mac" is not parity — you'll find missing CLIs and a config that's weeks behind. Close the gaps, re-test, *then* rely on it.

---
*Field notes from a real multi-machine setup. No infrastructure details included by design.*

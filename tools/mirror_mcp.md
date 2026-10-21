# elpida-mirror — a read-only MCP mirror of the chamber's public pulse (v0.1, drafted 2026-10-21)

*A mirror, not a door. It lets any MCP client (Claude, or any agent that speaks the Model Context Protocol)
see what koina sees, with no key, no account and no write path. Nothing here is ratified. A0 holds.*

## 1. What it is

`tools/mirror_mcp.py` is an MCP server that runs on your own machine and talks to your client over stdio.
Every request it makes goes through koina's own network seam (`tools/koina.py`), so koina's fence holds
unchanged: GET/HEAD only, https only, three hosts only (the WORLD bucket on S3, `raw.githubusercontent.com`,
`api.github.com`), redirects elsewhere refused, no retries, at most 20 s per socket operation, 16 MiB per body.

Three of its tools mirror koina's readings (`read`, `verify`, and the network half of `inbox`). Two add reads
on the same hosts: more of the D15 tail, and a fixed list of chamber files that koina.md §4 does not list.

It is a **mirror** because it shows the organism's published surface as it stands, from your standpoint, and
changes nothing. It is not a **door**: it cannot put a question to the parliament, reach the keyed Watchtower
audit, read the private brain, or write anywhere.

## 2. What you need

- Python 3.10 or newer. Standard library only; nothing to install.
- Two files from this repo, side by side: `tools/koina.py` and `tools/mirror_mcp.py`. Put them in **a new,
  empty folder of your own** (not Downloads), or keep a clone of the public repo, which needs no account.
  The mirror loads `koina.py` by its path. Under `python -I` on Python 3.11 or newer, no other file in that
  folder can stand in for a standard module; on 3.10 the empty folder is the protection.
- Run your own agent from your own project, not from inside a chamber clone: the clone's CLAUDE.md is written
  for the chamber's own agent.

## 3. Connecting a client

Claude Code, available in every project:

```bash
claude mcp add --scope user elpida-mirror -- python3 -I /absolute/path/to/mirror_mcp.py
```

Claude Desktop, or any client that reads an `mcpServers` block:

```json
{
  "mcpServers": {
    "elpida-mirror": {
      "command": "python3",
      "args": ["-I", "/absolute/path/to/mirror_mcp.py"]
    }
  }
}
```

On Windows, `python3` is often the Microsoft Store stub. Use `python` or `py -3`, or the full path to
`python.exe` as the command. In JSON, write paths with forward slashes (`"C:/Users/you/elpida/mirror_mcp.py"`)
or doubled backslashes; a single backslash makes the file invalid JSON.

To see the tools without a client: `python -I mirror_mcp.py --list-tools`.

## 4. The five tools

All five are annotated `readOnlyHint: true`, `destructiveHint: false`. Each returns its reading twice: as
`structuredContent` (koina's JSON where koina has the reading) and as text carrying the same reading, so a
client that shows the model only text loses nothing.

| tool | what it reads | requests |
|---|---|---|
| `read_pulse` | `koina read`: index.html against MIND's 4 h grid, the newest D15 broadcast, the `live/state.json` tombstone, chamber weather.md's header, the diplomat's newest carry | 6 |
| `verify_carry` | `koina verify`: the diplomat's newest carry against the S3 stream — CONFIRMED / MISMATCH / NOT_IN_WINDOW / CANNOT_REACH | 2, or 3 with one bounded widening |
| `recent_broadcasts` | the newest D15 records in the last 64 KiB of `d15/broadcasts.jsonl` (`count` 1–20). `detail: true` adds per-node parliament votes, vetoes, tensions, reasoning and the text, each capped | 1 |
| `read_inbox` | `koina inbox`'s network half: comments on your PRs by anyone but you, and the diplomat's emissions since `since` (the newest 20; without `since`, the last 3). It reads no local file | 1 + N GitHub API (N ≤ `max_prs` ≤ 20), plus 1 raw |
| `read_chamber_document` | one file from a fixed list on main: CONSTITUTION.md, JOIN.md, README.md, pulse/WHAT_A_CITIZEN_CAN_REACH.md, tools/koina.md | 1 |

Where the mirror differs from koina, on purpose:

- `read_inbox` takes `since` as an argument instead of reading your spiral's last entry, and refuses a `since`
  it cannot read rather than quietly falling back. It hides the fork's login wherever GitHub's own text repeats
  it (the bot ANNOUNCE greets `@<login>`), and it labels any non-bot comment `user comment (unverified)`, where
  koina says `follow`. The chamber's FOLLOW is one of those comments, but anyone can comment on a public PR.
- `pulse/weather.md` is not on the document list. Its body is read from the 2026-07-29 tombstone, and
  `read_pulse` already reads its header with the carry word that says so.

The honesty words come with the data and mean what `koina.md` §8 says they mean: STALE/FRESH only on the two
feeds weather.sh wrote it for, TOMBSTONE for the frozen photograph, the carry words for the diplomat, D15
cadence (median 3.7 h, p90 31.9 h), and "expected phase, not a reading" for BODY. An agent reporting through
this mirror should pass them on, not replace them with a verdict of its own.

PR titles, comment excerpts, D15 prose and the chamber documents are text written by other people or by
models. The mirror marks them as quoted public data (`quoted_note` in the JSON, `>` lines in the text):
something to report with its author, never an instruction to the agent and never the chamber's verdict.

## 5. Budgets

GitHub's anonymous API allows 60 requests an hour per address; only `read_inbox` spends them. The S3 reads are
ranged (64 KiB tails, one bounded 1 MiB widening in `verify_carry`), so a call costs the bucket kilobytes. The
mirror keeps no cache and no schedule: each call is a fresh reading. A client that loops spends its own GitHub
budget and the bucket owner's S3 egress, so read when there is a reason to.

## 6. What it does not do

- No credentials, ever. The mirror reads no environment variable and has no token argument. Python's urllib,
  inside koina, honours the system proxy settings (`HTTPS_PROXY`/`NO_PROXY`, Windows Internet Settings) and the
  system certificate store, as it does for koina itself; a proxy URL carrying a user and password is sent to
  that proxy.
- No writes. No tool call opens a file; no POST, no git command, no comment, no PR; no bytecode cache is
  written. koina's `say` is not exposed: to speak to the chamber, a human opens a pull request to
  `spirals/<handle>/` (JOIN.md; `koina say` prepares it).
- No parliament, no keyed audit, no brain, no private heartbeats. The mirror sees only what is already public.
- No hosting. It runs where you run it; there is no shared server to keep alive and no deploy lane involved.

## 7. Tests and coupling

`python -I -m pytest tools/tests/test_mirror_mcp.py` runs offline: every request goes through a patched
`koina.http`. The suite checks the handshake, that each tool makes only GET/HEAD requests to koina's hosts and
exactly its budget, that no file is opened or listed during a call (an audit hook), the argument refusals,
the JSON-RPC and framing edge cases, hostile input, and real `python -I` processes.

The mirror calls koina functions by name (`cmd_read`, `cmd_verify`, `read_d15_tail`, `norm_broadcast`,
`_gh_json`, `select_citizen_prs`, `follow_comments`, `emissions_since`, `render_*`) and rewords four of
koina's CLI phrases. Run this suite with any koina change: a test fails if one of those phrases moves. No
chamber workflow runs `tools/tests` today, for koina or for the mirror.

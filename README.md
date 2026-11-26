# J² Stack — Local Memory That Doesn't Eat Your Context Window

<p align="center">
  <a href="https://github.com/ontop01970/J2-Stack"><img src="https://img.shields.io/github/stars/ontop01970/J2-Stack?style=for-the-badge&logo=github" alt="Stars"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green?style=for-the-badge" alt="MIT License"></a>
  <a href="https://www.python.org/"><img src="https://img.shields.io/badge/python-3.10+-blue?style=for-the-badge&logo=python" alt="Python 3.10+"></a>
  <a href="https://hermes-agent.nousresearch.com"><img src="https://img.shields.io/badge/Hermes%20Agent-ready-8A2BE2?style=for-the-badge" alt="Hermes Ready"></a>
  <a href="https://github.com/open-jarvis/OpenJarvis"><img src="https://img.shields.io/badge/OpenJarvis-powered-FF6B35?style=for-the-badge" alt="OpenJarvis Powered"></a>
</p>

J² (J-squared) integrates **Jarvis** + **Jev** into **Hermes Agent** for persistent on-demand memory that lives in your database, not your prompt.

```
Jarvis ──SQLite FTS5──► Memory Store
  │                          
  │  POST /v1/memory/search  │
  ▼                          │
Hermes ──jarvis_lookup──► On-Demand Retrieval
  │
  │  Jev judges relevance    │
  ▼  before every lookup     │
User                        ▼
```

## Why Not Hindsight?

[Hindsight](https://github.com/nousresearch/hermes-agent) is Hermes's built-in memory system. It works — but every session it dumps your entire memory DB into the prompt as context. That means:

|                  | Hindsight                          | J² Stack                              |
|------------------|------------------------------------|---------------------------------------|
| **Memory load**  | All entries → every prompt         | Only what you search for              |
| **Context cost** | K of tokens per turn (grows)       | Zero unless a lookup fires            |
| **Latency**      | LLM ingests memory on every reply   | Sub-ms SQLite FTS5 search             |
| **Routing**      | None — memory always fires          | Jev judges lookups AND storage targets |
| **Storage**      | In-process Python objects           | Durable SQLite + FTS5/BM25            |
| **API spend**    | Pay for memory tokens every turn     | Pay nothing for idle memory            |

**J² retrieves memory facts on demand via a structured search tool, gated by a relevance router.** Hindsight force-feeds them into every window. That's the difference between a library you check out from and a firehose you stand under.

![J² Stack Demo](assets/demo.gif)

## Quick Start

```bash
curl -fsSL https://raw.githubusercontent.com/ontop01970/J2-Stack/main/install.sh | bash
```

Or manually:

```bash
# 1. Clone and set up Jarvis
git clone https://github.com/open-jarvis/OpenJarvis
cd OpenJarvis && uv sync && cd ..

# 2. Install Jev agent router
hermes plugin install jev

# 3. Add the Hermes profile
cp configs/hermes-profile.yaml ~/.hermes/profiles/j2/
hermes profile use j2

# 4. Start Jarvis service
systemctl --user enable --now jarvis-serve
```

## What You Get

| Component | Role |
|-----------|------|
| **Jarvis** (OpenJarvis) | Local memory API server backed by SQLite FTS5/BM25. ~3000 facts out of the box, zero cloud dependencies. |
| **Jev** | Hermes agent router that decides when memory retrieval is justified — abstains when it's not, falls back sensibly. Also routes *writing*: storage decisions go through Jev to pick user-fact, procedure, or project-context targets. |
| **Hermes** | The agent framework that ties it together. The `jarvis_lookup` tool queries Jarvis on demand; Jev gates the call. |

## Storage Routing Targets

Before persisting anything, Jev's `agent_route` chooses the right storage target:

| Route | Target | What it stores |
|-------|--------|----------------|
| `user-fact-store` | `memory(target='user')` | Who you are, what you like, standing conventions |
| `procedure-store` | `skill_manage create/patch` | How-to guides, setup steps, workflows, installation steps, walkthroughs |
| `project-context-store` | `Jarvis POST /v1/memory` | Project state, git history, session context |

Call `agent_route(task="<what to store>", agents=[user-fact-store, procedure-store, project-context-store], scope="j2-stack")` and Jev picks the best match with fallback. This keeps facts in the domain where they're most useful — no more guessing whether a preference belongs in a skill or a config file.

See [`skills/storage-router.md`](skills/storage-router.md) for the full protocol.

## How Memory Flows

```
1. User asks a question
2. Hermes context includes the J² profile
3. Hermes may call jarvis_lookup (gated by Jev)
4. Jev decides: "Is this worth a memory search?"
   ├── Yes → Jarvis returns up to 3 relevant fact clusters
   └── No  → Abstain; no context wasted
5. At most 2 searches per request (bounded budget)
6. Results land in the prompt as grounded citations
```

**No context pollution. No per-turn memory tax. No silent API spend.**

## Files

```
j2-stack/
├── install.sh                     # One-shot: clone + build + configure
├── configs/
│   ├── hermes-profile.yaml        # J² Hermes profile (Jarvis + Jev wired)
│   └── jarvis-serve.service       # Systemd user unit for Jarvis API
├── skills/
│   └── storage-router.md          # Storage routing protocol & agent definitions
├── scripts/
│   ├── setup-jarvis.sh            # Clone OpenJarvis, build Rust ext, init DB
│   └── setup-jev.sh               # Install and configure Jev plugin
├── docs/
│   ├── architecture.md            # Detail on the retrieval pipeline
│   └── troubleshooting.md
├── .github/
│   ├── ISSUE_TEMPLATE.md          # Bug report template
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.md
│   │   ├── feature_request.md
│   │   └── config.yml
│   └── PULL_REQUEST_TEMPLATE.md   # PR template
├── CODE_OF_CONDUCT.md             # Contributor Covenant v2.1
├── CONTRIBUTING.md                # How to contribute
├── README.md
└── LICENSE                        # MIT
```

## Community

Contributions are welcome! Before opening an issue or PR:

- Read [CONTRIBUTING.md](CONTRIBUTING.md) for the workflow and conventions
- Use the issue templates (bug report / feature request) so we have the right info upfront
- Follow [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) — be excellent to each other

Three storage targets are defined in the J² profile — see [`configs/hermes-profile.yaml`](configs/hermes-profile.yaml) for the full agent definitions and their tags.

## Requirements

- Linux or macOS
- Python 3.10+
- [uv](https://docs.astral.sh/uv/) (fast Python package manager)
- [Hermes Agent](https://hermes-agent.nousresearch.com) installed
- Systemd (Linux) or equivalent service manager for Jarvis persistence

## License

MIT — free for any use, personal or commercial.
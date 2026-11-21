# J² Stack Architecture

## Overview

The J² Stack is three components wired together to give Hermes on-demand memory
that never pollutes the context window unless a relevance router decides it should.

```
┌────────────────────────────────────────────────────────────────────┐
│                        J² Stack Architecture                        │
│                                                                    │
│  ┌─────────┐     ┌──────────┐     ┌─────────────────────────────┐  │
│  │         │     │          │     │  Hermes Agent               │  │
│  │ OpenJarvis │◄────│ jarvis_  │─────│  ┌─────────────────────┐  │  │
│  │ (Rust+Pyth)│  │  lookup   │  │  │  │ Jev Router        │  │  │
│  │           │     │  tool     │     │  │  (gates lookups)   │  │  │
│  │ SQLite   │─────►│          │     │  └─────────────────────┘  │  │
│  │ FTS5/BM25│  │  results   │  │  │                             │  │
│  └─────────┘     └──────────┘     │  ┌─────────────────────┐  │  │
│       ▲                          │  │ User Context       │  │  │
│       │                          │  │ (no memory bloat)  │  │  │
│       │                          │  └─────────────────────┘  │  │
│  ┌──────────┐                    └─────────────────────────────┘  │
│  │ Systemd   │                                                    │
│  │ user unit │     Memory stored locally, queried on demand       │
│  └──────────┘                                                     │
└────────────────────────────────────────────────────────────────────┘
```

## Memory Flow (Detailed)

```
User: "Do I already have a keybind for that?"

   │
   ▼
Hermes parses the request → loads J² profile
   │
   ▼
Jev (agent router) evaluates: "Is memory retrieval relevant?"
   │
   ├── YES (relevance ≥ threshold / 0.4)
   │    │
   │    ▼
   │  jarvis_lookup(query="keybind for ...", provider="jarvis")
   │    │
   │    ▼
   │  Jarvis API: POST /v1/memory/search
   │    │  Searches SQLite FTS5 index
   │    │  Returns up to 3 fact clusters (BM25-ranked)
   │    │
   │    ▼
   │  Results injected into context as grounded citations
   │  Next search? → Allowed up to 2 total per request
   │
   ├── NO (relevance below threshold / Jev abstains)
   │    │
   │    ▼
   │  No memory context consumed. Zero cost.
   │
   └── UNCERTAIN → Bounded retry (1 attempt)
```

## Components

### Jarvis (OpenJarvis)

- **Role:** Local-first memory API server
- **Storage:** SQLite with FTS5 full-text search + BM25 ranking
- **Capacity:** ~3000 fact clusters on consumer hardware
- **API:** REST at `http://127.0.0.1:8000`
  - `POST /v1/memory/search` — keyword + BM25 retrieval
  - `POST /v1/memory/store` — persist a fact
- **Performance:** Sub-5ms queries, zero network dependency
- **Persistence:** Systemd user unit, auto-start on boot

### Jev (Agent Router)

- **Role:** Relevance gate for memory lookups
- **Behavior:**
  1. Evaluate a request: "does this need memory context?"
  2. YES → route to jarvis_lookup; NO → abstain silently
  3. On failure → drop back to user with a note
- **Bounded:** Maximum 2 searches per originating user request
- **No infinite loops:** After 2 attempts or a refusal, stop

### Hermes

- **Role:** The agent framework that ties everything together
- **Profile:** `j2` with Jarvis provider + Jev plugin enabled
- **Tool:** `jarvis_lookup(query, missing_fact)` — the structured call
- **Integration:** Sub-400-token retrieval summary per successful lookup

## Key Design Decisions

### Why SQLite FTS5 + BM25, not vector embeddings?

- BM25 is deterministic, free, and fast on small-to-medium corpuses
- No embedding API call or GPU inference for every search
- Keyword search maps well to memory recall ("what was that keybind?")
- Can swap in vector search later via the same Jarvis API interface

### Why 2-search max?

Prevents runaway lookups. If the first 2 searches don't find the answer,
the information probably isn't in memory — stop asking and move on.

### Why Jev gates the lookup?

Not every question needs memory context. Jev applies a cheap
relevance judgment before any network/CPU cost, keeping memory
near-zero overhead for the majority of queries.

## vs Hindsight — A Cost Breakdown

**Scenario:** User asks 100 questions.
Half need memory, half don't. Memory DB has 3000 entries.

| Metric               | Hindsight                     | J² Stack                   |
|----------------------|-------------------------------|----------------------------|
| Prompt inflation     | 3000 entries × ~30 tokens     | 0 tokens (no lookup)       |
|                      | = 90K tokens per prompt       | or ~400 tokens (lookup)    |
| Total tokens consumed| 100 × 90K = **9M tokens**     | 50 × 400 = **20K tokens**  |
| Memory overhead      | 90K tokens every single turn  | Only when Jev says yes     |
| API cost (claude-opus)| ~$135 per 100 queries        | ~$0.30 per 100 queries     |
| Latency              | +2-3s for memory ingestion    | +5ms for SQLite query      |

**J² saves ~99.8% of memory-related token spend.**
No exaggeration — Hindsight feeds everything into the window; J² feeds nothing unless Jev decides otherwise.
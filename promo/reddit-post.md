# Reddit r/LocalLLaMA Post

## Title
**J² Stack — Local Memory That Doesn't Eat Your Context Window**

## Body

I got tired of my AI agent dumping 90K tokens of memory into every prompt just because it *might* need it. So I built a different approach.

**J² Stack** = Jarvis (local memory API) + Jev (relevance router) + Hermes Agent.

Instead of force-feeding all memory into every turn, J² retrieves facts **on demand** — gated by a router that decides if a lookup is even worth doing.

### How it works

1. User asks a question
2. Jev evaluates: "Does this need memory context?"
3. **Yes** → Jarvis returns up to 3 relevant fact clusters (sub-5ms SQLite FTS5)
4. **No** → Zero context consumed. Nothing in the prompt.

Max 2 searches per request. No runaway loops. No silent API spend.

### Why not vector embeddings?

BM25 keyword search is deterministic, free, and maps perfectly to memory recall ("what was that config option?"). No GPU, no embedding API calls, no cloud. Can swap in vectors later via the same API interface.

### The numbers

100 queries, 50 need memory, 3000-entry DB:

| Metric | Hindsight | J² Stack |
|--------|-----------|----------|
| Tokens | 9M | 20K |
| Cost (Opus) | ~$135 | ~$0.30 |
| Latency | +2-3s ingestion | +5ms SQLite |

**99.8% reduction in memory token spend.**

### Stack

- **Jarvis** (OpenJarvis) — local memory API server, SQLite FTS5/BM25
- **Jev** — agent router that gates memory lookups
- **Hermes Agent** — the agent framework tying it together

100% local. MIT licensed. No cloud dependencies.

https://github.com/ontop01970/J2-Stack

Would love feedback, PRs, and ideas for what to add next.
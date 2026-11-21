# Hacker News Post

## Title
J² Stack: On-demand memory for AI agents — 99.8% less context bloat

## Body

Most agent memory systems dump your entire database into the prompt on every turn. Hindsight (Hermes's built-in memory) loads 90K tokens per prompt — you pay for all of it even when the agent doesn't need it.

J² Stack takes a different approach: **on-demand retrieval gated by a relevance router.**

The pipeline:
1. Jev (agent router) evaluates: "does this query need memory?"
2. If yes → Jarvis searches a local SQLite FTS5/BM25 index (sub-5ms)
3. If no → zero context consumed, zero cost

Max 2 searches per request, bounded budget, no runaway loops.

Why BM25 instead of vector embeddings? For personal memory recall ("what was that keybind?"), keyword search is deterministic, free, and doesn't need GPU. The API supports swapping in vectors later.

**Cost comparison** (100 queries, 50 need memory, 3000-entry DB):
- Hindsight: 9M tokens, ~$135 on Claude Opus
- J² Stack: 20K tokens, ~$0.30

Stack: OpenJarvis (local memory API) + Jev (relevance router) + Hermes Agent (framework)

100% local. MIT. No cloud dependencies.

https://github.com/ontop01970/J2-Stack

Would love to hear what the HN community thinks — especially if you've built similar systems and have lessons learned.
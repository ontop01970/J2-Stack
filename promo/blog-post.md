# Local Memory That Doesn't Eat Your Context Window

*How we built J² Stack — on-demand agent memory that saves 99.8% of token spend*

---

If you've built anything with LLM agents, you've felt the pain.

Your agent needs to remember things across sessions — user preferences, project context, configuration details. So you give it memory. But the standard approach is a firehose: dump every stored fact into every prompt, every turn, and let the LLM figure out what's relevant.

That works. But it's **expensive**.

At 3000 stored facts × ~30 tokens each, that's 90,000 tokens of memory overhead per prompt. For a model like Claude Opus at $15/MTok input, that's **$1.35 per query just for memory ingestion**. Ask 100 questions and you've spent $135 on context you might not even need.

We thought: there has to be a better way.

## The Library, Not the Firehose

The insight is simple: your agent doesn't need to *carry* all its memories everywhere. It just needs to be able to *look them up* when relevant.

That's the difference between a firehose you stand under and a library you check books out from.

**J² Stack** implements exactly that. Three components wired together:

### Jarvis (OpenJarvis)

A local-first memory API server backed by SQLite with FTS5 full-text search and BM25 ranking. Runs on your machine at `http://127.0.0.1:8000`. Sub-5ms queries. ~3000 fact clusters on consumer hardware. Zero cloud dependencies.

### Jev (Agent Router)

A relevance gate that sits between the user's question and the memory system. Before any lookup fires, Jev evaluates: "Does this question need memory context?" If yes, it routes to Jarvis. If no, it abstains — zero context consumed, zero cost.

### Hermes Agent

The agent framework that ties everything together. The `jarvis_lookup` tool queries Jarvis on demand; Jev gates the call. The result lands in the prompt as a grounded citation — typically under 400 tokens.

## How Memory Flows

```
1. User asks a question
2. Jev evaluates: "Is memory retrieval relevant?"
   ├── YES → Jarvis returns up to 3 fact clusters (BM25-ranked)
   └── NO  → Zero context consumed
3. At most 2 searches per request (bounded budget)
4. Results injected as ~400-token grounded citations
```

**No context pollution. No per-turn memory tax. No silent API spend.**

## The Numbers

Let's run the math. 100 queries, half need memory, half don't. Memory DB has 3000 entries.

| Metric | Hindsight (default) | J² Stack |
|--------|--------------------|----------|
| Tokens per prompt | 90K (3000 × 30) | 0 or ~400 |
| Total tokens (100 queries) | 9,000,000 | 20,000 |
| Cost (Claude Opus) | ~$135 | ~$0.30 |
| Latency per query | +2-3s ingestion | +5ms SQLite |

**99.8% reduction in memory-related token spend.** That's not incremental improvement — that's a different category of system.

## Why Not Vector Embeddings?

Good question. For personal memory recall ("what was that config option?" "what did we decide about X?"), keyword search with BM25 ranking works remarkably well. It's:

- **Deterministic** — same query, same results, every time
- **Free** — no GPU, no embedding API calls
- **Fast** — sub-5ms on consumer hardware
- **Sufficient** — memory recall is fundamentally a keyword-matching problem

The Jarvis API is designed to support vector search as a drop-in replacement later. But for 99% of use cases, BM25 is the right default.

## Bounded by Design

One risk with on-demand retrieval is runaway loops — the agent keeps searching because it didn't find what it wanted. J² prevents this with hard bounds:

- **Max 2 searches per user request**
- **Jev abstains on low relevance** — the router says "no" before any search fires
- **Fallback on failure** — if both searches miss, the agent drops back to the user with a note

No infinite loops. No silent API spend.

## Getting Started

```bash
curl -fsSL https://raw.githubusercontent.com/ontop01970/J2-Stack/main/install.sh | bash
```

Or follow the manual steps in the [README](https://github.com/ontop01970/J2-Stack).

Requirements: Linux/macOS, Python 3.10+, [uv](https://docs.astral.sh/uv/), and [Hermes Agent](https://hermes-agent.nousresearch.com).

## What's Next

J² Stack is MIT licensed and in active development. We're working on:

- Vector search integration for semantic memory
- Multi-user memory namespaces
- Memory expiry and consolidation
- Web UI for browsing stored facts

---

*J² Stack — Local Memory That Doesn't Eat Your Context Window*

*https://github.com/ontop01970/J2-Stack*
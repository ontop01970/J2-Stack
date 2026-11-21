# J² Stack — Troubleshooting

## Installation

### `uv sync` fails
Ensure Rust toolchain is installed for the Jarvis extension:
```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```
Or skip the Rust build with `--no-build`.

### `systemctl --user enable` fails
Likely running in a container or on a system without systemd. Run Jarvis manually:
```bash
cd ~/j2-stack/OpenJarvis
.venv/bin/python -m openjarvis.api serve
```

### Hermes can't find the J² profile
Check the profile exists:
```bash
hermes profile list
```
If missing, copy the config manually:
```bash
mkdir -p ~/.hermes/profiles/j2
cp ~/j2-stack/configs/hermes-profile.yaml ~/.hermes/profiles/j2/config.yaml
hermes profile use j2
```

## Runtime

### `jarvis_lookup` returns empty results
1. Check Jarvis API is running:
   ```bash
   curl http://127.0.0.1:8000/health
   ```
2. Check memory DB exists:
   ```bash
   ls -la ~/.local/share/jarvis/memory.db
   ```
3. Try a direct search:
   ```bash
   curl -X POST http://127.0.0.1:8000/v1/memory/search \
     -H "Content-Type: application/json" \
     -d '{"query": "test", "limit": 3}'
   ```

### Jev abstains too often
Lower the relevance threshold in the profile:
```yaml
memory:
  jarvis:
    relevance_threshold: 0.3  # default is 0.4
```

### Jev fires too often — too many lookups
Raise the threshold:
```yaml
memory:
  jarvis:
    relevance_threshold: 0.6
```

### Memory still shows up in context after switching to J²
Make sure `context_from_memory` is false in Hermes config:
```bash
hermes config set memory.context_from_memory false
```

## Performance

### SQLite queries are slow
Ensure FTS5 is enabled (verify with `PRAGMA compile_options`). For
>10000 entries, consider adding an index:
```sql
CREATE INDEX IF NOT EXISTS idx_facts_updated ON memory_facts(updated_at);
```

### Rust extension won't build
The Python-only fallback works fine for <5000 entries. Skip Rust:
```bash
cd ~/j2-stack/OpenJarvis
uv sync --no-build
```
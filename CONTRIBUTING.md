# Contributing to J² Stack

Thanks for wanting to contribute. J² Stack is a storage-routing layer that sits between Hermes Agent and its persistence backends. Here's how to help.

## How to Contribute

1. **Open an issue** — bugs, feature ideas, and questions are welcome.
2. **Fork the repo** and create a feature branch.
3. **Make your changes** — keep them focused on one thing.
4. **Open a PR** against `main`.

## Development Setup

```bash
git clone https://github.com/ontop01970/J2-Stack.git
cd J2-Stack
./install.sh          # links configs into ~/.hermes/
```

The install script is idempotent — safe to re-run after pulling.

## What Needs Help

Check the [open issues](https://github.com/ontop01970/J2-Stack/issues) for `help-wanted` and `good-first-issue` tags. Some areas:

- **New storage backends** — add adapters beyond the current three agents
- **Tests** — the router logic needs coverage
- **Docs** — tutorials, examples, configuration reference

## PR Guidelines

- One feature/fix per PR.
- Keep diffs small and reviewable.
- Update the README or relevant docs if your change affects behavior.
- No linter errors — the CI will check.

## Code of Conduct

Be excellent to each other. Harassment, hate speech, and entitled demands will not be tolerated.
# J² Storage Router — Route Before You Store

## What

Before persisting any data, route the storage decision through Jev's `agent_route` tool to pick the right target. Three storage agents, each owning a specific domain:

| Agent | Target | Stores |
|-------|--------|--------|
| **User Fact Storage** | `memory(target='user')` | Personal facts, preferences, identity, bio, likes, dislikes |
| **Procedure Storage** | `skill_manage` | Reusable how-tos, setup steps, workflows, troubleshooting guides |
| **Project Context Storage** | Jarvis API (`POST /v1/memory`) | Project state, config details, git history, system state |

## The Three Storage Agents

```yaml
agents:
  - id: user-fact-store
    name: User Fact Storage
    description: >
      Stores personal user facts, preferences, identity, likes, dislikes,
      and biographical details via memory(target='user'). Best for facts
      about who the user is and what they prefer.
    capabilities: [memory, user-profile, preferences, identity, bio]
    tags: [personal, user, preference, identity, bio]
    cost: 0.1
    latency: 0.1
    reliability: 0.9
    scope: j2-stack

  - id: procedure-store
    name: Procedure Storage
    description: >
      Stores reusable step-by-step instructions, how-to guides, setup steps,
      workflows, operational procedures, troubleshooting steps, and config
      walkthroughs via skill_manage. Best for how-to guides and process docs.
    capabilities: [skills, procedures, workflows, howto, guide, troubleshooting, setup]
    tags: [procedure, workflow, howto, guide, setup, troubleshoot]
    cost: 0.3
    latency: 0.3
    reliability: 0.85
    scope: j2-stack

  - id: project-context-store
    name: Project Context Storage
    description: >
      Stores project state, system configuration details, historical records,
      session context, git history, repo state, and deployment info via Jarvis.
      Best for technical project data and system state.
    capabilities: [jarvis, project, state, history, config, repo, deploy]
    tags: [project, state, config, system, repo, git, commit, deploy]
    cost: 0.2
    latency: 0.2
    reliability: 0.85
    scope: j2-stack
```

## Protocol

```
1. Have something to persist
2. Call agent_route(task="<what to store>", agents=[user-fact, procedure, project-context], scope="j2-stack")
3. Jev returns: { decision: "select"|"abstain", selected: { id: "user-fact-store"|... } }
4. Execute:
   - user-fact-store  → memory(target='user')
   - procedure-store   → skill_manage (create/patch)
   - project-context   → Jarvis POST /v1/memory
   - abstain           → skip, nothing to persist
```

## When to Route

- **Always route** before first persist of any new information.
- **Skip routing** for ephemeral data (not worth storing), obvious continuations of the same storage target, or tasks where the target is already explicit in the instruction.

## Integration Points

- **J² Profile**: Router agents are defined in the profile config under `plugins.jev_agent_router.storage_agents`.
- **SOUL.md**: The storage routing mandate lives in the Persistent Memory section.
- **Testing**: Call `agent_route` with a sample task to verify routing before committing new storage logic.
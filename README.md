# GSD-Ruflo Bridge

Bridge between [GSD](https://github.com/get-stuff-done/gsd) structured phase planning and [Ruflo](https://github.com/ruvnet/ruflo) multi-agent swarm execution.

## What It Does

GSD plans your work in phases. Ruflo executes with agent swarms. This skill connects them — and pre-teaches agents about your codebase before they start.

```
Learn Codebase → Seed Ruflo Memory → GSD PLAN.md → Spawn Informed Swarm → Results → GSD Verify
```

Instead of a single GSD executor agent working sequentially through a phase, this skill spawns a coordinated team of specialized Ruflo agents that already understand your project's structure, patterns, and conventions.

## Dependencies

| Dependency | Version | Purpose |
|-----------|---------|---------|
| [GSD](https://github.com/get-stuff-done/gsd) | Latest | Structured phase planning, roadmaps, and verification |
| [Ruflo CLI](https://github.com/ruvnet/ruflo) (`claude-flow`) | v3alpha+ | Multi-agent swarm orchestration and execution |
| [Claude Code](https://claude.com/claude-code) | Latest | CLI environment for running skills and agents |

### Install Dependencies

```bash
# Ruflo CLI (required)
npx claude-flow@v3alpha --version

# GSD skill (required — install via Claude Code)
# See https://github.com/get-stuff-done/gsd for setup instructions
```

## How It Works

| Step | Action | Tool |
|------|--------|------|
| 0 | **Learn codebase** (once) | `learn.sh` or Claude |
| 1 | Plan your phase | GSD (`/gsd:plan-phase`) |
| 2 | Parse PLAN.md tasks | Bridge skill |
| 3 | Map tasks to agent roles | Bridge skill |
| 4 | Spawn Ruflo swarm | Ruflo CLI |
| 5 | Execute in parallel | Ruflo agents (with pre-loaded memory) |
| 6 | Verify results | GSD (`/gsd:verify-work`) |

## Task-to-Agent Mapping

The bridge automatically maps GSD task types to Ruflo agent roles:

| Task Keywords | Ruflo Agent | Role |
|--------------|-------------|------|
| implement, build, create, code | `coder` | Developer |
| test, spec, coverage, assert | `tester` | Tester |
| review, audit, check, validate | `reviewer` | Reviewer |
| design, architect, structure | `architect` | Architect |
| security, auth, permissions | `security-architect` | Security |
| research, analyze, investigate | `researcher` | Researcher |
| optimize, performance, benchmark | `optimizer` | Performance |

## Swarm Topology Selection

The bridge picks the right topology based on your phase:

| Task Count | Max Agents | Topology |
|-----------|------------|----------|
| 1-4 | 4 | `hierarchical` |
| 5-8 | 6 | `hierarchical` |
| 9+ | 8 | `hierarchical-mesh` |

## Agent Execution Order

Agents spawn in dependency waves, not all at once:

```
Level 0: Researcher, Architect       (no dependencies)
Level 1: Developer, Security         (needs architecture)
Level 2: Tester                      (needs implementation)
Level 3: Reviewer                    (needs code + tests)
```

## Usage

### Prerequisites

- [Ruflo CLI](https://github.com/ruvnet/ruflo): `npx claude-flow@v3alpha --version`
- A GSD project with `.planning/` directory
- A phase planned via `/gsd:plan-phase`

### Install the Skill

Copy `SKILL.md` to your Claude Code skills directory:

```bash
mkdir -p ~/.claude/skills/gsd-ruflo-bridge
cp SKILL.md ~/.claude/skills/gsd-ruflo-bridge/
```

Or clone this repo directly:

```bash
git clone https://github.com/PitlaneHQ/gsd-ruflo-bridge.git ~/.claude/skills/gsd-ruflo-bridge
```

### Step 0: Learn Your Codebase (once per project)

Before running any phase, teach the agents about your existing project:

```bash
# Basic learn (current directory)
bash ~/.claude/skills/gsd-ruflo-bridge/scripts/learn.sh .

# Deep learn with custom namespace
bash ~/.claude/skills/gsd-ruflo-bridge/scripts/learn.sh /path/to/project --namespace my-project --deep
```

Or just tell Claude: **"Learn this codebase for Ruflo"**

This scans and stores:

| Memory Key | What It Captures |
|-----------|-----------------|
| `structure-files` | File tree (200 files, 3 levels deep) |
| `structure-dirs` | Directory layout |
| `code-patterns` | Languages, frameworks, linting configs |
| `architecture` | Entry points, package.json, key configs |
| `test-patterns` | Test framework, test locations, test count |
| `git-history` | Recent commits, hot files, contributors |
| `doc-*` | README, CLAUDE.md, CONTRIBUTING.md |

**Deep mode** (`--deep`) also captures:

| Memory Key | What It Captures |
|-----------|-----------------|
| `api-routes` | Files with API route definitions |
| `data-models` | Database model/schema files |
| `import-graph` | Module import relationships |
| `tech-debt` | TODO/FIXME/HACK markers |

Agents can then query this at any time:

```bash
npx claude-flow@v3alpha memory search --namespace project-memory --query "test framework"
npx claude-flow@v3alpha memory search --namespace project-memory --query "architecture"
```

### Step 1-4: Run It

```
1. /gsd:plan-phase           # Create your phase plan
2. /gsd-ruflo-bridge          # Execute with Ruflo swarm (agents read pre-loaded memory)
3. /gsd:verify-work           # Verify the results
4. /gsd:next                  # Move to next phase
```

## Example Swarm Configurations

### Feature Development

```
Architect  → Design API/data structures
Developer  → Implement endpoints/logic (2 agents for large phases)
Tester     → Write unit + integration tests
Reviewer   → Code review + acceptance criteria check
```

### Security Phase

```
Security   → Threat model + vulnerability scan
Developer  → Implement fixes
Tester     → Security test cases
Reviewer   → Verify remediations
```

### Refactoring Phase

```
Architect  → Plan refactoring approach
Developer  → Execute refactoring
Tester     → Ensure no regressions
Reviewer   → Code quality review
```

### Performance Phase

```
Researcher → Profile + identify bottlenecks
Optimizer  → Implement optimizations
Tester     → Benchmark before/after
Reviewer   → Validate improvements
```

## When to Use This vs. Standard GSD

| Use GSD alone | Use GSD + Ruflo Bridge |
|---------------|------------------------|
| Small phases (1-3 tasks) | Large phases (4+ parallelizable tasks) |
| Sequential work | Independent tasks across modules |
| Single-file changes | Changes spanning 5+ files |
| Quick fixes | Multi-concern work (API + tests + docs) |

## How Results Flow Back

After swarm execution:

1. Agent outputs are collected from Ruflo shared memory
2. Changes are verified against PLAN.md acceptance criteria
3. An atomic commit is created for the phase
4. Patterns are stored in Ruflo memory for future phases
5. GSD phase status is updated for `/gsd:verify-work`

## License

MIT

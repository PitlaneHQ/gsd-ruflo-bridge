---
name: gsd-ruflo-bridge
description: "Bridge GSD phase planning with Ruflo swarm execution. Use when executing a GSD phase with multi-agent swarms instead of a single executor, or when a phase has parallelizable tasks across 5+ files. Also use to pre-learn a codebase so agents start with full project context."
---

# GSD-Ruflo Bridge

## Overview

Connects GSD's structured phase planning with Ruflo's multi-agent swarm execution. Instead of a single GSD executor agent working sequentially, this skill spawns a coordinated Ruflo swarm matched to the phase's task types.

Includes a **memory seeding** system that pre-analyzes your codebase so agents already know your project's structure, patterns, frameworks, and history before they start working.

**Announce at start:** "I'm using the gsd-ruflo-bridge skill to execute this phase with a Ruflo swarm."

## When to Use

- GSD phase has 4+ parallelizable tasks
- Phase touches 5+ files across different concerns (API + tests + docs)
- Phase benefits from specialized agents (security review, architecture, testing)
- You want multi-agent review/validation during execution
- **New project**: Run `learn` first so agents start with full context

## When NOT to Use

- Simple phases with 1-3 sequential tasks
- Single-file changes
- Documentation-only phases
- Quick fixes (`/gsd:fast` or `/gsd:quick` are better)

## Prerequisites

- Ruflo CLI available: `npx claude-flow@v3alpha --version`
- A GSD phase with a `PLAN.md` already created via `/gsd:plan-phase`
- Active `.planning/` directory with roadmap

---

## Pre-Learning: Seed Memory Before Execution

Before running any phase, teach the agents about your existing codebase. This only needs to happen once per project (or after major changes).

### What Learn Captures

| Memory Key | What It Stores |
|-----------|----------------|
| `structure-files` | Project file tree (up to 200 files, 3 levels deep) |
| `structure-dirs` | Directory layout |
| `code-patterns` | Languages, frameworks (React, Express, etc.), linting/formatting configs |
| `architecture` | Entry points, key config files, package.json metadata |
| `test-patterns` | Test framework (vitest/jest/pytest), test file locations, test count |
| `git-history` | Recent 20 commits, most-changed files, contributors, current branch |
| `doc-*` | First 100 lines of README, CLAUDE.md, CONTRIBUTING.md, etc. |

### Deep Mode (--deep) adds:

| Memory Key | What It Stores |
|-----------|----------------|
| `api-routes` | Files containing API route definitions |
| `data-models` | Files with database models/schemas |
| `import-graph` | Top 100 import statements showing module relationships |
| `tech-debt` | TODO/FIXME/HACK/WORKAROUND markers across the codebase |

### How to Run Learn

**Option A: Via script**
```bash
# Basic learn (current directory)
bash ~/.claude/skills/gsd-ruflo-bridge/scripts/learn.sh .

# Deep learn with custom namespace
bash ~/.claude/skills/gsd-ruflo-bridge/scripts/learn.sh /path/to/project --namespace my-project --deep
```

**Option B: Via Claude Code (recommended)**

Tell Claude: "Learn this codebase for Ruflo" and it will run these steps:

1. **Scan structure**: `find` the project tree, store in Ruflo memory
2. **Detect patterns**: Identify languages, frameworks, configs
3. **Map architecture**: Find entry points, key files, package metadata
4. **Analyze tests**: Detect test framework, count test files, find test dirs
5. **Read git history**: Recent commits, hot files, contributors
6. **Ingest docs**: README, CLAUDE.md, and other documentation

```bash
# All stored under a namespace your agents can query
npx claude-flow@v3alpha memory search --namespace project-memory --query "test framework"
npx claude-flow@v3alpha memory search --namespace project-memory --query "architecture"
npx claude-flow@v3alpha memory search --namespace project-memory --query "recent changes"
```

### How Agents Use Pre-Learned Memory

When the bridge spawns agents in Step 4, each agent's prompt includes:

```
Read project context from Ruflo memory namespace 'project-memory':
- Query 'architecture' for entry points and project structure
- Query 'code-patterns' for languages and frameworks in use
- Query 'test-patterns' for testing conventions
- Query 'git-history' for recent changes and hot files

Use this context to inform your work. Follow existing patterns.
```

This means:
- **Architects** know the existing module structure before designing
- **Developers** follow existing code conventions automatically
- **Testers** use the correct test framework and file patterns
- **Reviewers** check against established project patterns

### Re-Learning

Run learn again when:
- Major refactoring changes project structure
- New framework/dependency added
- Switching branches to a different feature area
- Starting a new milestone

The `--upsert` flag ensures existing memories are updated, not duplicated.

---

## The Process

### Step 1: Load and Parse the GSD Phase Plan

1. Read the phase's `PLAN.md` file from `.planning/`
2. Extract all tasks with their:
   - Task name and description
   - Acceptance criteria
   - File targets (which files each task touches)
   - Dependencies between tasks
3. Categorize each task by type:

| Task Keywords | Agent Type | Ruflo Role |
|--------------|------------|------------|
| implement, build, create, code, add | `coder` | Developer |
| test, spec, coverage, assert | `tester` | Tester |
| review, audit, check, validate | `reviewer` | Reviewer |
| design, architect, structure, schema | `architect` | Architect |
| security, auth, permissions, CVE | `security-architect` | Security |
| research, analyze, investigate | `researcher` | Researcher |
| optimize, performance, benchmark | `optimizer` | Performance |

### Step 2: Determine Swarm Configuration

Based on the parsed tasks, select the swarm topology:

**Hierarchical** (default for most phases):
- When tasks have clear dependencies (design before implement before test)
- When one agent needs to coordinate others
- Best for: feature development, refactoring

**Mesh** (for independent parallel work):
- When tasks are independent and can run simultaneously
- When peer review between agents is needed
- Best for: multi-module changes, documentation + code

**Configuration rules:**
- Tasks <= 4: `maxAgents: 4`, topology: `hierarchical`
- Tasks 5-8: `maxAgents: 6`, topology: `hierarchical`
- Tasks 9+: `maxAgents: 8`, topology: `hierarchical-mesh`

### Step 3: Initialize the Ruflo Swarm

Run these commands to set up the swarm:

```bash
# Initialize swarm with anti-drift config
npx claude-flow@v3alpha swarm init \
  --topology <selected-topology> \
  --max-agents <calculated-count> \
  --strategy specialized

# Store the GSD phase context in Ruflo memory
npx claude-flow@v3alpha memory store \
  --namespace "gsd-phase" \
  --key "plan" \
  --value "<contents of PLAN.md>" \
  --tags "gsd,phase-<N>"

# Store acceptance criteria separately for verification
npx claude-flow@v3alpha memory store \
  --namespace "gsd-phase" \
  --key "acceptance-criteria" \
  --value "<extracted acceptance criteria>" \
  --tags "gsd,verification"
```

### Step 4: Spawn Agents and Execute

Spawn agents matched to the task categories from Step 1. All agent spawns MUST be in a single message for parallel execution.

```bash
# Spawn agents based on task mapping
npx claude-flow@v3alpha agent spawn -t <type> --name <role>-1

# Start swarm execution with the phase objective
npx claude-flow@v3alpha swarm start \
  --objective "<phase goal from PLAN.md>" \
  --strategy specialized \
  --parallel true
```

**Simultaneously**, use Claude Code's Agent tool to spawn real executor agents. Each agent gets **pre-learned project context** from the `project-memory` namespace:

```
Agent("Architect", "
  CONTEXT: Query Ruflo memory namespace 'project-memory' for: architecture, code-patterns, git-history.
  TASK: Read the GSD phase plan from .planning/..., design the implementation approach.
  Follow existing patterns found in project memory. Store decisions in namespace 'gsd-phase'.")

Agent("Developer", "
  CONTEXT: Query Ruflo memory namespace 'project-memory' for: code-patterns, test-patterns, architecture.
  TASK: Implement tasks from the GSD phase plan. Read design from namespace 'gsd-phase'.
  Match existing code style and framework conventions. Files to modify: [list from plan]")

Agent("Tester", "
  CONTEXT: Query Ruflo memory namespace 'project-memory' for: test-patterns, code-patterns.
  TASK: Write tests for acceptance criteria from the GSD phase plan.
  Use the project's test framework and follow existing test file patterns. Read criteria from namespace 'gsd-phase'")

Agent("Reviewer", "
  CONTEXT: Query Ruflo memory namespace 'project-memory' for: code-patterns, architecture, tech-debt.
  TASK: Review all changes against the phase acceptance criteria.
  Check for consistency with existing patterns. Report findings to namespace 'gsd-phase'")
```

**Dependency ordering:**
- Level 0: Researcher, Architect (no dependencies)
- Level 1: Developer, Security (depends on architecture)
- Level 2: Tester (depends on implementation)
- Level 3: Reviewer (depends on code + tests)

For levels with dependencies, wait for prior level to complete before spawning.

### Step 5: Monitor and Collect Results

```bash
# Check swarm progress
npx claude-flow@v3alpha swarm status --format json

# Check individual agents
npx claude-flow@v3alpha agent list --format json

# Retrieve findings from shared memory
npx claude-flow@v3alpha memory search \
  --namespace "gsd-phase" \
  --query "results" \
  --limit 10
```

Do NOT poll continuously. Check status only when:
- An agent completes and returns results
- You need to verify before spawning the next dependency level
- All agents should be done (after reasonable time)

### Step 6: Write Results Back to GSD

After all agents complete:

1. **Collect all changes** made by the swarm agents
2. **Verify against acceptance criteria** from the PLAN.md
3. **Update GSD phase status**:
   - Mark completed tasks in the phase's todo tracking
   - Note any tasks that failed or need manual intervention
4. **Create atomic commit** for the phase's work
5. **Store learning patterns** for future phases:

```bash
npx claude-flow@v3alpha hooks post-task \
  --task-id "gsd-phase-<N>" \
  --success true \
  --train-patterns true

npx claude-flow@v3alpha memory store \
  --namespace "patterns" \
  --key "gsd-swarm-phase-<N>" \
  --value "<what worked, agent count, topology used, timing>"
```

### Step 7: Hand Back to GSD

After swarm execution completes:

1. Announce: "Ruflo swarm execution complete for phase <N>."
2. Present a summary:
   - Tasks completed vs. total
   - Agents used and their roles
   - Any issues or deviations from the plan
   - Files modified
3. Suggest next GSD action:
   - If all tasks passed: `/gsd:verify-work` to run UAT
   - If some failed: List what needs manual attention
   - If phase complete: `/gsd:next` to advance

## Task-to-Agent Mapping Reference

### Feature Development Phase
```
Architect  → Design API/data structures
Developer  → Implement endpoints/logic (can be 2 agents for large phases)
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

## Error Handling

- **Agent fails**: Check agent logs, retry with adjusted instructions
- **Swarm timeout**: Reduce scope, split into sub-phases
- **Memory conflicts**: Use CRDT consensus or let reviewer resolve
- **Plan deviation**: Stop swarm, update PLAN.md, re-execute

## Example Full Flow

```
User: /gsd:plan-phase          # Creates PLAN.md for phase 3
User: /gsd-ruflo-bridge         # This skill activates

Skill:
1. Reads .planning/milestone-1/phase-3/PLAN.md
2. Finds 6 tasks: 2 implement, 2 test, 1 design, 1 review
3. Maps to: 1 architect + 2 coders + 1 tester + 1 reviewer = 5 agents
4. Inits swarm: hierarchical, maxAgents=6, specialized
5. Spawns Level 0: architect
6. Spawns Level 1: 2 coders (after architect done)
7. Spawns Level 2: tester (after coders done)
8. Spawns Level 3: reviewer (after all done)
9. Collects results, verifies acceptance criteria
10. Commits changes, stores patterns
11. Reports: "Phase 3 complete. 6/6 tasks done. Run /gsd:verify-work"

User: /gsd:verify-work          # UAT verification
User: /gsd:next                 # Advance to phase 4
```

---
name: gsd-ruflo-bridge
description: "Bridge GSD phase planning with Ruflo swarm execution. Use when executing a GSD phase with multi-agent swarms instead of a single executor, or when a phase has parallelizable tasks across 5+ files."
---

# GSD-Ruflo Bridge

## Overview

Connects GSD's structured phase planning with Ruflo's multi-agent swarm execution. Instead of a single GSD executor agent working sequentially, this skill spawns a coordinated Ruflo swarm matched to the phase's task types.

**Announce at start:** "I'm using the gsd-ruflo-bridge skill to execute this phase with a Ruflo swarm."

## When to Use

- GSD phase has 4+ parallelizable tasks
- Phase touches 5+ files across different concerns (API + tests + docs)
- Phase benefits from specialized agents (security review, architecture, testing)
- You want multi-agent review/validation during execution

## When NOT to Use

- Simple phases with 1-3 sequential tasks
- Single-file changes
- Documentation-only phases
- Quick fixes (`/gsd:fast` or `/gsd:quick` are better)

## Prerequisites

- Ruflo CLI available: `npx claude-flow@v3alpha --version`
- A GSD phase with a `PLAN.md` already created via `/gsd:plan-phase`
- Active `.planning/` directory with roadmap

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

**Simultaneously**, use Claude Code's Agent tool to spawn real executor agents:

```
Agent("Architect", "Read the GSD phase plan from .planning/..., design the implementation approach, store decisions in memory namespace 'gsd-phase'")
Agent("Developer", "Implement tasks from the GSD phase plan. Read design from memory namespace 'gsd-phase'. Files to modify: [list from plan]")
Agent("Tester", "Write tests for acceptance criteria from the GSD phase plan. Read criteria from memory namespace 'gsd-phase'")
Agent("Reviewer", "Review all changes against the phase acceptance criteria. Report findings to memory namespace 'gsd-phase'")
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

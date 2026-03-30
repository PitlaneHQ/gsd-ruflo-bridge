#!/usr/bin/env bash
# gsd-ruflo-bridge: learn
# Analyzes an existing codebase, sets up GSD project scaffolding,
# and seeds Ruflo memory so agents start fully informed.
#
# Usage: ./learn.sh [project-dir] [--namespace NAME] [--deep] [--skip-gsd]
#
# What it does:
#   Phase 1 - GSD Setup:
#     - Initializes git repo if needed
#     - Creates .planning/ directory structure
#     - Generates PROJECT.md from codebase analysis
#     - Creates initial ROADMAP.md
#     - Sets up CLAUDE.md if missing
#
#   Phase 2 - Ruflo Memory Seeding:
#     - Project structure (directory tree, key files)
#     - Code patterns (languages, frameworks, conventions)
#     - Architecture (entry points, modules, dependencies)
#     - Test patterns (test framework, coverage approach, test locations)
#     - Git history (recent changes, active contributors, hot files)
#     - Existing docs (README, CLAUDE.md, package.json metadata)

set -euo pipefail

PROJECT_DIR="${1:-.}"
NAMESPACE="project-memory"
DEEP=false
SKIP_GSD=false

# Parse flags
shift || true
while [[ $# -gt 0 ]]; do
  case $1 in
    --namespace) NAMESPACE="$2"; shift 2 ;;
    --deep) DEEP=true; shift ;;
    --skip-gsd) SKIP_GSD=true; shift ;;
    *) echo "Unknown flag: $1"; exit 1 ;;
  esac
done

RUFLO="npx claude-flow@v3alpha"
cd "$PROJECT_DIR"

PROJECT_NAME=$(basename "$(pwd)")
TODAY=$(date +%Y-%m-%d)

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  GSD-Ruflo Bridge: Learn & Setup                           ║"
echo "║  Project: $PROJECT_NAME"
echo "║  Date: $TODAY"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# ═══════════════════════════════════════════════════════════════════
# PHASE 1: GSD PROJECT SETUP
# ═══════════════════════════════════════════════════════════════════

if [ "$SKIP_GSD" = false ]; then

echo "━━━ Phase 1: GSD Project Setup ━━━"
echo ""

# ─── 1.1 Git repo ──────────────────────────────────────────────────

if [ ! -d ".git" ]; then
  echo "[1.1] Initializing git repository..."
  git init
  echo "  Git repo initialized"
else
  echo "[1.1] Git repo exists ✓"
fi

# ─── 1.2 .planning directory ──────────────────────────────────────

if [ ! -d ".planning" ]; then
  echo "[1.2] Creating .planning/ directory structure..."
  mkdir -p .planning/codebase
  mkdir -p .planning/research
  echo "  Created .planning/"
else
  echo "[1.2] .planning/ exists ✓"
fi

# ─── 1.3 Detect project metadata ─────────────────────────────────

echo "[1.3] Detecting project metadata..."

# Detect primary language
PRIMARY_LANG="Unknown"
TS_COUNT=$(find . -name "*.ts" -o -name "*.tsx" -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null | wc -l)
JS_COUNT=$(find . -name "*.js" -o -name "*.jsx" -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null | wc -l)
PY_COUNT=$(find . -name "*.py" -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/venv/*' 2>/dev/null | wc -l)
RS_COUNT=$(find . -name "*.rs" -not -path '*/target/*' 2>/dev/null | wc -l)
GO_COUNT=$(find . -name "*.go" -not -path '*/vendor/*' 2>/dev/null | wc -l)

MAX_COUNT=0
for lang_count in "TypeScript:$TS_COUNT" "JavaScript:$JS_COUNT" "Python:$PY_COUNT" "Rust:$RS_COUNT" "Go:$GO_COUNT"; do
  name="${lang_count%%:*}"
  count="${lang_count##*:}"
  if [ "$count" -gt "$MAX_COUNT" ]; then
    MAX_COUNT=$count
    PRIMARY_LANG=$name
  fi
done

# Detect package manager
PKG_MANAGER="none"
[ -f "pnpm-lock.yaml" ] && PKG_MANAGER="pnpm"
[ -f "yarn.lock" ] && PKG_MANAGER="yarn"
[ -f "package-lock.json" ] && PKG_MANAGER="npm"
[ -f "bun.lockb" ] && PKG_MANAGER="bun"
[ -f "requirements.txt" ] || [ -f "pyproject.toml" ] && PKG_MANAGER="pip"
[ -f "Cargo.lock" ] && PKG_MANAGER="cargo"
[ -f "go.sum" ] && PKG_MANAGER="go"

# Detect frameworks
DETECTED_FRAMEWORKS=""
[ -f "package.json" ] && {
  grep -q '"react"' package.json 2>/dev/null && DETECTED_FRAMEWORKS="$DETECTED_FRAMEWORKS React"
  grep -q '"next"' package.json 2>/dev/null && DETECTED_FRAMEWORKS="$DETECTED_FRAMEWORKS Next.js"
  grep -q '"vue"' package.json 2>/dev/null && DETECTED_FRAMEWORKS="$DETECTED_FRAMEWORKS Vue"
  grep -q '"svelte"' package.json 2>/dev/null && DETECTED_FRAMEWORKS="$DETECTED_FRAMEWORKS Svelte"
  grep -q '"express"' package.json 2>/dev/null && DETECTED_FRAMEWORKS="$DETECTED_FRAMEWORKS Express"
  grep -q '"fastify"' package.json 2>/dev/null && DETECTED_FRAMEWORKS="$DETECTED_FRAMEWORKS Fastify"
  grep -q '"hono"' package.json 2>/dev/null && DETECTED_FRAMEWORKS="$DETECTED_FRAMEWORKS Hono"
  grep -q '"nestjs"' package.json 2>/dev/null && DETECTED_FRAMEWORKS="$DETECTED_FRAMEWORKS NestJS"
  grep -q '"prisma"' package.json 2>/dev/null && DETECTED_FRAMEWORKS="$DETECTED_FRAMEWORKS Prisma"
  grep -q '"drizzle"' package.json 2>/dev/null && DETECTED_FRAMEWORKS="$DETECTED_FRAMEWORKS Drizzle"
  grep -q '"tailwindcss"' package.json 2>/dev/null && DETECTED_FRAMEWORKS="$DETECTED_FRAMEWORKS Tailwind"
}
[ -f "requirements.txt" ] && {
  grep -qi "django" requirements.txt 2>/dev/null && DETECTED_FRAMEWORKS="$DETECTED_FRAMEWORKS Django"
  grep -qi "flask" requirements.txt 2>/dev/null && DETECTED_FRAMEWORKS="$DETECTED_FRAMEWORKS Flask"
  grep -qi "fastapi" requirements.txt 2>/dev/null && DETECTED_FRAMEWORKS="$DETECTED_FRAMEWORKS FastAPI"
}

# Detect test framework
DETECTED_TEST_FW="none"
[ -f "package.json" ] && {
  grep -q '"vitest"' package.json 2>/dev/null && DETECTED_TEST_FW="vitest"
  grep -q '"jest"' package.json 2>/dev/null && DETECTED_TEST_FW="jest"
  grep -q '"mocha"' package.json 2>/dev/null && DETECTED_TEST_FW="mocha"
}
[ -f "pytest.ini" ] && DETECTED_TEST_FW="pytest"
[ -f "pyproject.toml" ] && grep -q "pytest" pyproject.toml 2>/dev/null && DETECTED_TEST_FW="pytest"

# Get description from package.json or README
PROJECT_DESC=""
[ -f "package.json" ] && {
  PROJECT_DESC=$(grep '"description"' package.json 2>/dev/null | head -1 | sed 's/.*"description"[[:space:]]*:[[:space:]]*"\(.*\)".*/\1/' || true)
}
if [ -z "$PROJECT_DESC" ] && [ -f "README.md" ]; then
  PROJECT_DESC=$(head -5 README.md | grep -v "^#" | grep -v "^$" | head -1 || true)
fi
[ -z "$PROJECT_DESC" ] && PROJECT_DESC="$PROJECT_NAME project"

# Count source files
SRC_FILE_COUNT=$(find . -type f \
  -not -path '*/node_modules/*' -not -path '*/.git/*' \
  -not -path '*/dist/*' -not -path '*/build/*' \
  -not -path '*/.next/*' -not -path '*/coverage/*' \
  -not -path '*/__pycache__/*' -not -path '*/venv/*' \
  -not -path '*/.planning/*' \
  \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \
     -o -name "*.py" -o -name "*.rs" -o -name "*.go" -o -name "*.java" \
     -o -name "*.rb" -o -name "*.php" \) \
  2>/dev/null | wc -l)

echo "  Language: $PRIMARY_LANG ($MAX_COUNT files)"
echo "  Package manager: $PKG_MANAGER"
echo "  Frameworks: ${DETECTED_FRAMEWORKS:-none detected}"
echo "  Test framework: $DETECTED_TEST_FW"
echo "  Source files: $SRC_FILE_COUNT"

# ─── 1.4 PROJECT.md ──────────────────────────────────────────────

if [ ! -f ".planning/PROJECT.md" ]; then
  echo "[1.4] Generating PROJECT.md..."

  cat > .planning/PROJECT.md << PROJEOF
# $PROJECT_NAME

> Generated by gsd-ruflo-bridge learn on $TODAY

## Overview

$PROJECT_DESC

## Technical Stack

| Component | Technology |
|-----------|-----------|
| Primary Language | $PRIMARY_LANG |
| Package Manager | $PKG_MANAGER |
| Frameworks | ${DETECTED_FRAMEWORKS:-None detected} |
| Test Framework | $DETECTED_TEST_FW |
| Source Files | $SRC_FILE_COUNT |

## Project Structure

\`\`\`
$(find . -maxdepth 2 -type d \
  -not -path '*/node_modules/*' -not -path '*/.git/*' \
  -not -path '*/dist/*' -not -path '*/build/*' \
  -not -path '*/.next/*' -not -path '*/coverage/*' \
  | sort | head -30)
\`\`\`

## Key Files

$(for f in package.json tsconfig.json pyproject.toml Cargo.toml go.mod \
           docker-compose.yml Dockerfile .env.example CLAUDE.md; do
    [ -f "$f" ] && echo "- \`$f\`"
  done)

## Development Workflow

### Build
\`\`\`bash
$(if [ -f "package.json" ]; then
    echo "# Install dependencies"
    echo "$PKG_MANAGER install"
    echo ""
    grep '"build"' package.json >/dev/null 2>&1 && echo "# Build" && echo "$PKG_MANAGER run build"
  elif [ -f "Cargo.toml" ]; then
    echo "cargo build"
  elif [ -f "go.mod" ]; then
    echo "go build ./..."
  elif [ -f "requirements.txt" ]; then
    echo "pip install -r requirements.txt"
  fi)
\`\`\`

### Test
\`\`\`bash
$(if [ "$DETECTED_TEST_FW" = "vitest" ]; then
    echo "$PKG_MANAGER run test"
  elif [ "$DETECTED_TEST_FW" = "jest" ]; then
    echo "$PKG_MANAGER run test"
  elif [ "$DETECTED_TEST_FW" = "pytest" ]; then
    echo "pytest"
  elif [ -f "Cargo.toml" ]; then
    echo "cargo test"
  elif [ -f "go.mod" ]; then
    echo "go test ./..."
  else
    echo "# No test framework detected"
  fi)
\`\`\`

## Constraints

- Follow existing code patterns and conventions
- Maintain backward compatibility
- All changes must include tests

## GSD Configuration

- **Orchestration**: GSD + Ruflo Bridge
- **Memory Namespace**: $NAMESPACE
- **Swarm Strategy**: specialized (hierarchical)
PROJEOF

  echo "  Created .planning/PROJECT.md"
else
  echo "[1.4] PROJECT.md exists ✓"
fi

# ─── 1.5 ROADMAP.md ─────────────────────────────────────────────

if [ ! -f ".planning/ROADMAP.md" ]; then
  echo "[1.5] Generating initial ROADMAP.md..."

  cat > .planning/ROADMAP.md << ROADEOF
# $PROJECT_NAME — Roadmap

> Generated by gsd-ruflo-bridge learn on $TODAY
> Use \`/gsd:add-phase\` to add phases, \`/gsd:plan-phase\` to plan them

## Milestone 1: Current Work

| Phase | Name | Status | Description |
|-------|------|--------|-------------|
| 1.0 | Setup & Learning | done | Codebase analysis and Ruflo memory seeding |

## Backlog

_Use \`/gsd:add-backlog\` to capture ideas here._

## Notes

- Memory namespace: \`$NAMESPACE\`
- Primary language: $PRIMARY_LANG
- Frameworks: ${DETECTED_FRAMEWORKS:-none}
- Run \`/gsd-ruflo-bridge\` to execute phases with Ruflo swarms
ROADEOF

  echo "  Created .planning/ROADMAP.md"
else
  echo "[1.5] ROADMAP.md exists ✓"
fi

# ─── 1.6 CLAUDE.md ──────────────────────────────────────────────

if [ ! -f "CLAUDE.md" ]; then
  echo "[1.6] Generating CLAUDE.md..."

  cat > CLAUDE.md << CLAUDEEOF
# $PROJECT_NAME — Claude Code Configuration

## Project

$PROJECT_DESC

- **Language**: $PRIMARY_LANG
- **Frameworks**: ${DETECTED_FRAMEWORKS:-none}
- **Test Framework**: $DETECTED_TEST_FW
- **Package Manager**: $PKG_MANAGER

## Rules

- Follow existing code patterns and conventions in the codebase
- Run tests before committing: \`$( [ "$DETECTED_TEST_FW" != "none" ] && echo "$PKG_MANAGER run test" || echo "# configure test command" )\`
- Do not commit secrets, credentials, or .env files
- Keep files under 500 lines

## GSD-Ruflo Bridge

This project uses GSD for phase planning and Ruflo for multi-agent execution.

- Planning artifacts: \`.planning/\`
- Ruflo memory namespace: \`$NAMESPACE\`
- Execute phases: \`/gsd-ruflo-bridge\`
- Learn codebase: \`bash ~/.claude/skills/gsd-ruflo-bridge/scripts/learn.sh .\`
CLAUDEEOF

  echo "  Created CLAUDE.md"
else
  echo "[1.6] CLAUDE.md exists ✓"
fi

# ─── 1.7 .gitignore additions ───────────────────────────────────

if [ -f ".gitignore" ]; then
  if ! grep -q ".planning/codebase" .gitignore 2>/dev/null; then
    echo "[1.7] Adding .planning/codebase to .gitignore..."
    echo "" >> .gitignore
    echo "# GSD-Ruflo Bridge (generated analysis - don't commit)" >> .gitignore
    echo ".planning/codebase/" >> .gitignore
    echo ".planning/research/" >> .gitignore
    echo "  Updated .gitignore"
  else
    echo "[1.7] .gitignore already configured ✓"
  fi
else
  echo "[1.7] Creating .gitignore..."
  cat > .gitignore << GITEOF
node_modules/
dist/
build/
.next/
coverage/
*.log
.env
.env.local

# GSD-Ruflo Bridge (generated analysis - don't commit)
.planning/codebase/
.planning/research/
GITEOF
  echo "  Created .gitignore"
fi

echo ""
echo "━━━ Phase 1 Complete: GSD project scaffolded ━━━"
echo ""

fi # end SKIP_GSD check

# ═══════════════════════════════════════════════════════════════════
# PHASE 2: RUFLO MEMORY SEEDING
# ═══════════════════════════════════════════════════════════════════

echo "━━━ Phase 2: Ruflo Memory Seeding ━━━"
echo "Namespace: $NAMESPACE"
echo ""

# ─── 2.1 Project Structure ────────────────────────────────────────

echo "[2.1] Scanning project structure..."

STRUCTURE=$(find . -maxdepth 3 -type f \
  -not -path '*/node_modules/*' \
  -not -path '*/.git/*' \
  -not -path '*/dist/*' \
  -not -path '*/build/*' \
  -not -path '*/.next/*' \
  -not -path '*/coverage/*' \
  -not -path '*/__pycache__/*' \
  -not -path '*/venv/*' \
  -not -path '*/.venv/*' \
  | head -200 \
  | sort)

DIR_TREE=$(find . -maxdepth 3 -type d \
  -not -path '*/node_modules/*' \
  -not -path '*/.git/*' \
  -not -path '*/dist/*' \
  -not -path '*/build/*' \
  | sort)

$RUFLO memory store \
  --namespace "$NAMESPACE" \
  --key "structure-files" \
  --value "$STRUCTURE" \
  --tags "structure,files" \
  --upsert 2>/dev/null || true

$RUFLO memory store \
  --namespace "$NAMESPACE" \
  --key "structure-dirs" \
  --value "$DIR_TREE" \
  --tags "structure,directories" \
  --upsert 2>/dev/null || true

echo "  Stored $(echo "$STRUCTURE" | wc -l) files, $(echo "$DIR_TREE" | wc -l) directories"

# ─── 2.2 Code Patterns ────────────────────────────────────────────

echo "[2.2] Detecting code patterns..."

LANG_COUNTS=""
for ext in ts tsx js jsx py rs go java rb php cs swift kt; do
  count=$(find . -name "*.$ext" -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null | wc -l)
  if [ "$count" -gt 0 ]; then
    LANG_COUNTS="$LANG_COUNTS\n$ext: $count files"
  fi
done

FRAMEWORKS=""
[ -f "package.json" ] && {
  grep -q '"react"' package.json 2>/dev/null && FRAMEWORKS="$FRAMEWORKS React,"
  grep -q '"next"' package.json 2>/dev/null && FRAMEWORKS="$FRAMEWORKS Next.js,"
  grep -q '"vue"' package.json 2>/dev/null && FRAMEWORKS="$FRAMEWORKS Vue,"
  grep -q '"svelte"' package.json 2>/dev/null && FRAMEWORKS="$FRAMEWORKS Svelte,"
  grep -q '"express"' package.json 2>/dev/null && FRAMEWORKS="$FRAMEWORKS Express,"
  grep -q '"fastify"' package.json 2>/dev/null && FRAMEWORKS="$FRAMEWORKS Fastify,"
  grep -q '"hono"' package.json 2>/dev/null && FRAMEWORKS="$FRAMEWORKS Hono,"
  grep -q '"nestjs"' package.json 2>/dev/null && FRAMEWORKS="$FRAMEWORKS NestJS,"
  grep -q '"prisma"' package.json 2>/dev/null && FRAMEWORKS="$FRAMEWORKS Prisma,"
  grep -q '"drizzle"' package.json 2>/dev/null && FRAMEWORKS="$FRAMEWORKS Drizzle,"
  grep -q '"tailwindcss"' package.json 2>/dev/null && FRAMEWORKS="$FRAMEWORKS Tailwind,"
}
[ -f "requirements.txt" ] && {
  grep -qi "django" requirements.txt 2>/dev/null && FRAMEWORKS="$FRAMEWORKS Django,"
  grep -qi "flask" requirements.txt 2>/dev/null && FRAMEWORKS="$FRAMEWORKS Flask,"
  grep -qi "fastapi" requirements.txt 2>/dev/null && FRAMEWORKS="$FRAMEWORKS FastAPI,"
}
[ -f "Cargo.toml" ] && FRAMEWORKS="$FRAMEWORKS Rust/Cargo,"
[ -f "go.mod" ] && FRAMEWORKS="$FRAMEWORKS Go,"

CONFIGS=""
[ -f "tsconfig.json" ] && CONFIGS="$CONFIGS TypeScript,"
[ -f ".eslintrc.json" ] || [ -f ".eslintrc.js" ] || [ -f "eslint.config.js" ] && CONFIGS="$CONFIGS ESLint,"
[ -f ".prettierrc" ] || [ -f ".prettierrc.json" ] && CONFIGS="$CONFIGS Prettier,"
[ -f "biome.json" ] && CONFIGS="$CONFIGS Biome,"
[ -f "docker-compose.yml" ] || [ -f "docker-compose.yaml" ] && CONFIGS="$CONFIGS Docker,"
[ -f "Dockerfile" ] && CONFIGS="$CONFIGS Dockerfile,"
[ -f ".github/workflows" ] && CONFIGS="$CONFIGS GitHub Actions,"

PATTERNS="Languages:\n$LANG_COUNTS\n\nFrameworks: $FRAMEWORKS\n\nConfigs: $CONFIGS"

$RUFLO memory store \
  --namespace "$NAMESPACE" \
  --key "code-patterns" \
  --value "$(echo -e "$PATTERNS")" \
  --tags "patterns,languages,frameworks" \
  --upsert 2>/dev/null || true

echo "  Detected: $FRAMEWORKS"

# ─── 2.3 Architecture ─────────────────────────────────────────────

echo "[2.3] Mapping architecture..."

ENTRY_POINTS=""
for f in src/index.ts src/index.js src/main.ts src/main.js app/page.tsx pages/index.tsx \
         src/app.ts src/app.js main.py app.py manage.py src/main.rs cmd/main.go; do
  [ -f "$f" ] && ENTRY_POINTS="$ENTRY_POINTS $f"
done

PKG_INFO=""
[ -f "package.json" ] && {
  PKG_INFO=$(cat package.json | head -30)
}

KEY_CONFIGS=""
for f in CLAUDE.md .claude/settings.json tsconfig.json package.json \
         pyproject.toml Cargo.toml go.mod docker-compose.yml .env.example; do
  [ -f "$f" ] && KEY_CONFIGS="$KEY_CONFIGS $f"
done

ARCH="Entry points:$ENTRY_POINTS\n\nKey configs:$KEY_CONFIGS\n\nPackage:\n$PKG_INFO"

$RUFLO memory store \
  --namespace "$NAMESPACE" \
  --key "architecture" \
  --value "$(echo -e "$ARCH")" \
  --tags "architecture,entry-points,config" \
  --upsert 2>/dev/null || true

echo "  Entry points:$ENTRY_POINTS"

# ─── 2.4 Test Patterns ────────────────────────────────────────────

echo "[2.4] Analyzing test patterns..."

TEST_FRAMEWORK=""
[ -f "package.json" ] && {
  grep -q '"vitest"' package.json 2>/dev/null && TEST_FRAMEWORK="vitest"
  grep -q '"jest"' package.json 2>/dev/null && TEST_FRAMEWORK="jest"
  grep -q '"mocha"' package.json 2>/dev/null && TEST_FRAMEWORK="mocha"
  grep -q '"playwright"' package.json 2>/dev/null && TEST_FRAMEWORK="$TEST_FRAMEWORK+playwright"
  grep -q '"cypress"' package.json 2>/dev/null && TEST_FRAMEWORK="$TEST_FRAMEWORK+cypress"
}
[ -f "pytest.ini" ] || [ -f "pyproject.toml" ] && grep -q "pytest" pyproject.toml 2>/dev/null && TEST_FRAMEWORK="pytest"

TEST_FILES=$(find . -name "*.test.*" -o -name "*.spec.*" -o -name "test_*" \
  -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null | head -50)

TEST_DIRS=""
for d in tests test __tests__ src/__tests__ spec e2e cypress; do
  [ -d "$d" ] && TEST_DIRS="$TEST_DIRS $d"
done

TEST_COUNT=$(echo "$TEST_FILES" | grep -c . 2>/dev/null || echo "0")

TESTS="Framework: $TEST_FRAMEWORK\nTest dirs:$TEST_DIRS\nTest files: $TEST_COUNT\n\nFiles:\n$TEST_FILES"

$RUFLO memory store \
  --namespace "$NAMESPACE" \
  --key "test-patterns" \
  --value "$(echo -e "$TESTS")" \
  --tags "testing,patterns,coverage" \
  --upsert 2>/dev/null || true

echo "  Framework: $TEST_FRAMEWORK | $TEST_COUNT test files"

# ─── 2.5 Git History ──────────────────────────────────────────────

echo "[2.5] Reading git history..."

if [ -d ".git" ]; then
  RECENT_COMMITS=$(git log --oneline -20 2>/dev/null || echo "no commits")

  HOT_FILES=$(git log --pretty=format: --name-only -50 2>/dev/null \
    | sort | uniq -c | sort -rn | head -20 || echo "none")

  CONTRIBUTORS=$(git shortlog -sn --no-merges -10 2>/dev/null || echo "none")

  BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")

  LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "no tags")

  GIT_INFO="Branch: $BRANCH\nLast tag: $LAST_TAG\n\nRecent commits:\n$RECENT_COMMITS\n\nHot files (most changed):\n$HOT_FILES\n\nContributors:\n$CONTRIBUTORS"

  $RUFLO memory store \
    --namespace "$NAMESPACE" \
    --key "git-history" \
    --value "$(echo -e "$GIT_INFO")" \
    --tags "git,history,contributors" \
    --upsert 2>/dev/null || true

  echo "  Branch: $BRANCH | Last tag: $LAST_TAG | $(echo "$RECENT_COMMITS" | wc -l) recent commits"
else
  echo "  Not a git repo, skipping"
fi

# ─── 2.6 Documentation ────────────────────────────────────────────

echo "[2.6] Ingesting documentation..."

DOC_COUNT=0

for docfile in README.md CLAUDE.md CONTRIBUTING.md ARCHITECTURE.md docs/README.md .planning/PROJECT.md; do
  if [ -f "$docfile" ]; then
    CONTENT=$(head -100 "$docfile")
    $RUFLO memory store \
      --namespace "$NAMESPACE" \
      --key "doc-$(basename "$docfile" .md | tr '[:upper:]' '[:lower:]')" \
      --value "$CONTENT" \
      --tags "documentation,$(basename "$docfile" .md | tr '[:upper:]' '[:lower:]')" \
      --upsert 2>/dev/null || true
    DOC_COUNT=$((DOC_COUNT + 1))
  fi
done

# Store .env.example if it exists (safe - no secrets)
if [ -f ".env.example" ]; then
  $RUFLO memory store \
    --namespace "$NAMESPACE" \
    --key "env-vars" \
    --value "$(cat .env.example)" \
    --tags "config,environment" \
    --upsert 2>/dev/null || true
  DOC_COUNT=$((DOC_COUNT + 1))
fi

# Store the GSD project config in memory so agents know the setup
if [ -f ".planning/PROJECT.md" ]; then
  $RUFLO memory store \
    --namespace "$NAMESPACE" \
    --key "gsd-project" \
    --value "$(cat .planning/PROJECT.md)" \
    --tags "gsd,project,config" \
    --upsert 2>/dev/null || true
fi

if [ -f ".planning/ROADMAP.md" ]; then
  $RUFLO memory store \
    --namespace "$NAMESPACE" \
    --key "gsd-roadmap" \
    --value "$(cat .planning/ROADMAP.md)" \
    --tags "gsd,roadmap,phases" \
    --upsert 2>/dev/null || true
fi

echo "  Ingested $DOC_COUNT documents + GSD artifacts"

# ─── Deep mode: additional analysis ───────────────────────────────

if [ "$DEEP" = true ]; then
  echo ""
  echo "[DEEP] Running extended analysis..."

  echo "  Scanning API routes..."
  API_ROUTES=$(grep -rn "router\.\|app\.\(get\|post\|put\|delete\|patch\)" \
    --include="*.ts" --include="*.js" \
    -l 2>/dev/null | head -20 || echo "none found")

  $RUFLO memory store \
    --namespace "$NAMESPACE" \
    --key "api-routes" \
    --value "$API_ROUTES" \
    --tags "api,routes,endpoints" \
    --upsert 2>/dev/null || true

  echo "  Scanning data models..."
  MODELS=$(grep -rn "model\|schema\|@Entity\|class.*Model\|def.*migration" \
    --include="*.ts" --include="*.js" --include="*.py" \
    -l 2>/dev/null | head -20 || echo "none found")

  $RUFLO memory store \
    --namespace "$NAMESPACE" \
    --key "data-models" \
    --value "$MODELS" \
    --tags "database,models,schema" \
    --upsert 2>/dev/null || true

  echo "  Building import graph..."
  IMPORTS=$(grep -rn "^import\|^from.*import\|require(" \
    --include="*.ts" --include="*.js" --include="*.py" \
    2>/dev/null | head -100 || echo "none")

  $RUFLO memory store \
    --namespace "$NAMESPACE" \
    --key "import-graph" \
    --value "$IMPORTS" \
    --tags "imports,dependencies,graph" \
    --upsert 2>/dev/null || true

  echo "  Finding TODOs and tech debt markers..."
  TODOS=$(grep -rn "TODO\|FIXME\|HACK\|XXX\|WORKAROUND" \
    --include="*.ts" --include="*.js" --include="*.py" --include="*.rs" --include="*.go" \
    2>/dev/null | head -50 || echo "none")

  $RUFLO memory store \
    --namespace "$NAMESPACE" \
    --key "tech-debt" \
    --value "$TODOS" \
    --tags "todo,fixme,tech-debt" \
    --upsert 2>/dev/null || true

  echo "  Deep analysis complete"
fi

# ═══════════════════════════════════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════════════════════════════════

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  Setup & Learning Complete                                  ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
if [ "$SKIP_GSD" = false ]; then
echo "GSD Project:"
echo "  .planning/PROJECT.md   — Project metadata & tech stack"
echo "  .planning/ROADMAP.md   — Phase roadmap (add phases with /gsd:add-phase)"
echo "  CLAUDE.md              — Claude Code configuration"
echo ""
fi
echo "Ruflo Memory (namespace: $NAMESPACE):"
echo "  structure-files     : Project file tree"
echo "  structure-dirs      : Directory layout"
echo "  code-patterns       : Languages, frameworks, configs"
echo "  architecture        : Entry points, key files"
echo "  test-patterns       : Test framework, test locations"
echo "  git-history         : Recent commits, hot files, contributors"
echo "  doc-*               : README, CLAUDE.md, PROJECT.md, etc."
echo "  gsd-project         : GSD project configuration"
echo "  gsd-roadmap         : Phase roadmap"
if [ "$DEEP" = true ]; then
echo "  api-routes          : API endpoint files"
echo "  data-models         : Database model files"
echo "  import-graph        : Top-level import relationships"
echo "  tech-debt           : TODO/FIXME/HACK markers"
fi
echo ""
echo "Next steps:"
echo "  1. Review .planning/PROJECT.md and ROADMAP.md"
echo "  2. Add phases:  /gsd:add-phase"
echo "  3. Plan a phase: /gsd:plan-phase"
echo "  4. Execute with swarm: /gsd-ruflo-bridge"
echo ""
echo "Query memory: npx claude-flow@v3alpha memory search --namespace $NAMESPACE --query '<topic>'"

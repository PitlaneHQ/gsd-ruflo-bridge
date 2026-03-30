#!/usr/bin/env bash
# gsd-ruflo-bridge: learn
# Analyzes an existing codebase and seeds Ruflo memory so agents start informed.
#
# Usage: ./learn.sh [project-dir] [--namespace NAME] [--deep]
#
# What it stores:
#   - Project structure (directory tree, key files)
#   - Code patterns (languages, frameworks, conventions)
#   - Architecture (entry points, modules, dependencies)
#   - Test patterns (test framework, coverage approach, test locations)
#   - Git history (recent changes, active contributors, hot files)
#   - Existing docs (README, CLAUDE.md, package.json metadata)

set -euo pipefail

PROJECT_DIR="${1:-.}"
NAMESPACE="project-memory"
DEEP=false

# Parse flags
shift || true
while [[ $# -gt 0 ]]; do
  case $1 in
    --namespace) NAMESPACE="$2"; shift 2 ;;
    --deep) DEEP=true; shift ;;
    *) echo "Unknown flag: $1"; exit 1 ;;
  esac
done

RUFLO="npx claude-flow@v3alpha"
cd "$PROJECT_DIR"

echo "=== GSD-Ruflo Bridge: Learning from $(basename "$(pwd)") ==="
echo "Namespace: $NAMESPACE"
echo ""

# ─── 1. Project Structure ───────────────────────────────────────────

echo "[1/6] Scanning project structure..."

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

# ─── 2. Code Patterns ───────────────────────────────────────────────

echo "[2/6] Detecting code patterns..."

# Language breakdown
LANG_COUNTS=""
for ext in ts tsx js jsx py rs go java rb php cs swift kt; do
  count=$(find . -name "*.$ext" -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null | wc -l)
  if [ "$count" -gt 0 ]; then
    LANG_COUNTS="$LANG_COUNTS\n$ext: $count files"
  fi
done

# Framework detection
FRAMEWORKS=""
[ -f "package.json" ] && {
  grep -q '"react"' package.json 2>/dev/null && FRAMEWORKS="$FRAMEWORKS React,"
  grep -q '"next"' package.json 2>/dev/null && FRAMEWORKS="$FRAMEWORKS Next.js,"
  grep -q '"vue"' package.json 2>/dev/null && FRAMEWORKS="$FRAMEWORKS Vue,"
  grep -q '"express"' package.json 2>/dev/null && FRAMEWORKS="$FRAMEWORKS Express,"
  grep -q '"fastify"' package.json 2>/dev/null && FRAMEWORKS="$FRAMEWORKS Fastify,"
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

# Config patterns
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

# ─── 3. Architecture ────────────────────────────────────────────────

echo "[3/6] Mapping architecture..."

# Entry points
ENTRY_POINTS=""
for f in src/index.ts src/index.js src/main.ts src/main.js app/page.tsx pages/index.tsx \
         src/app.ts src/app.js main.py app.py manage.py src/main.rs cmd/main.go; do
  [ -f "$f" ] && ENTRY_POINTS="$ENTRY_POINTS $f"
done

# Package info
PKG_INFO=""
[ -f "package.json" ] && {
  PKG_INFO=$(cat package.json | head -30)
}

# Key config files
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

# ─── 4. Test Patterns ───────────────────────────────────────────────

echo "[4/6] Analyzing test patterns..."

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

# ─── 5. Git History ─────────────────────────────────────────────────

echo "[5/6] Reading git history..."

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

# ─── 6. Documentation ───────────────────────────────────────────────

echo "[6/6] Ingesting documentation..."

DOC_COUNT=0

for docfile in README.md CLAUDE.md CONTRIBUTING.md ARCHITECTURE.md docs/README.md; do
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

echo "  Ingested $DOC_COUNT documents"

# ─── Deep mode: additional analysis ─────────────────────────────────

if [ "$DEEP" = true ]; then
  echo ""
  echo "[DEEP] Running extended analysis..."

  # API routes
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

  # Database models/schemas
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

  # Import graph (top-level dependencies between files)
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

  # TODO/FIXME/HACK comments
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

# ─── Summary ─────────────────────────────────────────────────────────

echo ""
echo "=== Learning Complete ==="
echo "Namespace: $NAMESPACE"
echo ""
echo "Stored memories:"
echo "  - structure-files     : Project file tree"
echo "  - structure-dirs      : Directory layout"
echo "  - code-patterns       : Languages, frameworks, configs"
echo "  - architecture        : Entry points, key files"
echo "  - test-patterns       : Test framework, test locations"
echo "  - git-history         : Recent commits, hot files, contributors"
echo "  - doc-*               : README, CLAUDE.md, etc."
if [ "$DEEP" = true ]; then
echo "  - api-routes          : API endpoint files"
echo "  - data-models         : Database model files"
echo "  - import-graph        : Top-level import relationships"
echo "  - tech-debt           : TODO/FIXME/HACK markers"
fi
echo ""
echo "Agents can now query: npx claude-flow@v3alpha memory search --namespace $NAMESPACE --query '<topic>'"
echo ""
echo "Run swarm with pre-loaded memory:"
echo "  /gsd-ruflo-bridge"

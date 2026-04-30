# Agent Studio — just command runner
# https://github.com/casey/just
#
# Usage: just <recipe>
#        just          (shows this help)

set shell := ["bash", "-cu"]

# List available recipes
[private]
default:
    @just --list

# ── Build ──────────────────────────────────────────────────────────────────────

# Full build: schema-gen → flow-gen → webview → extension
build:
    npm run build

# Dev build (skips TOON generation)
build-dev:
    npm run build:dev

# Build webview only
build-webview:
    npm run build:webview

# Build extension only
build-extension:
    npm run build:extension

# Generate TOON schema from workflow-schema.json
gen-toon:
    npm run generate:toon

# Generate editing flow
gen-flow:
    npm run generate:editing-flow

# ── Watch ──────────────────────────────────────────────────────────────────────

# Watch extension (rebuild on change)
watch:
    npm run watch

# Watch webview (Vite HMR dev server)
watch-webview:
    npm run watch:webview

# ── Quality Gates ──────────────────────────────────────────────────────────────

# Biome lint + format + auto-fix (run after every code change)
check:
    npm run check

# Biome lint only (no auto-fix)
lint:
    npm run lint

# Biome format + write
fmt:
    npm run format

# Full quality gate: check then build (run before commit/PR)
gate: check build

# ── Tests ──────────────────────────────────────────────────────────────────────

# Webview Vitest unit tests
test:
    npm test

# E2E tests (⚠ BROKEN — wdio.conf.ts does not exist yet)
test-e2e:
    npm run test:e2e

# ── Dev Workflow ───────────────────────────────────────────────────────────────

# Install all dependencies (root + webview)
install:
    npm install
    cd src/webview && npm install

# TypeScript compile check (no emit)
compile:
    npm run compile

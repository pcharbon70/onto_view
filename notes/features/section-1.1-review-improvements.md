# Section 1.1 Review Improvements - Implementation Plan

**Feature Branch:** `feature/phase-1.1-review-improvements`
**Created:** 2025-12-10
**Status:** In Progress

## Overview

Implementing all Priority 0 (Critical) and Priority 1 (High) fixes identified in the comprehensive code review of Section 1.1.

**Review Document:** `notes/reviews/section-1.1-comprehensive-review.md`

## Priority 0: Critical Security & Performance Issues

### ✅ Issue 1: Path Traversal Vulnerability (CRITICAL)
- **Status:** Not Started
- **File:** `lib/onto_view/ontology/import_resolver.ex`
- **Fix:** Validate file:// URIs stay within base directory
- **Tests:** `test/onto_view/ontology/security_test.exs`

### ✅ Issue 2: Symlink Following Vulnerability (CRITICAL)
- **Status:** Not Started
- **File:** `lib/onto_view/ontology/loader.ex`
- **Fix:** Add symlink detection using File.lstat/1
- **Tests:** `test/onto_view/ontology/security_test.exs`

### ✅ Issue 3: Missing File Size Validation (CRITICAL)
- **Status:** Not Started
- **File:** `lib/onto_view/ontology/loader.ex`
- **Fix:** Enforce max_file_size_bytes config
- **Tests:** `test/onto_view/ontology/security_test.exs`

### ✅ Issue 4: Graph Reloading Performance (CRITICAL)
- **Status:** Not Started
- **File:** `lib/onto_view/ontology/import_resolver.ex`
- **Fix:** Cache graphs in metadata, eliminate file reloading
- **Tests:** Existing integration tests

## Priority 1: High-Priority Security & Quality

### ✅ Issue 5: Resource Exhaustion via Import Chains
- **Status:** Not Started
- **Files:** `config/config.exs`, `lib/onto_view/ontology/import_resolver.ex`
- **Fix:** Add max_total_imports and max_imports_per_ontology limits
- **Tests:** `test/onto_view/ontology/security_test.exs`

### ✅ Issue 6: Error Message Information Disclosure
- **Status:** Not Started
- **Files:** New `lib/onto_view/ontology/error_sanitizer.ex`, update loader/resolver
- **Fix:** Sanitize error messages for external display
- **Tests:** `test/onto_view/ontology/error_sanitizer_test.exs`

### ✅ Issue 7: IRI Resolution Strategies Untested
- **Status:** Not Started
- **Tests:** New `test/onto_view/ontology/iri_resolution_test.exs`
- **Fix:** Add comprehensive tests for all 3 strategies

### ✅ Issue 8: Code Duplication
- **Status:** Not Started
- **Files:** New `lib/onto_view/ontology/rdf_helpers.ex`, `test/support/fixture_helpers.ex`
- **Fix:** Extract common utilities
- **Tests:** Test all refactored code paths

## Implementation Progress

**Current Coverage:** 89.2% (61 tests)
**Target Coverage:** 95%+ (~100-105 tests)

## Detailed Plan

See full implementation plan in this file for:
- Specific code changes
- Test requirements
- Implementation order
- Success criteria
- Risk mitigation

---

# Detailed Implementation Plan

[The full plan from the feature-planner agent follows below]

## Executive Summary

This plan addresses all **Priority 0 (Critical)** and **Priority 1 (High)** issues identified in the comprehensive code review of Section 1.1 (Ontology File Loading & Import Resolution). The plan follows a security-first approach, then addresses performance optimization, code quality, and test coverage improvements.

**Total Estimated Effort:** 16-20 hours
**Target Completion:** 2 weeks
**Success Criteria:**
- All security vulnerabilities resolved
- Test coverage increased from 89.2% to 95%+
- All existing tests continue to pass (61 tests)
- Zero breaking changes to public API
- Performance improvement (eliminate 2x file I/O overhead)

[Full plan content continues as provided by the agent...]


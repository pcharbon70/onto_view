# Release Process

## Ontology Documentation Platform

This document defines the official **release workflow** aligned with
Phase 5 of the project plan.

------------------------------------------------------------------------

## Release Types

We use semantic versioning:

-   **MAJOR** --- incompatible ontology or API changes
-   **MINOR** --- new backward-compatible features
-   **PATCH** --- bug fixes and security patches

------------------------------------------------------------------------

## Pre-Release Checklist

Before creating a release:

-   [ ] All Phase tasks complete for this milestone
-   [ ] All unit tests passing
-   [ ] All integration tests passing
-   [ ] Ontology TTL validation passing
-   [ ] CI pipeline fully green
-   [ ] Documentation updated
-   [ ] README updated if architecture changed

------------------------------------------------------------------------

## Release Steps

1.  Merge `develop` into `main`

2.  Tag release using semantic version

    ``` bash
    git tag vX.Y.Z
    git push origin vX.Y.Z
    ```

3.  Generate ontology export artifacts (TTL + JSON)

4.  Build production Phoenix release

5.  Publish GitHub Release with changelog

6.  Deploy to production environment

------------------------------------------------------------------------

## Hotfix Releases

Hotfixes follow:

1.  Branch from `main`
2.  Apply fix
3.  Add regression test
4.  Tag patch version
5.  Deploy immediately

------------------------------------------------------------------------

## Ontology Versioning

Each release must include:

-   Updated `owl:versionIRI`
-   Updated `owl:versionInfo`
-   Migration notes if breaking changes occurred

------------------------------------------------------------------------

## Rollback Policy

If a release fails:

-   Roll back to previous stable tag
-   Restore previous ontology snapshot
-   Re-open CI validation before re-release

------------------------------------------------------------------------

This release process ensures stability, reproducibility, and long-term
maintainability.


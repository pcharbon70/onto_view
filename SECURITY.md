# Security Policy

## Ontology Documentation Platform

We take security seriously and appreciate responsible disclosure of
vulnerabilities.

------------------------------------------------------------------------

## Supported Versions

Only the latest released version and the active development branch are
supported with security updates.

------------------------------------------------------------------------

## Reporting a Vulnerability

If you discover a security vulnerability, please do **not** open a
public issue.

Instead:

1.  Email the maintainers directly (preferred)
2.  Provide a detailed description of the vulnerability
3.  Include steps to reproduce if applicable
4.  Include affected versions

You will receive an acknowledgment within 72 hours.

------------------------------------------------------------------------

## Security Scope

This security policy applies to:

-   Ontology ingestion pipeline
-   RDF/OWL parsing and canonical model
-   LiveView documentation UI
-   Graph visualization JavaScript hooks
-   Export endpoints
-   CI/CD and deployment infrastructure

------------------------------------------------------------------------

## Disclosure Process

1.  Vulnerability is reported privately
2.  Maintainers confirm and assess severity
3.  A fix is developed
4.  A coordinated release is published
5.  Public disclosure occurs after patch availability

------------------------------------------------------------------------

## Security Best Practices

All contributors should:

-   Avoid introducing dynamic code execution paths
-   Validate all TTL and RDF input strictly
-   Enforce read-only behavior in production
-   Never hard-code secrets in the repository
-   Follow Phoenix security guidelines

------------------------------------------------------------------------

Thank you for helping keep the Ontology Documentation Platform secure.


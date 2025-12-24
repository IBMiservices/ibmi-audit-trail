# Changelog - ibmi-audit-trail

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

**[🇫🇷 Version française](CHANGELOG.md)** | **🇬🇧 English version**

## [Unreleased]

### Coming Soon
- Asynchronous mode for improved performance
- Composite key support
- Integration with ibmi-json for serialization
- JSON data compression
- REST API for history consultation
- Web visualization dashboard

## [0.1.0] - 2025-12-24

### Added
- Basic audit system for INSERT/UPDATE/DELETE
- AUDITLOG table with optimized indexes
- Simple API to record operations
- History query functions
- Flexible system configuration
- Metadata capture (user, IP, job, program)
- Complete documentation (API + Compliance)
- Usage examples
- GDPR/SOX/ISO 27001 compliance guide
- Project structure compatible with ibmi-dependencies

### Documentation
- Complete README.md
- API.md with full reference
- COMPLIANCE.md for regulatory compliance
- Demonstration program

### Infrastructure
- VS Code configuration (.vscode/)
- Build tasks
- iproj.json for Tobi
- Rules.mk for compilation
- Empty dependencies.json (no dependencies)

## Version Format

- **Major** (X.0.0): Incompatible API changes
- **Minor** (0.X.0): Backward-compatible feature additions
- **Patch** (0.0.X): Bug fixes

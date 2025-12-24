# Changelog - ibmi-audit-trail

Tous les changements notables de ce projet seront documentés dans ce fichier.

Le format est basé sur [Keep a Changelog](https://keepachangelog.com/fr/1.0.0/),
et ce projet adhère au [Versioning Sémantique](https://semver.org/lang/fr/).

**🇫🇷 Version française** | **[🇬🇧 English version](CHANGELOG.en.md)**

## [Non publié]

### À venir
- Mode asynchrone pour améliorer les performances
- Support de clés composites
- Intégration avec ibmi-json pour sérialisation
- Compression des données JSON
- API REST pour consultation de l'historique
- Dashboard web de visualisation

## [0.1.0] - 2025-12-24

### Ajouté
- Système d'audit de base pour INSERT/UPDATE/DELETE
- Table AUDITLOG avec indexes optimisés
- API simple pour enregistrer les opérations
- Fonctions de consultation d'historique
- Configuration flexible du système
- Capture des métadonnées (user, IP, job, programme)
- Documentation complète (API + Conformité)
- Exemples d'utilisation
- Guide de conformité RGPD/SOX/ISO 27001
- Structure de projet compatible avec ibmi-dependencies

### Documentation
- README.md complet
- API.md avec référence complète
- COMPLIANCE.md pour la conformité réglementaire
- Programme de démonstration

### Infrastructure
- Configuration VS Code (.vscode/)
- Tasks de build
- iproj.json pour Tobi
- Rules.mk pour compilation
- dependencies.json vide (pas de dépendances)

## Format des versions

- **Majeure** (X.0.0) : Changements incompatibles de l'API
- **Mineure** (0.X.0) : Ajout de fonctionnalités compatibles
- **Patch** (0.0.X) : Corrections de bugs

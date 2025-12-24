# Makefile rules for ibmi-audit-trail
.SUFFIXES: .rpgle .rpgleinc .bnd

# Répertoires
CORE_DIR = core
REF_DIR = ref
EXAMPLES_DIR = examples

# Objets
OBJECTS = $(CORE_DIR)/auditlog

# Cible par défaut
all: auditlog demo

# Module principal
auditlog: $(CORE_DIR)/auditlog.rpgle $(REF_DIR)/auditlog.rpgleinc
	@echo "Compilation de auditlog..."
	system "CRTRPGMOD MODULE($(OBJLIB)/AUDITLOG) SRCSTMF('$(CORE_DIR)/auditlog.rpgle') DBGVIEW(*SOURCE) INCDIR('$(REF_DIR)')"
	system "CRTSRVPGM SRVPGM($(OBJLIB)/AUDITLOG) MODULE($(OBJLIB)/AUDITLOG) EXPORT(*SRCFILE) SRCFILE($(OBJLIB)/QSRVSRC) SRCMBR(AUDITLOG) BNDDIR(QC2LE)"

# Programme de démonstration
demo: $(EXAMPLES_DIR)/demo_audit.rpgle
	@echo "Compilation de demo_audit..."
	system "CRTBNDRPG PGM($(OBJLIB)/DEMO_AUDIT) SRCSTMF('$(EXAMPLES_DIR)/demo_audit.rpgle') DBGVIEW(*SOURCE) INCDIR('$(REF_DIR)') BNDDIR(AUDITLOG)"

# Nettoyage
clean:
	@echo "Nettoyage des objets..."
	-system "DLTMOD MODULE($(OBJLIB)/AUDITLOG)"
	-system "DLTSRVPGM SRVPGM($(OBJLIB)/AUDITLOG)"
	-system "DLTPGM PGM($(OBJLIB)/DEMO_AUDIT)"

.PHONY: all auditlog demo clean

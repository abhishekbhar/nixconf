# Convenience Makefile — delegates to the parent Makefile in nixconf/
# This lets you run `make` from inside the devcontainer/ directory.
# All targets pass through to ../Makefile with the devbox- prefix.

%:
	$(MAKE) -C .. $@

.PHONY: help
help:
	$(MAKE) -C .. help

# Default target
.DEFAULT_GOAL := help

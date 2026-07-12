# forge-provision convenience targets. The scripts under scripts/ are the
# implementation; these targets call them. Recipes use tabs (Make requires it).

SANDBOX := scripts/sandbox/claude-box

# Let `make redact build` / `make redact run` read as subcommands: capture the words
# after the `redact` goal, hand them to the dispatcher, and turn them into do-nothing
# goals so make does not try to build them itself.
ifeq (redact,$(firstword $(MAKECMDGOALS)))
  REDACT_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
  $(eval $(REDACT_ARGS):;@:)
endif

.DEFAULT_GOAL := help
.PHONY: help redact

help:
	@echo "forge-provision:"
	@echo "  make redact build [<gpg-recipient>]   build claude-box-redact (forge-redact + Presidio in the VM)"
	@echo "  make redact run                       run Claude in the redaction box (interactive)"
	@echo "  for claude args, call the script:     $(SANDBOX)/redact run -p '...'"

redact:
	@$(SANDBOX)/redact $(REDACT_ARGS)

# test-pattern-rtl — convenience targets. See docs/pattern-generator-rtl-prd.md.
.PHONY: check lint provenance sim

check: lint provenance sim ## run all gates (lint + provenance + sim)

lint: ## Verilator -Wall lint of the portable RTL
	./flow/lint/run_lint.sh

provenance: ## clean-room / SPDX provenance check
	./flow/provenance_check.sh

sim: ## self-checking Verilator sims (VTG + patterns, incl. odd geometry)
	./flow/sim/run_sim.sh

# test-pattern-rtl — convenience targets. See docs/pattern-generator-rtl-prd.md.
.PHONY: check lint provenance

check: lint provenance ## run all M0 gates

lint: ## Verilator -Wall lint of the portable RTL
	./flow/lint/run_lint.sh

provenance: ## clean-room / SPDX provenance check
	./flow/provenance_check.sh

# test-pattern-rtl — convenience targets. See docs/pattern-generator-rtl-prd.md.
.PHONY: check lint yosys-smoke provenance sim

check: lint yosys-smoke provenance sim ## run all gates

lint: ## Verilator -Wall lint of the portable RTL
	./flow/lint/run_lint.sh

yosys-smoke: ## Yosys read_verilog smoke (Yosys-tested subset, PRD §13)
	./flow/lint/yosys_smoke.sh

provenance: ## clean-room / SPDX provenance check
	./flow/provenance_check.sh

sim: ## self-checking Verilator sims (VTG + patterns, incl. odd geometry)
	./flow/sim/run_sim.sh

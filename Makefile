# test-pattern-rtl — convenience targets. See docs/pattern-generator-rtl-prd.md.
.PHONY: check lint yosys-smoke provenance sim report build-artyz7 report-artyz7

check: lint yosys-smoke provenance sim ## run all gates

lint: ## Verilator -Wall lint of the portable RTL
	./flow/lint/run_lint.sh

yosys-smoke: ## Yosys read_verilog smoke (Yosys-tested subset, PRD §13)
	./flow/lint/yosys_smoke.sh

provenance: ## clean-room / SPDX provenance check
	./flow/provenance_check.sh

sim: ## self-checking Verilator sims (VTG + patterns, incl. odd geometry)
	./flow/sim/run_sim.sh

report: ## show the last Tang Nano 9K build's timing + resource report
	@./boards/tangnano9k/flow/build.sh report

build-artyz7: ## build the Arty Z7-20 bitstream with Vivado (default RES=1080p)
	RES="$(RES)" ZONES="$(ZONES)" CLK_ALT="$(CLK_ALT)" ./boards/artyz7/flow/build.sh

report-artyz7: ## show the last Arty Z7-20 Vivado build report
	@./boards/artyz7/flow/build.sh report

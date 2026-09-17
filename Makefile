# `make run` — build + install on the phone connected over wireless adb,
# auto-detecting this Mac's LAN IP and the phone's adb address each time
# (see scripts/run_phone.sh for why those aren't hardcoded).
.PHONY: run

run:
	@bash scripts/run_phone.sh

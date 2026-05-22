.PHONY: dictionary dictionary-mail dictionary-standard compile check test test-dictionary test-smoke

dictionary:
	@printf '### Mail.app\n'
	@sdef /System/Applications/Mail.app
	@printf '\n### CocoaStandard.sdef\n'
	@cat /System/Library/ScriptingDefinitions/CocoaStandard.sdef

dictionary-mail:
	@sdef /System/Applications/Mail.app

dictionary-standard:
	@cat /System/Library/ScriptingDefinitions/CocoaStandard.sdef

compile:
	@set -euo pipefail; \
	find scripts/applescripts -name '*.applescript' -print | while IFS= read -r file; do \
		osacompile -o /tmp/$$(echo "$$file" | tr '/' '_' | sed 's/\.applescript$$/.scpt/') "$$file" || exit 1; \
	done; \
	find scripts/tests scripts/commands -name '*.sh' -print | while IFS= read -r file; do \
		bash -n "$$file" || exit 1; \
	done

check:
	@command -v jq >/dev/null || { echo "check: jq is required"; exit 1; }
	@osascript -e 'tell application "Mail" to get name' >/dev/null || { echo "check: Mail.app not available"; exit 1; }
	@echo "Mail.app and jq are available"

test: test-dictionary test-smoke

test-dictionary:
	@bash scripts/tests/dictionary_contract.sh

test-smoke:
	@bash scripts/tests/smoke_mail.sh

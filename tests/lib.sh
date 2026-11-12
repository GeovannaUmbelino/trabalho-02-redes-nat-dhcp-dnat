#!/bin/sh
# Helpers de teste. check "descricao" comando args...
PASS=0; FAIL=0
check() {
  _d=$1; shift
  if "$@" >/dev/null 2>&1; then printf '  [ OK ]  %s\n' "$_d"; PASS=$((PASS+1))
  else printf '  [FALHA] %s\n' "$_d"; FAIL=$((FAIL+1)); fi
}
summary() { echo "  -> $PASS ok, $FAIL falhas"; [ "$FAIL" -eq 0 ]; }

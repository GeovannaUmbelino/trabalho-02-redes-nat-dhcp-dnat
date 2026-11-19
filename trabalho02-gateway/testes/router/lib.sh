# testes/router/lib.sh - funcoes dos testes (usar com: ROOT=...; . lib.sh)
. "$ROOT/lib/common.sh"
[ "$(id -u)" -eq 0 ] || die "execute como root"
PASS=0; FAIL=0
titulo() { printf '\n=== %s ===\n' "$*"; }
check() {
  _d=$1; shift
  if "$@" >/dev/null 2>&1; then
    printf '[ OK ] %s\n' "$_d"; PASS=$((PASS+1))
  else
    printf '[FALHOU] %s\n' "$_d"; FAIL=$((FAIL+1))
  fi
}
info() { printf '[INFO] %s\n' "$*"; }
resumo() { printf -- '--> %s ok, %s falhas\n' "$PASS" "$FAIL"; [ "$FAIL" -eq 0 ]; }
regras() { { pfctl -sn; pfctl -sr; } 2>/dev/null; }

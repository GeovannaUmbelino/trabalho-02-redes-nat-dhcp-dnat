#!/bin/sh
# Roda todos os testes do roteador (tests/router/*.sh).
D=$(cd "$(dirname "$0")" && pwd); rc=0
for t in "$D"/router/*.sh; do sh "$t" || rc=1; echo; done
[ $rc -eq 0 ] && echo "TODOS OS TESTES DO ROTEADOR PASSARAM" || echo "HÁ FALHAS: revise acima"
exit $rc

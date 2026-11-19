#!/bin/sh
# rodar-todos.sh - executa os testes 01..06 no roteador
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
D="$ROOT/testes/router"
falhas=0
for t in "$D"/t0*.sh; do
  sh "$t" || falhas=$((falhas+1))
done
echo
if [ "$falhas" -eq 0 ]; then
  echo "########  TODOS OS TESTES DO ROTEADOR PASSARAM  ########"
else
  echo "########  $falhas TESTE(S) COM FALHA (veja [FALHOU] acima)  ########"
fi
[ "$falhas" -eq 0 ]

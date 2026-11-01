-- Grão: uma etapa da execução ativa de cada competência.
SELECT c.competencia, e.execucao_id, e.origem, e.origem_sha256,
  t.ordem, t.etapa, t.entrada, t.saida, t.excluidos, t.unidade
FROM competencias c
JOIN execucoes e ON e.execucao_id = c.execucao_id
JOIN etapas t ON t.execucao_id = e.execucao_id
ORDER BY c.competencia, t.ordem;

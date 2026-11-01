-- Grão final: uma linha por competência.
-- As duas bases são agregadas antes dos JOINs para evitar multiplicação de linhas.
WITH base_valida AS (
  SELECT competencia, COUNT(*) AS atendimentos_validos,
    COUNT(avaliacao) AS avaliacoes_validas,
    COUNT(DISTINCT atendente) AS atendentes,
    COUNT(DISTINCT NULLIF(cliente, '')) AS clientes,
    AVG(tma_minutos) AS tma_medio_min,
    AVG(avaliacao) AS avaliacao_media
  FROM validos GROUP BY competencia
), base_excluida AS (
  SELECT competencia, COUNT(*) AS atendimentos_excluidos
  FROM excluidos GROUP BY competencia
)
SELECT c.competencia, c.total_extraido,
  COALESCE(v.atendimentos_validos, 0) AS atendimentos_validos,
  COALESCE(e.atendimentos_excluidos, 0) AS atendimentos_excluidos,
  COALESCE(v.avaliacoes_validas, 0) AS avaliacoes_validas,
  ROUND(100.0 * v.avaliacoes_validas / NULLIF(v.atendimentos_validos, 0), 4) AS cobertura_avaliacao_pct,
  ROUND(100.0 * COALESCE(e.atendimentos_excluidos, 0) / NULLIF(c.total_extraido, 0), 4) AS exclusoes_pct,
  v.atendentes, v.clientes,
  ROUND(v.tma_medio_min, 4) AS tma_medio_min,
  ROUND(v.avaliacao_media, 4) AS avaliacao_media,
  c.total_extraido = COALESCE(v.atendimentos_validos, 0) + COALESCE(e.atendimentos_excluidos, 0) AS reconciliado
FROM competencias c
LEFT JOIN base_valida v ON v.competencia = c.competencia
LEFT JOIN base_excluida e ON e.competencia = c.competencia
ORDER BY c.competencia;

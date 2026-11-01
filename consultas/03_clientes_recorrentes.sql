-- Recorrência de contatos no mês não prova retrabalho nem falta de resolução.
WITH demanda AS (
  SELECT competencia, cliente, COUNT(*) AS atendimentos,
    COUNT(DISTINCT DATE(inicio)) AS dias_ativos,
    COUNT(DISTINCT atendente) AS atendentes_distintos
  FROM validos
  WHERE NULLIF(TRIM(cliente), '') IS NOT NULL
  GROUP BY competencia, cliente
), total AS (
  SELECT competencia, COUNT(*) AS total_validos
  FROM validos GROUP BY competencia
)
SELECT d.competencia, d.cliente, d.atendimentos, d.dias_ativos,
  d.atendentes_distintos,
  ROUND(100.0 * d.atendimentos / NULLIF(t.total_validos, 0), 4) AS participacao_validos_pct
FROM demanda d JOIN total t ON t.competencia = d.competencia
WHERE d.atendimentos >= 2
ORDER BY d.competencia, d.atendimentos DESC, d.cliente;

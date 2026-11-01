-- Cada linha tem um único motivo principal, conforme a prioridade do ETL.
WITH motivos AS (
  SELECT competencia, motivo_codigo, COUNT(*) AS quantidade
  FROM excluidos GROUP BY competencia, motivo_codigo
), acumulado AS (
  SELECT *,
    SUM(quantidade) OVER (PARTITION BY competencia) AS total_excluidos,
    SUM(quantidade) OVER (
      PARTITION BY competencia
      ORDER BY quantidade DESC, motivo_codigo
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS quantidade_acumulada
  FROM motivos
)
SELECT competencia, motivo_codigo, quantidade,
  ROUND(100.0 * quantidade / NULLIF(total_excluidos, 0), 4) AS participacao_pct,
  ROUND(100.0 * quantidade_acumulada / NULLIF(total_excluidos, 0), 4) AS acumulado_pct
FROM acumulado ORDER BY competencia, quantidade DESC, motivo_codigo;

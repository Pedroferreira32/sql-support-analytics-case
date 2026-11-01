-- A variação só é calculada quando existe o mês calendário imediatamente anterior.
-- Primeira observação ou lacuna permanece NULL, em vez de virar zero artificial.
WITH mensal AS (
  SELECT c.competencia, COUNT(v.linha_origem) AS atendimentos,
    AVG(v.tma_minutos) AS tma_medio_min,
    AVG(v.avaliacao) AS avaliacao_media,
    100.0 * COUNT(v.avaliacao) / NULLIF(COUNT(v.linha_origem), 0) AS cobertura_avaliacao_pct
  FROM competencias c LEFT JOIN validos v ON v.competencia = c.competencia
  GROUP BY c.competencia
), historico AS (
  SELECT *,
    LAG(competencia) OVER (ORDER BY competencia) AS competencia_anterior,
    LAG(atendimentos) OVER (ORDER BY competencia) AS atendimentos_anterior
  FROM mensal
)
SELECT competencia, atendimentos, competencia_anterior, atendimentos_anterior,
  CASE
    WHEN DATE(competencia_anterior || '-01') = DATE(competencia || '-01', '-1 month')
    THEN ROUND(100.0 * (atendimentos - atendimentos_anterior) / NULLIF(atendimentos_anterior, 0), 4)
    ELSE NULL
  END AS variacao_mensal_pct,
  ROUND(tma_medio_min, 4) AS tma_medio_min,
  ROUND(avaliacao_media, 4) AS avaliacao_media,
  ROUND(cobertura_avaliacao_pct, 4) AS cobertura_avaliacao_pct
FROM historico ORDER BY competencia;

-- Recalcula indicadores na base de atendimentos; a nota é a já calculada no ETL.
WITH indicadores AS (
  SELECT competencia, atendente, COUNT(*) AS atendimentos,
    COUNT(avaliacao) AS avaliacoes,
    SUM(duracao_horas) AS horas_total,
    AVG(tma_minutos) AS tma_medio_min,
    AVG(avaliacao) AS avaliacao_media,
    100.0 * COUNT(avaliacao) / NULLIF(COUNT(*), 0) AS cobertura_avaliacao_pct
  FROM validos GROUP BY competencia, atendente
), classificados AS (
  SELECT *, DENSE_RANK() OVER (
    PARTITION BY competencia ORDER BY atendimentos DESC
  ) AS posicao_volume
  FROM indicadores
)
SELECT i.competencia, i.atendente, i.atendimentos, i.avaliacoes,
  ROUND(i.horas_total, 4) AS horas_total,
  ROUND(i.tma_medio_min, 4) AS tma_medio_min,
  ROUND(i.avaliacao_media, 4) AS avaliacao_media,
  ROUND(i.cobertura_avaliacao_pct, 4) AS cobertura_avaliacao_pct,
  i.posicao_volume, r.posicao AS posicao_premiacao_etl,
  ROUND(r.nota_final, 4) AS nota_final_etl
FROM classificados i
LEFT JOIN ranking r
  ON r.competencia = i.competencia AND r.atendente = i.atendente
ORDER BY i.competencia, i.posicao_volume, i.atendente;

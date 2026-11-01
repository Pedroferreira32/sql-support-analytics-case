-- Contraprova: indicadores recalculados em SQL versus resultado persistido pelo pandas.
-- UNION ALL cobre também atendentes que só aparecessem em um dos lados.
WITH calculado AS (
  SELECT competencia, atendente, COUNT(*) AS atendimentos,
    COUNT(avaliacao) AS avaliacoes,
    SUM(duracao_horas) AS horas_total,
    AVG(tma_minutos) AS tma_medio_min,
    AVG(avaliacao) AS avaliacao_media,
    100.0 * COUNT(avaliacao) / NULLIF(COUNT(*), 0) AS cobertura_avaliacao
  FROM validos GROUP BY competencia, atendente
), comparacoes AS (
  SELECT s.competencia, s.atendente,
    CASE WHEN r.atendente IS NOT NULL
      AND s.atendimentos = r.atendimentos AND s.avaliacoes = r.avaliacoes
      AND ABS(s.horas_total - r.horas_total) <= 1e-10
      AND ABS(s.tma_medio_min - r.tma_medio_min) <= 1e-10
      AND (s.avaliacao_media IS r.avaliacao_media OR ABS(s.avaliacao_media - r.avaliacao_media) <= 1e-10)
      AND ABS(s.cobertura_avaliacao - r.cobertura_avaliacao) <= 1e-10
    THEN 1 ELSE 0 END AS aprovado
  FROM calculado s LEFT JOIN ranking r
    ON r.competencia = s.competencia AND r.atendente = s.atendente
  UNION ALL
  SELECT r.competencia, r.atendente, 0 AS aprovado
  FROM ranking r LEFT JOIN calculado s
    ON s.competencia = r.competencia AND s.atendente = r.atendente
  WHERE s.atendente IS NULL
)
SELECT * FROM comparacoes ORDER BY competencia, atendente;

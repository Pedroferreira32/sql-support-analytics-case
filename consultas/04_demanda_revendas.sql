-- O denominador é o total de válidos, preservando a categoria sem revenda.
WITH canais AS (
  SELECT competencia,
    COALESCE(NULLIF(TRIM(revenda), ''), 'Sem revenda identificada') AS revenda,
    COUNT(*) AS atendimentos,
    COUNT(DISTINCT NULLIF(cliente, '')) AS clientes_distintos,
    COUNT(avaliacao) AS avaliacoes,
    AVG(avaliacao) AS avaliacao_media
  FROM validos
  GROUP BY competencia, COALESCE(NULLIF(TRIM(revenda), ''), 'Sem revenda identificada')
)
SELECT competencia, revenda, atendimentos, clientes_distintos, avaliacoes,
  ROUND(avaliacao_media, 4) AS avaliacao_media,
  ROUND(100.0 * avaliacoes / NULLIF(atendimentos, 0), 4) AS cobertura_avaliacao_pct,
  ROUND(100.0 * atendimentos / NULLIF(SUM(atendimentos) OVER (
    PARTITION BY competencia
  ), 0), 4) AS participacao_validos_pct
FROM canais
ORDER BY competencia, atendimentos DESC, revenda;

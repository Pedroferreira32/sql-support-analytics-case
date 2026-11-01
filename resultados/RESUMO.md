# Resultado do estudo SQL

Dados exclusivamente sintéticos.

| Competência | Entrada | Válidos | Excluídos | Cobertura |
|---|---:|---:|---:|---:|
| 2026-08 | 18 | 10 | 8 | 90.00% |
| 2026-09 | 22 | 14 | 8 | 92.86% |
| 2026-10 | 20 | 12 | 8 | 91.67% |

Controles aprovados: três reconciliações, nove comparações de indicadores SQL/pandas, detecção de total inconsistente e tratamento de lacuna entre meses.

As consultas usam o resultado do ETL como origem. O cálculo analítico desta etapa é executado nos arquivos SQL; o Python cria o banco, chama o SQLite e exporta as linhas retornadas.

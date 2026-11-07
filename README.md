# SQL Support Analytics

**[English](README.md)** | [Português (Brasil)](README.pt-BR.md) | [Español](README.es.md) | [Italiano](README.it.md)

Reproducible SQL and SQLite case study in data analysis and data quality, derived from the Support Performance project.

I started with an existing SQL control that reconciled ETL loading and added queries to answer questions about demand, ratings, monthly changes, and exclusions. Analytical calculations live in the SQL files; a small Python runner uses only the standard library to create the database and export results.

## Business problem

A support operation needs to know which records contribute to its indicators, how volume changes, which customers return, and how much of the dataset has received a rating. This case's queries let readers inspect those questions and the consistency of the data supporting the answers.

## How to run

Requirement: Python 3.12 or later. No pandas, database server, or other dependencies are required.

~~~bash
git clone https://github.com/Pedroferreira32/sql-support-analytics-case.git
cd sql-support-analytics-case
python executar.py
~~~

The command creates an in-memory database, runs all queries, validates results, and writes CSVs and a summary to `resultados`. It can be repeated with the same command.

To also create a new SQLite file that can be opened in a database client:

~~~bash
python executar.py --database .gerado/suporte_demo.sqlite
~~~

The runner refuses to overwrite an existing database file. Choose another path for a subsequent persistent run. Queries can also be opened directly in a SQLite-compatible client after running `dados/criar_banco.sql` against an empty database.

## Queries and demonstrated skills

| Question or control | File | SQL features |
|---|---|---|
| Did loading reconcile without losing or duplicating records? | [00_reconciliacao_original.sql](consultas/00_reconciliacao_original.sql) | CTEs, UNION ALL, LEFT JOIN, subqueries, and HAVING |
| What is the overview for each month? | [01_visao_geral.sql](consultas/01_visao_geral.sql) | Aggregations before JOINs, COALESCE, and NULLIF |
| How are indicators distributed across agents? | [02_indicadores_atendentes.sql](consultas/02_indicadores_atendentes.sql) | GROUP BY, AVG, COUNT, month-aware JOIN, and DENSE_RANK |
| Which customers made more than one contact in a month? | [03_clientes_recorrentes.sql](consultas/03_clientes_recorrentes.sql) | CTEs, DISTINCT, JOIN, and share of total |
| How is demand distributed across resellers? | [04_demanda_revendas.sql](consultas/04_demanda_revendas.sql) | Grouping, coverage, and SUM OVER PARTITION BY |
| How did volume change from the previous month? | [05_evolucao_mensal.sql](consultas/05_evolucao_mensal.sql) | LAG, CASE, and gap handling |
| Which reasons account for most exclusions? | [06_pareto_exclusoes.sql](consultas/06_pareto_exclusoes.sql) | Cumulative window with ROWS and percentages |
| Do SQL indicators match the pandas result? | [07_validacao_indicadores.sql](consultas/07_validacao_indicadores.sql) | Independent aggregation checks, JOINs, and numeric tolerance |
| Which file and execution produced the counts? | [08_rastreabilidade.sql](consultas/08_rastreabilidade.sql) | JOINs across reporting months, runs, and stages |

## Data provenance

The sample is entirely fictional. The database was produced by the pinned version of the [Python/pandas ETL](https://github.com/Pedroferreira32/pandas-support-analytics-case/tree/7d864578c3a30ecf36078e64613d69e0728f2d93). The reconciliation SQL was copied in full from that version; the following eight queries were created for this study.

August retains the 18 records from the original sample. To exercise monthly comparisons, I created September and October by shifting dates by four and eight weeks and adding fictional tickets with new identifiers. The shifting rule preserves weekdays. These months are educational scenarios, not real operational history.

| Fictional reporting month | Input | Valid | Excluded |
|---|---:|---:|---:|
| August 2026 | 18 | 10 | 8 |
| September 2026 | 22 | 14 | 8 |
| October 2026 | 20 | 12 | 8 |
| Total | 60 | 36 | 24 |

Source CSVs are in `origens`. The [manifest](dados/manifesto_origem.json) identifies the ETL version, hashes, generation rule, and per-table counts. The [database creation SQL](dados/criar_banco.sql) makes execution independent of installing the original project.

## Model and grain

Table names remain as implemented in the database.

| Table | Grain |
|---|---|
| `validos` | One row per reporting month and source record; ticket identifier unique within the month |
| `excluidos` | One row per reporting month and source record, with the primary reason |
| `ranking` | One row per reporting month and agent, produced by the source ETL |
| `competencias` | One row per month, with the active execution and input total |
| `execucoes` | One row per committed load identifier |
| `etapas` | One row per execution stage |

The overview aggregates valid and excluded records separately before JOINs. Joining two interaction tables directly by month would multiply rows and distort counts. The ranking JOIN uses month and agent, respecting its key.

## Results and validation

All queries run in SQLite. Verification checks three monthly reconciliations and nine agent/month indicator comparisons between SQL and the values persisted by the pandas ETL.

I also ran two controlled scenarios inside savepoints: changing the input total, which must fail reconciliation, and removing the intermediate month, which must leave the next monthly variation absent. Both changes are rolled back afterward.

See the [execution summary](resultados/RESUMO.md) and [verification record](resultados/VALIDACAO.json). The workflow repeats execution on Linux and Windows; each run's status is available in the repository's Actions tab.

## Interpreting the sample

- In the synthetic sample, valid volume changes from 10 to 14 and then to 12. Calculated changes are +40% and approximately -14.29%; the first month has no prior comparison.
- More than one contact from a customer demonstrates recurrence. The dataset does not establish rework or lack of resolution.
- Rating coverage is the number of valid ratings divided by valid interactions. It is not the proportion of satisfied customers.
- The volume rank is calculated in SQL. The award rank and score in the agent query come from the ETL ranking and are explicitly identified as such.
- AHT (TMA) measures the duration between record start and end times; it does not establish active working time.

## Scope

This is a local SQL case study using small synthetic datasets. It demonstrates queries, grain, integrity, and reproducibility. It does not establish experience with BigQuery, SQL Server, or production database operations. No performance or productivity gains were measured.

It complements the [ETL case](https://github.com/Pedroferreira32/pandas-support-analytics-case) and the [Support Performance application](https://github.com/Pedroferreira32/support-performance-analytics), with documented provenance.

## Syntax references

- [SQLite CTEs](https://www.sqlite.org/lang_with.html)
- [SQLite window functions](https://www.sqlite.org/windowfunctions.html)

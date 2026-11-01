# SQL Support Analytics

Estudo reproduzível de análise e qualidade de dados com SQL e SQLite, derivado do projeto Performance do Suporte.

Parti de um controle SQL que já reconciliava a carga do ETL e acrescentei consultas para responder perguntas sobre demanda, avaliações, evolução mensal e exclusões. Os cálculos analíticos estão nos arquivos SQL; um pequeno executor Python usa somente a biblioteca padrão para criar o banco e exportar os resultados.

## O problema de negócio

Uma operação de suporte precisa saber quais registros entram nos indicadores, como o volume varia, quais clientes retornam e quanto da base recebeu avaliação. As consultas deste case permitem conferir essas perguntas e a consistência dos dados usados nas respostas.

## Como executar

Requisito: Python 3.12 ou superior. Não é necessário instalar pandas, um servidor de banco ou outras dependências.

```bash
git clone https://github.com/Pedroferreira32/sql-support-analytics-case.git
cd sql-support-analytics-case
python executar.py
```

O comando cria o banco em memória, executa todas as consultas, valida os resultados e grava os CSVs e o resumo na pasta resultados. Pode ser repetido com o mesmo comando.

Para criar também um arquivo SQLite novo que possa ser aberto em um cliente de banco:

```bash
python executar.py --database .gerado/suporte_demo.sqlite
```

O executor recusa sobrescrever um arquivo de banco existente. Em uma nova execução com persistência, escolha outro caminho. As consultas também podem ser abertas diretamente em um cliente compatível com SQLite, após executar dados/criar_banco.sql em um banco vazio.

## Consultas e competências demonstradas

| Pergunta ou controle | Arquivo | Recursos SQL |
|---|---|---|
| A carga fechou sem perder ou duplicar registros? | [00_reconciliacao_original.sql](consultas/00_reconciliacao_original.sql) | CTEs, UNION ALL, LEFT JOIN, subconsultas e HAVING |
| Qual é a visão geral de cada mês? | [01_visao_geral.sql](consultas/01_visao_geral.sql) | Agregações antes dos JOINs, COALESCE e NULLIF |
| Como os indicadores se distribuem entre atendentes? | [02_indicadores_atendentes.sql](consultas/02_indicadores_atendentes.sql) | GROUP BY, AVG, COUNT, JOIN por competência e DENSE_RANK |
| Quais clientes fizeram mais de um contato no mês? | [03_clientes_recorrentes.sql](consultas/03_clientes_recorrentes.sql) | CTEs, DISTINCT, JOIN e participação no total |
| Como a demanda se distribui entre revendas? | [04_demanda_revendas.sql](consultas/04_demanda_revendas.sql) | Agrupamento, cobertura e SUM OVER PARTITION BY |
| Como o volume mudou em relação ao mês anterior? | [05_evolucao_mensal.sql](consultas/05_evolucao_mensal.sql) | LAG, CASE e tratamento de lacunas |
| Quais motivos concentram as exclusões? | [06_pareto_exclusoes.sql](consultas/06_pareto_exclusoes.sql) | Janela acumulada com ROWS e percentuais |
| Os indicadores SQL conferem com o resultado pandas? | [07_validacao_indicadores.sql](consultas/07_validacao_indicadores.sql) | Contraprova por agregação, JOINs e tolerância numérica |
| Qual arquivo e execução deram origem às contagens? | [08_rastreabilidade.sql](consultas/08_rastreabilidade.sql) | JOIN entre competências, execuções e etapas |

## Origem dos dados

A amostra é inteiramente fictícia. O banco foi produzido pela versão fixada do [ETL Python/pandas](https://github.com/Pedroferreira32/pandas-support-analytics-case/tree/7d864578c3a30ecf36078e64613d69e0728f2d93). O SQL de reconciliação foi copiado integralmente dessa versão; as oito consultas seguintes foram criadas para este estudo.

Agosto conserva os 18 registros da amostra original. Para exercitar a comparação entre meses, criei setembro e outubro deslocando as datas em quatro e oito semanas e acrescentando tickets fictícios com novos protocolos. A regra de deslocamento preserva os dias da semana. Esses meses são cenários didáticos, não histórico operacional real.

| Competência fictícia | Entrada | Válidos | Excluídos |
|---|---:|---:|---:|
| Agosto/2026 | 18 | 10 | 8 |
| Setembro/2026 | 22 | 14 | 8 |
| Outubro/2026 | 20 | 12 | 8 |
| Total | 60 | 36 | 24 |

Os CSVs de origem estão em origens. O [manifesto](dados/manifesto_origem.json) identifica a versão do ETL, os hashes, a regra de geração e as contagens por tabela. O [SQL de criação do banco](dados/criar_banco.sql) torna a execução independente da instalação do projeto original.

## Modelo e grão

| Tabela | Grão |
|---|---|
| validos | Uma linha por competência e registro de origem; protocolo único no mês |
| excluidos | Uma linha por competência e registro de origem, com motivo principal |
| ranking | Uma linha por competência e atendente, produzida pelo ETL de origem |
| competencias | Uma linha por mês, com execução ativa e total de entrada |
| execucoes | Uma linha por identificador da carga confirmada |
| etapas | Uma linha por etapa da execução |

A visão geral agrega válidos e excluídos separadamente antes dos JOINs. Juntar diretamente duas tabelas de atendimentos pelo mês multiplicaria linhas e alteraria as contagens. Já o JOIN com o ranking usa competência e atendente, respeitando sua chave.

## Resultado e validação

Todas as consultas são executadas pelo SQLite. A verificação confere três reconciliações mensais e nove comparações de indicadores por atendente/mês entre SQL e os valores persistidos pelo ETL pandas.

Também executei dois cenários controlados dentro de savepoints: uma alteração no total de entrada, que deve reprovar a reconciliação, e a retirada do mês intermediário, que deve deixar a variação mensal seguinte ausente. Ao final, ambos são desfeitos.

Consulte o [resumo da execução](resultados/RESUMO.md) e o [registro das verificações](resultados/VALIDACAO.json). O workflow repete a execução em Linux e Windows; o estado de cada run pode ser consultado na aba Actions do repositório.

## Interpretação da amostra

- Na amostra sintética, o volume válido varia de 10 para 14 e depois para 12. As variações calculadas são +40% e aproximadamente -14,29%; o primeiro mês não possui comparação anterior.
- Mais de um contato do mesmo cliente demonstra recorrência. A base não permite concluir que houve retrabalho ou falta de resolução.
- Cobertura de avaliação é a quantidade de avaliações válidas dividida pelos atendimentos válidos. Não é a proporção de clientes satisfeitos.
- A posição por volume é calculada em SQL. A posição e a nota de premiação exibidas na consulta de atendentes vêm do ranking do ETL e são identificadas como tal.
- TMA mede a duração entre início e fim dos registros; não comprova tempo ativo de trabalho.

## Escopo

Este é um case local de SQL com dados sintéticos pequenos. Ele evidencia consultas, grão, integridade e reprodução. Não comprova experiência em BigQuery, SQL Server ou operação de banco em produção. Não foram medidos ganhos de desempenho ou produtividade.

É uma entrega complementar ao [case ETL](https://github.com/Pedroferreira32/pandas-support-analytics-case) e à [aplicação Performance do Suporte](https://github.com/Pedroferreira32/support-performance-analytics), com vínculo de origem documentado.

## Referências de sintaxe

- [CTEs no SQLite](https://www.sqlite.org/lang_with.html)
- [Funções de janela no SQLite](https://www.sqlite.org/windowfunctions.html)

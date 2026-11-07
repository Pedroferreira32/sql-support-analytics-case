# SQL Support Analytics

[English](README.md) | [Português (Brasil)](README.pt-BR.md) | **[Español](README.es.md)** | [Italiano](README.it.md)

Estudio reproducible de análisis y calidad de datos con SQL y SQLite, derivado del proyecto de Rendimiento del Soporte.

Partí de un control SQL que ya conciliaba la carga del ETL y añadí consultas para responder preguntas sobre demanda, valoraciones, evolución mensual y exclusiones. Los cálculos analíticos están en los archivos SQL; un pequeño ejecutor Python utiliza únicamente la biblioteca estándar para crear la base y exportar los resultados.

## Problema de negocio

Una operación de soporte necesita saber qué registros participan en los indicadores, cómo varía el volumen, qué clientes vuelven y qué parte de los datos recibió valoración. Las consultas permiten revisar esas preguntas y la consistencia de los datos que sustentan las respuestas.

## Cómo ejecutar

Requisito: Python 3.12 o superior. No se necesita instalar pandas, un servidor de base de datos ni otras dependencias.

~~~bash
git clone https://github.com/Pedroferreira32/sql-support-analytics-case.git
cd sql-support-analytics-case
python executar.py
~~~

El comando crea la base en memoria, ejecuta todas las consultas, valida los resultados y guarda los CSVs y el resumen en `resultados`. Puede repetirse con el mismo comando.

Para crear también un archivo SQLite nuevo que se pueda abrir en un cliente de base de datos:

~~~bash
python executar.py --database .gerado/suporte_demo.sqlite
~~~

El ejecutor rechaza sobrescribir una base existente. En una nueva ejecución persistente, elija otra ruta. También puede abrir las consultas directamente en un cliente compatible con SQLite después de ejecutar `dados/criar_banco.sql` en una base vacía.

## Consultas y competencias demostradas

| Pregunta o control | Archivo | Recursos SQL |
|---|---|---|
| ¿La carga concilia sin perder ni duplicar registros? | [00_reconciliacao_original.sql](consultas/00_reconciliacao_original.sql) | CTEs, UNION ALL, LEFT JOIN, subconsultas y HAVING |
| ¿Cuál es la visión general de cada mes? | [01_visao_geral.sql](consultas/01_visao_geral.sql) | Agregaciones antes de los JOINs, COALESCE y NULLIF |
| ¿Cómo se distribuyen los indicadores entre agentes? | [02_indicadores_atendentes.sql](consultas/02_indicadores_atendentes.sql) | GROUP BY, AVG, COUNT, JOIN por mes y DENSE_RANK |
| ¿Qué clientes hicieron más de un contacto en el mes? | [03_clientes_recorrentes.sql](consultas/03_clientes_recorrentes.sql) | CTEs, DISTINCT, JOIN y participación en el total |
| ¿Cómo se distribuye la demanda entre distribuidores? | [04_demanda_revendas.sql](consultas/04_demanda_revendas.sql) | Agrupación, cobertura y SUM OVER PARTITION BY |
| ¿Cómo cambió el volumen respecto al mes anterior? | [05_evolucao_mensal.sql](consultas/05_evolucao_mensal.sql) | LAG, CASE y tratamiento de meses ausentes |
| ¿Qué motivos concentran las exclusiones? | [06_pareto_exclusoes.sql](consultas/06_pareto_exclusoes.sql) | Ventana acumulada con ROWS y porcentajes |
| ¿Los indicadores SQL coinciden con pandas? | [07_validacao_indicadores.sql](consultas/07_validacao_indicadores.sql) | Comprobación independiente por agregación, JOINs y tolerancia numérica |
| ¿Qué archivo y ejecución originaron los conteos? | [08_rastreabilidade.sql](consultas/08_rastreabilidade.sql) | JOIN entre meses, ejecuciones y etapas |

## Origen de los datos

La muestra es completamente ficticia. La base se produjo mediante la versión fijada del [ETL Python/pandas](https://github.com/Pedroferreira32/pandas-support-analytics-case/tree/7d864578c3a30ecf36078e64613d69e0728f2d93). El SQL de conciliación se copió íntegramente de esa versión; las ocho consultas siguientes se crearon para este estudio.

Agosto conserva los 18 registros de la muestra original. Para ejercitar la comparación mensual, creé septiembre y octubre desplazando las fechas cuatro y ocho semanas y añadiendo tickets ficticios con identificadores nuevos. La regla de desplazamiento conserva los días de la semana. Son escenarios didácticos, no un historial operativo real.

| Mes de referencia ficticio | Entrada | Válidos | Excluidos |
|---|---:|---:|---:|
| Agosto/2026 | 18 | 10 | 8 |
| Septiembre/2026 | 22 | 14 | 8 |
| Octubre/2026 | 20 | 12 | 8 |
| Total | 60 | 36 | 24 |

Los CSVs de origen están en `origens`. El [manifiesto](dados/manifesto_origem.json) identifica la versión del ETL, los hashes, la regla de generación y los conteos por tabla. El [SQL de creación](dados/criar_banco.sql) permite ejecutar el estudio sin instalar el proyecto original.

## Modelo y granularidad

Los nombres de las tablas se conservan tal como están implementados.

| Tabla | Granularidad |
|---|---|
| `validos` | Una fila por mes y registro de origen; identificador de ticket único en el mes |
| `excluidos` | Una fila por mes y registro de origen, con motivo principal |
| `ranking` | Una fila por mes y agente, producida por el ETL de origen |
| `competencias` | Una fila por mes, con ejecución activa y total de entrada |
| `execucoes` | Una fila por identificador de carga confirmada |
| `etapas` | Una fila por etapa de ejecución |

La visión general agrega válidos y excluidos por separado antes de los JOINs. Unir directamente dos tablas de interacciones por mes multiplicaría filas y alteraría los conteos. El JOIN con la clasificación utiliza mes y agente, respetando su clave.

## Resultados y validación

Todas las consultas se ejecutan en SQLite. La verificación comprueba tres conciliaciones mensuales y nueve comparaciones de indicadores por agente/mes entre SQL y los valores guardados por el ETL pandas.

También ejecuté dos escenarios controlados dentro de savepoints: un cambio en el total de entrada que debe reprobar la conciliación y la retirada del mes intermedio, que debe dejar ausente la siguiente variación mensual. Ambos cambios se deshacen al finalizar.

Consulte el [resumen de ejecución](resultados/RESUMO.md) y el [registro de verificaciones](resultados/VALIDACAO.json). El workflow repite la ejecución en Linux y Windows; el estado de cada run está en la pestaña Actions del repositorio.

## Interpretación de la muestra

- En la muestra sintética, el volumen válido pasa de 10 a 14 y después a 12. Las variaciones son +40% y aproximadamente -14,29%; el primer mes no tiene comparación anterior.
- Más de un contacto del mismo cliente demuestra recurrencia. Los datos no permiten concluir que hubo retrabajo o falta de resolución.
- La cobertura de valoración es la cantidad de valoraciones válidas dividida por las interacciones válidas. No es la proporción de clientes satisfechos.
- La posición por volumen se calcula en SQL. La posición y puntuación de premios de la consulta de agentes provienen del ranking del ETL y se identifican como tales.
- El TMA mide la duración entre inicio y fin del registro; no demuestra tiempo activo de trabajo.

## Alcance

Es un estudio SQL local con datos sintéticos pequeños. Demuestra consultas, granularidad, integridad y reproducción. No demuestra experiencia con BigQuery, SQL Server ni operación de bases en producción. No se midieron mejoras de rendimiento ni productividad.

Complementa el [caso ETL](https://github.com/Pedroferreira32/pandas-support-analytics-case) y la [aplicación de Rendimiento del Soporte](https://github.com/Pedroferreira32/support-performance-analytics), con origen documentado.

## Referencias de sintaxis

- [CTEs en SQLite](https://www.sqlite.org/lang_with.html)
- [Funciones de ventana en SQLite](https://www.sqlite.org/windowfunctions.html)

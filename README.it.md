# SQL Support Analytics

[English](README.md) | [Português (Brasil)](README.pt-BR.md) | [Español](README.es.md) | **[Italiano](README.it.md)**

Studio riproducibile di analisi e qualità dei dati con SQL e SQLite, derivato dal progetto Performance dell'Assistenza.

Sono partito da un controllo SQL che riconciliava già il caricamento ETL e ho aggiunto query per rispondere a domande su domanda di assistenza, valutazioni, evoluzione mensile ed esclusioni. I calcoli analitici si trovano nei file SQL; un piccolo programma Python utilizza soltanto la libreria standard per creare il database ed esportare i risultati.

## Problema di business

Un servizio di assistenza deve sapere quali record contribuiscono agli indicatori, come varia il volume, quali clienti ritornano e quale parte dei dati ha ricevuto una valutazione. Le query permettono di verificare queste domande e la coerenza dei dati utilizzati per rispondere.

## Come eseguire il progetto

Requisito: Python 3.12 o successivo. Non occorre installare pandas, un server di database o altre dipendenze.

~~~bash
git clone https://github.com/Pedroferreira32/sql-support-analytics-case.git
cd sql-support-analytics-case
python executar.py
~~~

Il comando crea un database in memoria, esegue tutte le query, valida i risultati e salva CSV e riepilogo in `resultados`. Può essere ripetuto con lo stesso comando.

Per creare anche un nuovo file SQLite apribile con un client database:

~~~bash
python executar.py --database .gerado/suporte_demo.sqlite
~~~

Il programma rifiuta di sovrascrivere un database esistente. Per una nuova esecuzione persistente, scegli un percorso diverso. Le query possono anche essere aperte direttamente in un client compatibile con SQLite dopo aver eseguito `dados/criar_banco.sql` su un database vuoto.

## Query e competenze dimostrate

| Domanda o controllo | File | Funzionalità SQL |
|---|---|---|
| Il caricamento è riconciliato senza perdere o duplicare record? | [00_reconciliacao_original.sql](consultas/00_reconciliacao_original.sql) | CTE, UNION ALL, LEFT JOIN, sottoquery e HAVING |
| Qual è la visione d'insieme di ogni mese? | [01_visao_geral.sql](consultas/01_visao_geral.sql) | Aggregazioni prima dei JOIN, COALESCE e NULLIF |
| Come si distribuiscono gli indicatori tra gli operatori? | [02_indicadores_atendentes.sql](consultas/02_indicadores_atendentes.sql) | GROUP BY, AVG, COUNT, JOIN per mese e DENSE_RANK |
| Quali clienti hanno effettuato più di un contatto nel mese? | [03_clientes_recorrentes.sql](consultas/03_clientes_recorrentes.sql) | CTE, DISTINCT, JOIN e quota sul totale |
| Come si distribuisce la domanda tra i rivenditori? | [04_demanda_revendas.sql](consultas/04_demanda_revendas.sql) | Raggruppamento, copertura e SUM OVER PARTITION BY |
| Come è cambiato il volume rispetto al mese precedente? | [05_evolucao_mensal.sql](consultas/05_evolucao_mensal.sql) | LAG, CASE e gestione dei mesi mancanti |
| Quali motivi concentrano le esclusioni? | [06_pareto_exclusoes.sql](consultas/06_pareto_exclusoes.sql) | Finestra cumulativa con ROWS e percentuali |
| Gli indicatori SQL corrispondono al risultato pandas? | [07_validacao_indicadores.sql](consultas/07_validacao_indicadores.sql) | Controverifica tramite aggregazione, JOIN e tolleranza numerica |
| Quali file ed esecuzioni hanno prodotto i conteggi? | [08_rastreabilidade.sql](consultas/08_rastreabilidade.sql) | JOIN tra mesi, esecuzioni e fasi |

## Origine dei dati

Il campione è interamente fittizio. Il database è stato prodotto dalla versione fissata dell'[ETL Python/pandas](https://github.com/Pedroferreira32/pandas-support-analytics-case/tree/7d864578c3a30ecf36078e64613d69e0728f2d93). L'SQL di riconciliazione è stato copiato integralmente da quella versione; le otto query successive sono state create per questo studio.

Agosto mantiene i 18 record del campione originale. Per esercitare il confronto mensile, ho creato settembre e ottobre spostando le date di quattro e otto settimane e aggiungendo ticket fittizi con nuovi identificativi. Lo spostamento conserva i giorni della settimana. Si tratta di scenari didattici, non di uno storico operativo reale.

| Mese di riferimento fittizio | Input | Validi | Esclusi |
|---|---:|---:|---:|
| Agosto/2026 | 18 | 10 | 8 |
| Settembre/2026 | 22 | 14 | 8 |
| Ottobre/2026 | 20 | 12 | 8 |
| Totale | 60 | 36 | 24 |

I CSV di origine sono in `origens`. Il [manifesto](dados/manifesto_origem.json) identifica versione dell'ETL, hash, regola di generazione e conteggi per tabella. L'[SQL di creazione](dados/criar_banco.sql) rende l'esecuzione indipendente dall'installazione del progetto originale.

## Modello e granularità

I nomi delle tabelle rimangono quelli implementati nel database.

| Tabella | Granularità |
|---|---|
| `validos` | Una riga per mese e record di origine; identificativo del ticket univoco nel mese |
| `excluidos` | Una riga per mese e record di origine, con motivo principale |
| `ranking` | Una riga per mese e operatore, prodotta dall'ETL di origine |
| `competencias` | Una riga per mese, con esecuzione attiva e totale di input |
| `execucoes` | Una riga per identificativo del caricamento confermato |
| `etapas` | Una riga per fase dell'esecuzione |

La visione d'insieme aggrega validi ed esclusi separatamente prima dei JOIN. Unire direttamente due tabelle di interazioni per mese moltiplicherebbe le righe e altererebbe i conteggi. Il JOIN con la classifica utilizza mese e operatore, rispettandone la chiave.

## Risultati e validazione

Tutte le query sono eseguite da SQLite. La verifica controlla tre riconciliazioni mensili e nove confronti di indicatori per operatore/mese tra SQL e i valori salvati dall'ETL pandas.

Ho anche eseguito due scenari controllati all'interno di savepoint: una modifica del totale di input, che deve far fallire la riconciliazione, e la rimozione del mese intermedio, che deve lasciare assente la successiva variazione mensile. Entrambe le modifiche vengono poi annullate.

Consulta il [riepilogo dell'esecuzione](resultados/RESUMO.md) e il [registro delle verifiche](resultados/VALIDACAO.json). Il workflow ripete l'esecuzione su Linux e Windows; lo stato di ogni run è disponibile nella scheda Actions del repository.

## Interpretazione del campione

- Nel campione sintetico il volume valido passa da 10 a 14 e poi a 12. Le variazioni sono +40% e circa -14,29%; il primo mese non ha un confronto precedente.
- Più contatti dello stesso cliente dimostrano ricorrenza. I dati non permettono di concludere che vi siano rilavorazioni o mancata risoluzione.
- La copertura delle valutazioni è il numero di valutazioni valide diviso per le interazioni valide. Non è la proporzione di clienti soddisfatti.
- La posizione per volume è calcolata in SQL. La posizione e il punteggio di premiazione nella query degli operatori provengono dalla classifica ETL e sono identificati come tali.
- Il TMA misura la durata tra inizio e fine del record; non dimostra tempo di lavoro attivo.

## Perimetro

È uno studio SQL locale con piccoli dati sintetici. Dimostra query, granularità, integrità e riproducibilità. Non dimostra esperienza con BigQuery, SQL Server o gestione di database in produzione. Non sono stati misurati miglioramenti di prestazioni o produttività.

Completa il [caso ETL](https://github.com/Pedroferreira32/pandas-support-analytics-case) e l'[applicazione Performance dell'Assistenza](https://github.com/Pedroferreira32/support-performance-analytics), con origine documentata.

## Riferimenti di sintassi

- [CTE in SQLite](https://www.sqlite.org/lang_with.html)
- [Funzioni finestra in SQLite](https://www.sqlite.org/windowfunctions.html)

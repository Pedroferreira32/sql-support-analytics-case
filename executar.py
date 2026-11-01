"""Executa o estudo SQL em SQLite usando somente a biblioteca padrão do Python."""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
from pathlib import Path
import platform
import sqlite3
import sys

ROOT = Path(__file__).resolve().parent


def query(connection: sqlite3.Connection, path: Path, parameters: dict | None = None) -> list[dict]:
    return [dict(row) for row in connection.execute(path.read_text(encoding='utf-8'), parameters or {})]


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def verify(connection: sqlite3.Connection, results: dict[str, list[dict]]) -> dict:
    manifest = json.loads((ROOT / 'dados/manifesto_origem.json').read_text())
    require(not connection.execute('PRAGMA foreign_key_check').fetchall(), 'Chave estrangeira inconsistente.')
    for comp, expected in manifest['competencias'].items():
        report = query(connection, ROOT / 'consultas/00_reconciliacao_original.sql', {'competencia': comp})[0]
        require(report['reconciliado'] == 1, f'Reconciliação reprovada: {comp}')
        require(report['total_extraido'] == expected['total_extraido'], f'Total divergente: {comp}')
        require(report['validos'] == expected['validos'] and report['excluidos'] == expected['excluidos'], f'Classificação divergente: {comp}')
    monthly = results['05_evolucao_mensal']
    require([r['atendimentos'] for r in monthly] == [10, 14, 12], 'Volumes mensais inesperados.')
    require(monthly[0]['variacao_mensal_pct'] is None, 'Primeiro mês deve permanecer sem comparação.')
    require(math.isclose(monthly[1]['variacao_mensal_pct'], 40.0, abs_tol=1e-4), 'Variação de setembro incorreta.')
    require(math.isclose(monthly[2]['variacao_mensal_pct'], -14.2857, abs_tol=1e-4), 'Variação de outubro incorreta.')
    require(len(results['07_validacao_indicadores']) == 9, 'São esperados três atendentes em três meses.')
    require(all(r['aprovado'] == 1 for r in results['07_validacao_indicadores']), 'SQL e resultado pandas divergiram.')
    require(all(r['reconciliado'] == 1 for r in results['01_visao_geral']), 'A visão geral multiplicou ou perdeu registros.')
    observed = results['03_clientes_recorrentes']
    require(any(r['competencia'] == '2026-08' and r['cliente'] == 'Cliente Fictício 01' and r['atendimentos'] == 2 for r in observed), 'Recorrência da amostra não preservada.')

    # Evidência de que o controle detecta inconsistência, além do caminho bem-sucedido.
    connection.execute('SAVEPOINT erro_controlado')
    try:
        connection.execute("UPDATE competencias SET total_extraido = total_extraido + 1 WHERE competencia = '2026-08'")
        corrupt = query(connection, ROOT / 'consultas/00_reconciliacao_original.sql', {'competencia': '2026-08'})[0]
        require(corrupt['reconciliado'] == 0, 'A reconciliação não detectou o total adulterado.')
    finally:
        connection.execute('ROLLBACK TO erro_controlado')
        connection.execute('RELEASE erro_controlado')

    connection.execute('SAVEPOINT mes_ausente')
    try:
        for table in ['validos', 'excluidos', 'ranking', 'competencias']:
            connection.execute(f"DELETE FROM {table} WHERE competencia = ?", ('2026-09',))
        gap = query(connection, ROOT / 'consultas/05_evolucao_mensal.sql')
        require(gap[-1]['variacao_mensal_pct'] is None, 'Não se deve comparar outubro com agosto como variação mensal.')
    finally:
        connection.execute('ROLLBACK TO mes_ausente')
        connection.execute('RELEASE mes_ausente')

    return {
        'estado': 'aprovado', 'python': platform.python_version(), 'sqlite': sqlite3.sqlite_version,
        'competencias': len(manifest['competencias']), 'consultas_analiticas_executadas': len(results),
        'reconciliacoes_originais_aprovadas': 3, 'comparacoes_atendente_mes_aprovadas': 9,
        'falha_controlada_detectada': True, 'mes_ausente_preservou_null': True,
        'dados': 'exclusivamente sintéticos',
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--database', type=Path, help='Caminho de um banco novo; por padrão usa memória.')
    parser.add_argument('--output', type=Path, default=ROOT / 'resultados')
    args = parser.parse_args()
    try:
        seed = ROOT / 'dados/criar_banco.sql'
        manifest = json.loads((ROOT / 'dados/manifesto_origem.json').read_text(encoding='utf-8'))
        require(hashlib.sha256(seed.read_bytes()).hexdigest() == manifest['seed_sha256'], 'O SQL de carga divergiu do snapshot documentado.')
        if args.database:
            args.database.parent.mkdir(parents=True, exist_ok=True)
            if args.database.exists():
                raise FileExistsError('O banco já existe. Use --database com um novo caminho para repetir a demonstração.')
        args.output.mkdir(parents=True, exist_ok=True)
        with sqlite3.connect(args.database if args.database else ':memory:') as connection:
            connection.row_factory = sqlite3.Row
            connection.executescript(seed.read_text(encoding='utf-8'))
            connection.execute('PRAGMA foreign_keys = ON')
            results = {}
            for path in sorted((ROOT / 'consultas').glob('*.sql')):
                if path.name.startswith('00_'):
                    continue
                rows = query(connection, path)
                results[path.stem] = rows
                if rows:
                    with (args.output / f'{path.stem}.csv').open('w', encoding='utf-8-sig', newline='') as stream:
                        writer = csv.DictWriter(stream, fieldnames=list(rows[0]), delimiter=';', lineterminator='\n')
                        writer.writeheader(); writer.writerows(rows)
                print(f'{path.name}: {len(rows)} linha(s)')
            report = verify(connection, results)
            args.output.joinpath('VALIDACAO.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
            monthly = results['01_visao_geral']
            lines = ['# Resultado do estudo SQL', '', 'Dados exclusivamente sintéticos.', '',
                '| Competência | Entrada | Válidos | Excluídos | Cobertura |', '|---|---:|---:|---:|---:|']
            lines.extend(f"| {r['competencia']} | {r['total_extraido']} | {r['atendimentos_validos']} | {r['atendimentos_excluidos']} | {r['cobertura_avaliacao_pct']:.2f}% |" for r in monthly)
            lines += ['', 'Controles aprovados: três reconciliações, nove comparações de indicadores SQL/pandas, detecção de total inconsistente e tratamento de lacuna entre meses.', '',
                'As consultas usam o resultado do ETL como origem. O cálculo analítico desta etapa é executado nos arquivos SQL; o Python cria o banco, chama o SQLite e exporta as linhas retornadas.', '']
            args.output.joinpath('RESUMO.md').write_text('\n'.join(lines), encoding='utf-8')
        print('Validação SQL: aprovada. Todas as consultas foram executadas no SQLite.')
        return 0
    except (OSError, ValueError, AssertionError, sqlite3.Error) as exc:
        print(f'Falha: {exc}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())

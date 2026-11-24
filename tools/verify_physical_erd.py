"""
verify_physical_erd.py - checks that the physical PlantUML diagrams match the
deployed database exactly.

It parses diagrams/physical/modules/*.puml and diagrams/physical/master_physical.puml
(independently of the generator) and compares them with the catalog of a deployed
database (sys.tables, sys.columns, sys.types, sys.identity_columns,
sys.key_constraints, sys.foreign_keys, sys.check_constraints,
sys.default_constraints, sys.indexes), reporting every mismatch.

Modes
  --catalog "<ODBC connection string>"   compare against a deployed database (preferred)
  --ddl                                   fallback: compare against the parsed sql/ scripts
                                          (used only when no database can be deployed)

Exit code 0 = no mismatches, 1 = mismatches found, 2 = usage / parse error.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from schema_model import load_from_catalog, load_from_ddl, norm_expr  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
PHYS = ROOT / "diagrams" / "physical"

RE_ENTITY = re.compile(r'^entity "([\w.]+)" as (\w+)(.*)\{\s*$')
RE_COLUMN = re.compile(r"^(\* )?(\w+) : (\S+) (NOT NULL|NULL)((?: «[^»]+»)*)$")
RE_EDGE = re.compile(r"^(\w+) (\|\||\|o)--(o\{|o\|) (\w+) : (\w+)$")


def parse_puml(path: Path) -> tuple[dict, list[tuple[str, str, str]]]:
    """Returns ({table: parsed}, [(parent_alias, child_alias, fk_name)])."""
    tables: dict[str, dict] = {}
    edges = []
    current = None
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if current is None:
            if m := RE_ENTITY.match(line):
                name, _, stereo = m.groups()
                if "<<external>>" in stereo:
                    current = {"skip": True}
                else:
                    current = {"skip": False, "name": name, "columns": [], "pk": None, "uqs": {}, "fks": {}, "cks": set(),
                               "dfs": {}, "ixs": {}, "temporal": None, "history_of": None}
            elif m := RE_EDGE.match(line):
                edges.append((m.group(1), m.group(4), m.group(5)))
            continue
        if line == "}":
            if not current["skip"]:
                if current["name"] in tables:
                    raise ValueError(f"{path.name}: table {current['name']} defined twice")
                tables[current["name"]] = current
            current = None
            continue
        if current["skip"] or line == "--":
            continue
        if m := RE_COLUMN.match(line):
            star, cname, ctype, nullity, tags = m.groups()
            tagset = set(re.findall(r"«([^»]+)»", tags))
            if bool(star) != (nullity == "NOT NULL"):
                raise ValueError(f"{path.name}: '*' marker inconsistent with nullability: {line}")
            current["columns"].append({
                "name": cname, "type": ctype, "nullable": nullity == "NULL",
                "identity": next((t for t in tagset if t.startswith("IDENTITY")), None),
                "generated": next((t for t in tagset if t.startswith("ROW ")), None),
                "hidden": "HIDDEN" in tagset, "pk_tag": "PK" in tagset, "fk_tag": "FK" in tagset})
            continue
        kind, _, rest = line.partition(" ")
        if kind == "PK":
            n, cols = re.match(r"(\w+) \(([^)]*)\)$", rest).groups()
            current["pk"] = (n, cols)
        elif kind == "UQ":
            n, cols = re.match(r"(\w+) \(([^)]*)\)$", rest).groups()
            current["uqs"][n] = cols
        elif kind == "FK":
            n, cols, ref, rcols, cascade = re.match(r"(\w+) \(([^)]*)\) -> ([\w.]+) \(([^)]*)\)( ON DELETE CASCADE)?$", rest).groups()
            current["fks"][n] = (cols, ref, rcols, "CASCADE" if cascade else "NO ACTION")
        elif kind == "CK":
            current["cks"].add(rest.split(" : ")[0])
        elif kind == "DF":
            n, col, expr = re.match(r"(\w+) : (\w+) = (.*)$", rest).groups()
            current["dfs"][n] = (col, norm_expr(expr))
        elif kind == "IX":
            m = re.match(r"(\w+) \(([^)]*)\)(?: INCLUDE \(([^)]*)\))?( UNIQUE)?( CLUSTERED)?(?: WHERE (.*))?$", rest)
            n, cols, incl, uniq, clus, flt = m.groups()
            current["ixs"][n] = (cols, incl or "", bool(uniq), bool(clus), norm_expr(flt))
        elif kind == "TEMPORAL":
            current["temporal"] = rest.split("HISTORY_TABLE = ")[1].strip()
        elif kind == "HISTORY":
            current["history_of"] = rest.split()[1]
        else:
            raise ValueError(f"{path.name}: unrecognised line inside entity {current['name']}: {line}")
    return tables, edges


def compare(model: dict, diagram: dict, edges_by_file: dict) -> list[str]:
    errs: list[str] = []
    j = ", ".join

    missing = sorted(set(model) - set(diagram))
    extra = sorted(set(diagram) - set(model))
    errs += [f"[table] {t}: deployed but missing from module diagrams" for t in missing]
    errs += [f"[table] {t}: in diagrams but not deployed" for t in extra]

    for name in sorted(set(model) & set(diagram)):
        t, d = model[name], diagram[name]
        # columns, in order
        mc = [(c.name, c.type, c.nullable, c.identity, c.generated, c.hidden) for c in t.columns]
        dc = [(c["name"], c["type"], c["nullable"], c["identity"], c["generated"], c["hidden"]) for c in d["columns"]]
        if mc != dc:
            for a, b in zip(mc, dc):
                if a != b:
                    errs.append(f"[column] {name}: deployed {a} != diagram {b}")
            if len(mc) != len(dc):
                errs.append(f"[column] {name}: deployed has {len(mc)} columns, diagram {len(dc)}")
        pk_cols = set(t.pk.columns) if t.pk else set()
        fk_cols = {c for fk in t.fks for c in fk.columns}
        for c in d["columns"]:
            if c["pk_tag"] != (c["name"] in pk_cols):
                errs.append(f"[PK tag] {name}.{c['name']}")
            if c["fk_tag"] != (c["name"] in fk_cols):
                errs.append(f"[FK tag] {name}.{c['name']}")
        # keys / constraints
        mpk = (t.pk.name, j(t.pk.columns)) if t.pk else None
        if mpk != d["pk"]:
            errs.append(f"[PK] {name}: deployed {mpk} != diagram {d['pk']}")
        muq = {u.name: j(u.columns) for u in t.uqs}
        if muq != d["uqs"]:
            errs.append(f"[UQ] {name}: deployed {muq} != diagram {d['uqs']}")
        mfk = {f.name: (j(f.columns), f.ref_table, j(f.ref_columns), f.on_delete) for f in t.fks}
        for k in sorted(set(mfk) | set(d["fks"])):
            if mfk.get(k) != d["fks"].get(k):
                errs.append(f"[FK] {name}.{k}: deployed {mfk.get(k)} != diagram {d['fks'].get(k)}")
        mck = {c.name for c in t.cks}
        if mck != d["cks"]:
            errs.append(f"[CK] {name}: only deployed {sorted(mck - d['cks'])}, only diagram {sorted(d['cks'] - mck)}")
        mdf = {x.name: (x.column, norm_expr(x.definition)) for x in t.dfs}
        for k in sorted(set(mdf) | set(d["dfs"])):
            if mdf.get(k) != d["dfs"].get(k):
                errs.append(f"[DF] {name}.{k}: deployed {mdf.get(k)} != diagram {d['dfs'].get(k)}")
        mix = {i.name: (j(i.columns), j(i.includes), i.unique, i.clustered, norm_expr(i.filter)) for i in t.indexes}
        for k in sorted(set(mix) | set(d["ixs"])):
            if mix.get(k) != d["ixs"].get(k):
                errs.append(f"[IX] {name}.{k}: deployed {mix.get(k)} != diagram {d['ixs'].get(k)}")
        if t.temporal_history != d["temporal"]:
            errs.append(f"[temporal] {name}: deployed {t.temporal_history} != diagram {d['temporal']}")
        if t.history_of != d["history_of"]:
            errs.append(f"[history] {name}: deployed {t.history_of} != diagram {d['history_of']}")

    # relationships: every FK drawn as an edge in its child's module diagram and in the master
    for fname, edges in edges_by_file.items():
        drawn = {(p, c, n) for p, c, n in edges}
        for name, d in diagram.items():
            if fname != "master_physical.puml" and d["_file"] != fname:
                continue
            if name not in model:
                continue
            for f in model[name].fks:
                key = (f.ref_table.replace(".", "_"), name.replace(".", "_"), f.name)
                if key not in drawn:
                    errs.append(f"[relationship] {fname}: missing edge for {f.name}")
        known = {f.name for t in model.values() for f in t.fks}
        errs += [f"[relationship] {fname}: edge {n} has no deployed FK" for _, _, n in edges if n not in known]
    return errs


def main() -> int:
    ap = argparse.ArgumentParser()
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--catalog", help="ODBC connection string of the deployed database")
    g.add_argument("--ddl", action="store_true", help="fallback: compare with the parsed sql/ scripts")
    args = ap.parse_args()

    try:
        diagram: dict = {}
        edges_by_file: dict = {}
        module_files = sorted((PHYS / "modules").glob("*.puml"))
        if not module_files:
            print("No physical module diagrams found.")
            return 2
        for f in module_files:
            tables, edges = parse_puml(f)
            for k, v in tables.items():
                if k in diagram:
                    raise ValueError(f"{k} appears as a full entity in more than one module diagram")
                v["_file"] = f.name
                diagram[k] = v
            edges_by_file[f.name] = edges
        master_tables, master_edges = parse_puml(PHYS / "master_physical.puml")
        edges_by_file["master_physical.puml"] = master_edges
    except (ValueError, AttributeError) as e:
        print(f"PARSE ERROR: {e}")
        return 2

    if args.catalog:
        model = load_from_catalog(args.catalog)
        source = "deployed database catalog"
    else:
        model = load_from_ddl()
        source = "sql/ DDL scripts (fallback mode - database not deployed)"

    errs = compare(model, diagram, edges_by_file)
    missing_master = sorted(set(model) - set(master_tables))
    errs += [f"[master] {t}: missing from master_physical.puml" for t in missing_master]

    n_cols = sum(len(t.columns) for t in model.values())
    n_fk = sum(len(t.fks) for t in model.values())
    n_ix = sum(len(t.indexes) for t in model.values())
    n_ck = sum(len(t.cks) for t in model.values())
    n_df = sum(len(t.dfs) for t in model.values())
    n_uq = sum(len(t.uqs) for t in model.values())
    print(f"Compared {len(diagram)} diagram tables in {len(module_files)} module files + master against the {source}:")
    print(f"  {len(model)} tables, {n_cols} columns, {sum(1 for t in model.values() if t.pk)} PKs, {n_uq} UQs, {n_fk} FKs, "
          f"{n_ck} CKs, {n_df} DFs, {n_ix} other indexes")
    if errs:
        print(f"MISMATCHES: {len(errs)}")
        for e in errs:
            print("  " + e)
        return 1
    print("RESULT: PASS - physical diagrams match exactly.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

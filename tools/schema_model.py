"""
schema_model.py - one in-memory model of the physical schema, loadable from
  (a) the T-SQL source scripts in sql/ (03..06)       -> load_from_ddl()
  (b) a deployed database catalog via pyodbc (sys.*) -> load_from_catalog()

Both loaders return the same structure so the diagram generator and the
physical-ERD verifier can compare them field by field.

Model:  {"schema.Table": Table}
Table:  columns, pk, uqs, fks, cks, dfs, indexes, temporal_history, is_history

Never reads .env files; reads only sql/*.sql and the database catalog.
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path

SQL_DIR = Path(__file__).resolve().parent.parent / "sql"

CORE_SCHEMAS = ["organization", "iam", "people", "academic", "enrollment", "timetable",
                 "attendance", "assessment", "finance", "audit"]


# --------------------------------------------------------------------------- model
@dataclass
class Column:
    name: str
    type: str                 # normalised, e.g. NVARCHAR(100), DECIMAL(19,4), ROWVERSION
    nullable: bool
    identity: str | None = None   # "IDENTITY(1,1)" or None
    generated: str | None = None  # "ROW START" | "ROW END" | None
    hidden: bool = False


@dataclass
class Key:
    name: str
    columns: list[str]


@dataclass
class ForeignKey:
    name: str
    columns: list[str]
    ref_table: str            # schema.Table
    ref_columns: list[str]
    on_delete: str = "NO ACTION"


@dataclass
class Check:
    name: str
    definition: str


@dataclass
class Default:
    name: str
    column: str
    definition: str


@dataclass
class Index:
    name: str
    columns: list[str]
    includes: list[str] = field(default_factory=list)
    unique: bool = False
    clustered: bool = False
    filter: str | None = None


@dataclass
class Table:
    schema: str
    name: str
    columns: list[Column] = field(default_factory=list)
    pk: Key | None = None
    uqs: list[Key] = field(default_factory=list)
    fks: list[ForeignKey] = field(default_factory=list)
    cks: list[Check] = field(default_factory=list)
    dfs: list[Default] = field(default_factory=list)
    indexes: list[Index] = field(default_factory=list)
    temporal_history: str | None = None   # schema.Table of the history table
    history_of: str | None = None         # for history tables: schema.Table of the current table

    @property
    def full_name(self) -> str:
        return f"{self.schema}.{self.name}"

    def column(self, name: str) -> Column | None:
        return next((c for c in self.columns if c.name.lower() == name.lower()), None)


# ----------------------------------------------------------------- normalisation
def norm_expr(expr: str | None) -> str:
    """Canonical form of a DEFAULT / filter expression so DDL text and the
    catalog's rewritten text compare equal."""
    if expr is None:
        return ""
    e = expr
    # SQL Server stores TRY_CONVERT(INT, x) as TRY_CAST(x AS [int])
    e = re.sub(r"TRY_CONVERT\s*\(\s*INT\s*,\s*(.+)\)\s*$", r"TRY_CAST(\1 AS INT)", e.strip(), flags=re.I)
    e = e.replace("[", "").replace("]", "")
    e = re.sub(r"\bN'", "'", e)
    e = re.sub(r"[()\s]", "", e)
    return e.upper()


def split_cols(text: str) -> list[str]:
    return [c.strip().strip("[]") for c in text.split(",") if c.strip()]


# --------------------------------------------------------------- DDL loader
_RE_CREATE = re.compile(r"CREATE TABLE (\w+)\.(\w+)\s*\((.*?)\n\s*\);", re.S)
_RE_COL = re.compile(r"^\s*(\w+)\s+([A-Z0-9]+(?:\s*\([^)]*\))?)\s*(.*?),?\s*$", re.I)
_RE_PK = re.compile(r"ALTER TABLE (\w+)\.(\w+) ADD CONSTRAINT (\w+) PRIMARY KEY (CLUSTERED|NONCLUSTERED)? ?\(([^)]*)\);")
_RE_UQ = re.compile(r"ALTER TABLE (\w+)\.(\w+) ADD CONSTRAINT (\w+) UNIQUE \(([^)]*)\);")
_RE_FK = re.compile(r"ALTER TABLE (\w+)\.(\w+) ADD CONSTRAINT (\w+) FOREIGN KEY \(([^)]*)\) REFERENCES (\w+)\.(\w+) \(([^)]*)\)( ON DELETE CASCADE)?;")
_RE_CK = re.compile(r"ALTER TABLE (\w+)\.(\w+) ADD CONSTRAINT (\w+) CHECK \((.*)\);")
_RE_DF = re.compile(r"ALTER TABLE (\w+)\.(\w+) ADD CONSTRAINT (\w+) DEFAULT \((.*)\) FOR (\w+);")
_RE_TEMPORAL = re.compile(r"ALTER TABLE (\w+)\.(\w+) SET \(SYSTEM_VERSIONING = ON \(HISTORY_TABLE = (\w+)\.(\w+)")
_RE_IX = re.compile(r"CREATE (UNIQUE )?(CLUSTERED |NONCLUSTERED )?INDEX (\w+) ON (\w+)\.(\w+) \(([^)]*)\)(?: INCLUDE \(([^)]*)\))?(?: WHERE (.*?))?;")
_RE_RENAME = re.compile(r"sp_rename N'(\w+)\.(\w+)\.(\w+)', N'(\w+)', N'INDEX'")


def _norm_type(raw: str) -> str:
    t = re.sub(r"\s+", "", raw.upper())
    return t


def load_from_ddl(sql_dir: Path = SQL_DIR) -> dict[str, Table]:
    tables: dict[str, Table] = {}

    ddl = (sql_dir / "03_create_tables.sql").read_text(encoding="utf-8")
    for m in _RE_CREATE.finditer(ddl):
        schema, name, body = m.groups()
        t = Table(schema, name)
        for line in body.splitlines():
            line = line.strip()
            if not line or line.startswith("--") or line.upper().startswith("PERIOD FOR"):
                continue
            cm = _RE_COL.match(line)
            if not cm:
                raise ValueError(f"Unparsed column line in {schema}.{name}: {line}")
            cname, ctype, rest = cm.groups()
            rest_u = rest.upper()
            col = Column(
                name=cname,
                type=_norm_type(ctype),
                nullable=not ("NOT NULL" in rest_u),
                identity="IDENTITY(1,1)" if "IDENTITY(1,1)" in rest_u.replace(" ", "") else None,
                generated="ROW START" if "ROW START" in rest_u else ("ROW END" if "ROW END" in rest_u else None),
                hidden="HIDDEN" in rest_u,
            )
            # "IDENTITY(1,1)" is parsed into the type group when written right after the type
            if col.type.endswith("IDENTITY(1,1)"):
                col.type = col.type[: -len("IDENTITY(1,1)")]
                col.identity = "IDENTITY(1,1)"
            t.columns.append(col)
        tables[t.full_name] = t

    def tbl(s: str, n: str) -> Table:
        key = f"{s}.{n}"
        if key not in tables:
            raise KeyError(f"Constraint/index references unknown table {key}")
        return tables[key]

    for script in ("04_primary_foreign_keys.sql", "05_constraints.sql"):
        text = (sql_dir / script).read_text(encoding="utf-8")
        for line in text.splitlines():
            if "ADD CONSTRAINT" not in line and "SYSTEM_VERSIONING" not in line:
                continue
            if m := _RE_PK.search(line):
                s, n, cname, _, cols = m.groups()
                tbl(s, n).pk = Key(cname, split_cols(cols))
            elif m := _RE_UQ.search(line):
                s, n, cname, cols = m.groups()
                tbl(s, n).uqs.append(Key(cname, split_cols(cols)))
            elif m := _RE_FK.search(line):
                s, n, cname, cols, rs, rn, rcols, cascade = m.groups()
                tbl(s, n).fks.append(ForeignKey(cname, split_cols(cols), f"{rs}.{rn}", split_cols(rcols),
                                                "CASCADE" if cascade else "NO ACTION"))
            elif m := _RE_CK.search(line):
                s, n, cname, definition = m.groups()
                tbl(s, n).cks.append(Check(cname, definition))
            elif m := _RE_DF.search(line):
                s, n, cname, definition, col = m.groups()
                tbl(s, n).dfs.append(Default(cname, col, definition))
            elif m := _RE_TEMPORAL.search(line):
                s, n, hs, hn = m.groups()
                tbl(s, n).temporal_history = f"{hs}.{hn}"
            elif "ADD CONSTRAINT" in line:
                raise ValueError(f"Unparsed constraint line in {script}: {line.strip()[:120]}")

    # History tables: SQL Server creates them from the current table's columns
    # (no IDENTITY, period columns not hidden, no constraints) with a clustered
    # index on (SysEndTime, SysStartTime).
    for t in list(tables.values()):
        if t.temporal_history:
            hs, hn = t.temporal_history.split(".")
            h = Table(hs, hn, history_of=t.full_name)
            for c in t.columns:
                h.columns.append(Column(c.name, c.type, c.nullable, None, None, False))
            h.indexes.append(Index(f"ix_{hn}", ["SysEndTime", "SysStartTime"], clustered=True))
            tables[h.full_name] = h

    ix_text = (sql_dir / "06_indexes.sql").read_text(encoding="utf-8")
    for line in ix_text.splitlines():
        if m := _RE_IX.search(line):
            uniq, kind, iname, s, n, cols, incl, flt = m.groups()
            tbl(s, n).indexes.append(Index(iname, split_cols(cols), split_cols(incl) if incl else [],
                                           unique=bool(uniq), clustered=(kind or "").strip() == "CLUSTERED",
                                           filter=flt.strip() if flt else None))
        elif m := _RE_RENAME.search(line):
            s, n, old, new = m.groups()
            for ix in tbl(s, n).indexes:
                if ix.name.lower() == old.lower():
                    ix.name = new
        elif "CREATE" in line and "INDEX" in line and not line.lstrip().startswith("--"):
            raise ValueError(f"Unparsed index line: {line.strip()[:120]}")
    return tables


# ----------------------------------------------------------- catalog loader
def _catalog_type(type_name: str, max_length: int, precision: int, scale: int) -> str:
    t = type_name.lower()
    if t in ("nvarchar", "nchar"):
        return f"{t.upper()}({'MAX' if max_length == -1 else max_length // 2})"
    if t in ("varchar", "char", "varbinary", "binary"):
        return f"{t.upper()}({'MAX' if max_length == -1 else max_length})"
    if t in ("decimal", "numeric"):
        return f"{t.upper()}({precision},{scale})"
    if t in ("datetime2", "time", "datetimeoffset"):
        return f"{t.upper()}({scale})"
    if t == "timestamp":
        return "ROWVERSION"
    return t.upper()


def load_from_catalog(conn_str: str, schemas: list[str] = CORE_SCHEMAS) -> dict[str, Table]:
    import pyodbc  # imported lazily so the DDL mode needs no extra package

    cn = pyodbc.connect(conn_str, autocommit=True)
    cur = cn.cursor()
    in_list = ",".join("?" for _ in schemas)
    tables: dict[str, Table] = {}
    by_id: dict[int, Table] = {}

    for oid, s, n, ttype, hist_id in cur.execute(
            f"SELECT t.object_id, SCHEMA_NAME(t.schema_id), t.name, t.temporal_type, t.history_table_id "
            f"FROM sys.tables t WHERE SCHEMA_NAME(t.schema_id) IN ({in_list})", schemas).fetchall():
        t = Table(s, n)
        tables[t.full_name] = t
        by_id[oid] = t
        t._hist_id = hist_id  # type: ignore[attr-defined]

    for t in tables.values():
        hid = getattr(t, "_hist_id", None)
        if hid and hid in by_id:
            t.temporal_history = by_id[hid].full_name
            by_id[hid].history_of = t.full_name

    for oid, cname, tname, maxlen, prec, scale, nullable, is_ident, gen, hidden in cur.execute(
            f"""SELECT c.object_id, c.name, ty.name, c.max_length, c.precision, c.scale, c.is_nullable,
                       c.is_identity, c.generated_always_type, c.is_hidden
                FROM sys.columns c
                JOIN sys.tables t ON t.object_id = c.object_id
                JOIN sys.types ty ON ty.user_type_id = c.user_type_id
                WHERE SCHEMA_NAME(t.schema_id) IN ({in_list})
                ORDER BY c.object_id, c.column_id""", schemas).fetchall():
        ident = None
        if is_ident:
            seed, inc = cur.connection.cursor().execute(
                "SELECT CAST(seed_value AS BIGINT), CAST(increment_value AS BIGINT) FROM sys.identity_columns "
                "WHERE object_id = ? AND name = ?", oid, cname).fetchone()
            ident = f"IDENTITY({seed},{inc})"
        by_id[oid].columns.append(Column(
            cname, _catalog_type(tname, maxlen, prec, scale), bool(nullable), ident,
            {1: "ROW START", 2: "ROW END"}.get(gen), bool(hidden)))

    def cols_of(oid: int, index_id: int, included: int) -> list[str]:
        return [r[0] for r in cur.connection.cursor().execute(
            "SELECT c.name FROM sys.index_columns ic JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id "
            "WHERE ic.object_id = ? AND ic.index_id = ? AND ic.is_included_column = ? "
            "ORDER BY CASE WHEN ic.key_ordinal = 0 THEN ic.index_column_id ELSE ic.key_ordinal END", oid, index_id, included).fetchall()]

    for oid, iname, itype, is_unique, is_pk, is_uq, has_filter, flt, index_id in cur.execute(
            f"""SELECT i.object_id, i.name, i.type, i.is_unique, i.is_primary_key, i.is_unique_constraint,
                       i.has_filter, i.filter_definition, i.index_id
                FROM sys.indexes i JOIN sys.tables t ON t.object_id = i.object_id
                WHERE SCHEMA_NAME(t.schema_id) IN ({in_list}) AND i.type > 0""", schemas).fetchall():
        t = by_id[oid]
        keys = cols_of(oid, index_id, 0)
        if is_pk:
            t.pk = Key(iname, keys)
        elif is_uq:
            t.uqs.append(Key(iname, keys))
        else:
            t.indexes.append(Index(iname, keys, cols_of(oid, index_id, 1), bool(is_unique), itype == 1,
                                   flt if has_filter else None))

    for fk_id, fname, parent, ref_schema, ref_table, delete_action in cur.execute(
            f"""SELECT fk.object_id, fk.name, fk.parent_object_id, OBJECT_SCHEMA_NAME(fk.referenced_object_id),
                       OBJECT_NAME(fk.referenced_object_id), fk.delete_referential_action_desc
                FROM sys.foreign_keys fk WHERE OBJECT_SCHEMA_NAME(fk.parent_object_id) IN ({in_list})""", schemas).fetchall():
        pairs = cur.connection.cursor().execute(
            "SELECT COL_NAME(parent_object_id, parent_column_id), COL_NAME(referenced_object_id, referenced_column_id) "
            "FROM sys.foreign_key_columns WHERE constraint_object_id = ? ORDER BY constraint_column_id", fk_id).fetchall()
        by_id[parent].fks.append(ForeignKey(fname, [p[0] for p in pairs], f"{ref_schema}.{ref_table}",
                                            [p[1] for p in pairs],
                                            "NO ACTION" if delete_action == "NO_ACTION" else delete_action))

    for parent, cname, definition in cur.execute(
            f"SELECT parent_object_id, name, definition FROM sys.check_constraints "
            f"WHERE OBJECT_SCHEMA_NAME(parent_object_id) IN ({in_list})", schemas).fetchall():
        by_id[parent].cks.append(Check(cname, definition))

    for parent, cname, col, definition in cur.execute(
            f"SELECT d.parent_object_id, d.name, COL_NAME(d.parent_object_id, d.parent_column_id), d.definition "
            f"FROM sys.default_constraints d WHERE OBJECT_SCHEMA_NAME(d.parent_object_id) IN ({in_list})", schemas).fetchall():
        by_id[parent].dfs.append(Default(cname, col, definition))

    cn.close()
    return tables


# ----------------------------------------------------------------- helpers
def enum_values(table: Table) -> dict[str, list[str]]:
    """Column -> allowed values, taken from CHECK (Col IN (N'a', N'b')) constraints."""
    out: dict[str, list[str]] = {}
    for ck in table.cks:
        for col, values in re.findall(r"(\w+) IN \(((?:N'[^']*'(?:,\s*)?)+)\)", ck.definition):
            if "NOT IN" in ck.definition and f"{col} NOT IN" in ck.definition:
                continue
            out[col] = re.findall(r"N'([^']*)'", values)
    return out

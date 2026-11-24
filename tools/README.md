# Tools

None of these tools read `.env` files. They read only `sql/*.sql` and, when given a connection string, the database catalog.

| Tool | Purpose | Needs |
|---|---|---|
| `deploy.ps1` | Runs `sql/00_run_all.sql` with sqlcmd. `-Clean` drops and recreates the target, but only when it is named `SchoolManagement` or `SchoolManagement_<suffix>`. | sqlcmd |
| `schema_model.py` | Shared library: loads the physical schema from the T-SQL scripts **or** from a deployed catalog into one model | Python 3.10+; pyodbc only for catalog mode |
| `generate_diagrams.py` | Writes the conceptual, logical and physical `.puml` files from the model. Default source: `sql/`; `--catalog "<odbc>"` reads a deployed database instead. | Python |
| `generate_docs.py` | Writes `docs/TABLE_CATALOG.md` and `docs/DATABASE_RELATIONSHIPS.md` from `sql/` | Python |
| `verify_physical_erd.py` | Parses `diagrams/physical/**/*.puml` independently and compares every table, column, type, nullability, identity, period column, PK, UQ, FK (columns, target, delete rule), CHECK name, DEFAULT (normalised expression), index (keys, includes, unique, clustered, filter), temporal link and relationship edge against the **deployed catalog**. `--ddl` is the fallback for when no database can be deployed. Exit code 0 means it passed. | Python, pyodbc, ODBC Driver 17/18 |

Typical workflow after changing the SQL:

```bash
python tools/generate_diagrams.py
```
```bash
python tools/generate_docs.py
```
```bash
pwsh tools/deploy.ps1 -DatabaseName SchoolManagement_Validation -Clean
```
```bash
python tools/verify_physical_erd.py --catalog "DRIVER={ODBC Driver 17 for SQL Server};SERVER=.\SQLEXPRESS;DATABASE=SchoolManagement_Validation;Trusted_Connection=yes;"
```

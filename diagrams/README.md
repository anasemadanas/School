# Diagrams

PlantUML sources for the four modelling levels of the School Management database.

```
diagrams/
├── _style.iuml                 shared style (colours, fonts) - included by every diagram
├── conceptual/  master_conceptual.puml  + modules/   entities, relationships, cardinalities (no attributes)
├── logical/     master_logical.puml     + modules/   attributes with generic domains, PK/FK/AK, business rules
├── physical/    master_physical.puml    + modules/   exact SQL Server tables, columns, types, constraints, indexes
└── categorical/ master_categorical.puml + modules/   EER: specialization/generalization and categories
```

Module diagrams: `organization`, `iam`, `people`, `academic`, `enrollment`, `timetable`, `attendance`, `assessment`, `finance_setup`, `finance_billing`, `audit`. Finance has 16 tables, so it is split in two to keep each diagram readable. Categorical modules exist only where a real specialization exists: `people_roles` and `finance_payer`.

## Where the diagrams come from

| Level | Produced by | Source |
|---|---|---|
| Conceptual, logical, physical | `python tools/generate_diagrams.py` | Parsed from `sql/03`–`06` (the source of truth). Pass `--catalog "<ODBC string>"` to read a deployed database instead. |
| Categorical | Hand-written | Justified in [docs/CATEGORICAL_MODEL.md](../docs/CATEGORICAL_MODEL.md) |

Never edit a generated `.puml` by hand: change the SQL, then regenerate. `tools/verify_physical_erd.py` compares the physical diagrams with the deployed catalog and fails on any difference.

The master diagrams are **overviews**:
- The conceptual master shows cross-module relationships and the five empty reserved schemas.
- The logical master shows identifiers and relationships.
- The physical master shows key columns (PK/FK) and every relationship.

Full detail is always in `modules/`.

## Notation legend

| Symbol | Meaning |
|---|---|
| `\|\|--o{` | exactly one parent, zero or many children (mandatory FK) |
| `\|o--o{` | zero or one parent (nullable FK), zero or many children |
| `\|\|--o\|` | one-to-zero-or-one (the FK is also unique, e.g. subtype sharing the supertype key) |
| `*` before an attribute | mandatory / NOT NULL |
| «PK» «FK» «AKn» | primary key, foreign key, alternate key *n* (logical) |
| «IDENTITY(1,1)» «ROW START» «ROW END» «HIDDEN» | physical column properties |
| `PK` / `UQ` / `FK` / `CK` / `DF` / `IX` lines | constraint and index names exactly as deployed |
| <<lookup>> (green) | reference list |
| <<temporal>> (amber) | system-versioned table; history kept in `audit.*History` |
| <<history>> (grey) | temporal history table maintained by SQL Server |
| <<external>> (grey) | table owned by another module, shown for context |
| <<reserved>> (dashed) | empty schema reserved for future expansion (no tables) |
| EER `o` / `d` / `U` | overlapping / disjoint specialization / category (union) |
| EER thin / thick line | partial / total participation |

## Rendering

Requirements: Java 8+ and `plantuml.jar` (tested with PlantUML 1.2024.7 on Java 25).

```bash
java -DPLANTUML_LIMIT_SIZE=32768 -jar plantuml.jar -charset UTF-8 -tsvg "diagrams/**/*.puml"
```

- Use `-tpng` for PNG output. Rendered files are git-ignored.
- `PLANTUML_LIMIT_SIZE` is needed for the large master diagrams.
- VS Code: the *PlantUML* extension (jebbs.plantuml) previews any file with Alt+D.
- `!include` paths are relative, so render from any directory.

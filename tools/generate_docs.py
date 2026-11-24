"""
generate_docs.py - writes docs/TABLE_CATALOG.md and docs/DATABASE_RELATIONSHIPS.md
from the parsed sql/ scripts, so every table, column, key, index and
relationship in the docs matches the source of truth.

Usage: python tools/generate_docs.py
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from generate_diagrams import MODULES, crowfoot, module_tables  # noqa: E402
from schema_model import load_from_ddl  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent

# Growth classes (illustrative sizing: N = active students; Y = academic years kept online)
G_STATIC = "Static reference data (tens of rows)"
G_SMALL = "Small; grows with organisation size (hundreds of rows)"
G_YEARLY = "Grows per academic year (≈ hundreds–low thousands per year)"
G_STUDENT = "Grows with students (≈ 1–3 rows per student per year)"

PURPOSE = {
    "organization.Countries": ("Countries and nationalities (ISO codes, Arabic/English names).", G_STATIC),
    "organization.Schools": ("Legal school entity; owns branches, academic years and departments.", G_STATIC),
    "organization.Branches": ("Campus/branch with its working-day pattern.", G_STATIC),
    "organization.Buildings": ("Building on a campus.", G_STATIC),
    "organization.RoomTypes": ("Lookup: classroom, lab, gym, hall...", G_STATIC),
    "organization.Rooms": ("Teaching and other rooms; optional seat capacity.", G_SMALL),
    "organization.Departments": ("Academic or administrative department.", G_STATIC),
    "organization.DocumentNumberSeries": ("Next business number per document type, branch and year (no SEQUENCE objects).", G_SMALL),
    "iam.UserAccounts": ("Login accounts (local hash or external identity), optionally linked to one person.", G_STUDENT),
    "iam.Roles": ("Application roles.", G_STATIC),
    "iam.Permissions": ("Fine-grained permission codes.", G_STATIC),
    "iam.RolePermissions": ("Role-permission matrix (associative entity).", G_STATIC),
    "iam.UserRoles": ("Role grants to users, optionally branch-scoped and dated.", G_STUDENT),
    "people.Persons": ("Supertype of every human; bilingual 4-part names. System-versioned.", "Grows with students + guardians + staff (≈ 2.5 rows per new student)"),
    "people.PersonContacts": ("Phones/emails with one primary per type.", "≈ 2–3 per adult person"),
    "people.PersonAddresses": ("Postal addresses.", "≈ 1 per household"),
    "people.IdentityDocumentTypes": ("Lookup: national number, passport, residency, birth certificate.", G_STATIC),
    "people.PersonIdentityDocuments": ("Identity documents (PII).", "≈ 1 per person"),
    "people.Students": ("Student subtype (shared PK with Persons).", "1 per student ever admitted (never deleted)"),
    "people.Guardians": ("Guardian subtype (shared PK with Persons).", "≈ 1.5 per student"),
    "people.Employees": ("Employee subtype (shared PK with Persons).", G_SMALL),
    "people.Teachers": ("Teacher subtype of Employees.", G_SMALL),
    "people.RelationshipTypes": ("Lookup: father, mother, uncle, legal guardian...", G_STATIC),
    "people.StudentGuardians": ("M:N student-guardian link with custody, pickup and contact flags.", "≈ 2 per student"),
    "academic.AcademicYears": ("First-class academic year; scopes all yearly data.", "1 per year"),
    "academic.Terms": ("Semesters/terms of a year.", "2–3 per year"),
    "academic.Holidays": ("Non-school days (school-wide or per branch).", "≈ 10–20 per year"),
    "academic.GradeLevels": ("Lookup: KG1..Grade 12 with promotion path.", G_STATIC),
    "academic.Programs": ("Lookup: national curriculum, streams, international.", G_STATIC),
    "academic.Subjects": ("Subject catalogue.", G_STATIC),
    "academic.CurriculumSubjects": ("Subjects offered per year + grade + program (weekly periods, grading scale).", G_YEARLY),
    "academic.Sections": ("Class sections per year/branch/grade with optional capacity.", G_YEARLY),
    "academic.TeachingAssignments": ("Teacher teaches a curriculum subject to a section (whole year or a term).", G_YEARLY),
    "enrollment.Applications": ("Admission applications with status workflow.", "≈ 1.2 per new student"),
    "enrollment.ApplicationStatusHistory": ("Every application status change (append-only).", "≈ 3 per application"),
    "enrollment.Enrollments": ("Student enrollment per academic year (one per student per year). System-versioned.", "1 per student per year"),
    "enrollment.SectionAssignments": ("Placement of an enrollment in a section with dates (transfer history).", "≈ 1.05 per enrollment"),
    "enrollment.EnrollmentSubjects": ("Elective / stream subject choices.", "0–3 per enrollment"),
    "timetable.BellSchedules": ("Period patterns per branch and year.", "Few per branch per year"),
    "timetable.Periods": ("Periods of a bell schedule.", "≈ 8 per bell schedule"),
    "timetable.Timetables": ("Versioned timetable per section and term.", "≈ 2–4 per section per year"),
    "timetable.TimetableEntries": ("Day x period slots of a timetable.", "≈ 30 per timetable version"),
    "attendance.AttendanceStatuses": ("Lookup: present, late, absent, excused...", G_STATIC),
    "attendance.AttendanceSessions": ("One roll-call per section per day (or per period).", "sections × school days (× periods in period mode)"),
    "attendance.AttendanceRecords": ("One row per student per roll-call. HIGH VOLUME.", "students × ≈180 days per year (×7 in period mode)"),
    "assessment.GradingScales": ("Grading scales with pass mark.", G_STATIC),
    "assessment.GradingScaleBands": ("Percentage bands -> letter and descriptor.", G_STATIC),
    "assessment.AssessmentTypes": ("Lookup: quiz, homework, midterm, final...", G_STATIC),
    "assessment.AssessmentWeights": ("Weight of each assessment type per subject and term.", G_YEARLY),
    "assessment.Assessments": ("A concrete assessment given to a teaching assignment.", "≈ 6–20 per teaching assignment per year"),
    "assessment.AssessmentResults": ("Student score per assessment. System-versioned. HIGH VOLUME.", "students × subjects × assessments (≈ 200+ per student per year)"),
    "assessment.ReportCards": ("Versioned report-card snapshot per enrollment and term.", "≈ 2–3 per student per year"),
    "assessment.ReportCardLines": ("Per-subject line of a report card.", "≈ 10 per report card"),
    "finance.Currencies": ("Lookup: ISO currencies with minor units.", G_STATIC),
    "finance.FeeTypes": ("Lookup: tuition, registration, books, uniform...", G_STATIC),
    "finance.FeeStructures": ("Fee schedule per year + branch + grade + program.", G_YEARLY),
    "finance.FeeStructureItems": ("Fee amounts within a structure. System-versioned.", G_YEARLY),
    "finance.FeeInstallments": ("Installment due dates and percentages.", G_YEARLY),
    "finance.DiscountTypes": ("Lookup: sibling, staff, merit, aid...", G_STATIC),
    "finance.StudentDiscounts": ("Discounts granted to an enrollment.", "≈ 0.3 per enrollment"),
    "finance.Sponsors": ("Sponsoring organisations (employers, NGOs, funds).", G_SMALL),
    "finance.Payers": ("EER category: a payer is exactly one guardian or one sponsor.", "≈ 1 per family"),
    "finance.StudentPayers": ("Who pays which share of an enrollment.", "≈ 1.1 per enrollment"),
    "finance.Invoices": ("Issued invoices (immutable; corrected by credit notes). BIGINT.", "≈ 3–4 per enrollment per year"),
    "finance.InvoiceLines": ("Invoice lines per fee type. BIGINT.", "≈ 2–5 per invoice"),
    "finance.CreditNotes": ("Credit notes against invoices. BIGINT.", "Small fraction of invoices"),
    "finance.PaymentMethods": ("Lookup: cash, cheque, transfer, card, eFAWATEERcom.", G_STATIC),
    "finance.Payments": ("Money received. BIGINT.", "≈ 3–6 per payer per year"),
    "finance.PaymentAllocations": ("Allocation of payments to invoices (partial/split). BIGINT.", "≈ 1–2 per payment"),
    "audit.AuditEvents": ("Business-event log written by every procedure. HIGH VOLUME.", "≈ every business transaction"),
    "audit.SecurityEvents": ("Logins, failures, role grants. HIGH VOLUME.", "≈ users × logins"),
    "audit.PersonsHistory": ("Temporal history of people.Persons (system-maintained).", "Every change to a person"),
    "audit.EnrollmentsHistory": ("Temporal history of enrollment.Enrollments.", "Every enrollment change"),
    "audit.AssessmentResultsHistory": ("Temporal history of assessment results (grade changes).", "Every grade correction"),
    "audit.FeeStructureItemsHistory": ("Temporal history of fee amounts.", "Every fee change"),
}


def main() -> int:
    model = load_from_ddl()
    missing = sorted(set(model) - set(PURPOSE))
    if missing:
        print("Missing PURPOSE entries:", missing)
        return 1

    out = ["# Table Catalog", "",
           "> Generated by `tools/generate_docs.py` from the `sql/` scripts (the source of truth). Do not edit by hand.",
           "> Types are SQL Server 2022 types. `NN` = NOT NULL. Expected growth is a planning estimate; there is no",
           "> maximum student count anywhere in the design.", "",
           f"**{len(model)} tables** in the 10 delivered schemas (71 business tables + 4 temporal history tables).", ""]
    out.append("## Index\n")
    for mod, cfg in MODULES.items():
        names = ", ".join(f"[{t.full_name}](#{t.full_name.replace('.', '').lower()})" for t in module_tables(model, mod))
        out.append(f"- **{cfg['title']}**: {names}")
    out.append("")
    for mod, cfg in MODULES.items():
        out.append(f"## {cfg['title']}\n")
        for t in module_tables(model, mod):
            purpose, growth = PURPOSE[t.full_name]
            out.append(f"### {t.full_name}\n")
            out.append(f"**Purpose:** {purpose}  ")
            out.append(f"**Key type:** {'BIGINT' if any(c.type == 'BIGINT' and c.identity for c in t.columns) else 'INT'}"
                       f"{' · **Temporal:** history in `' + t.temporal_history + '`' if t.temporal_history else ''}"
                       f"{' · **History of:** `' + t.history_of + '`' if t.history_of else ''}  ")
            out.append(f"**Expected growth:** {growth}\n")
            out.append("| Column | Type | Null | Notes |")
            out.append("|---|---|---|---|")
            dfs = {d.column: d.definition for d in t.dfs}
            for c in t.columns:
                notes = []
                if t.pk and c.name in t.pk.columns:
                    notes.append("PK")
                for fk in t.fks:
                    if c.name in fk.columns:
                        notes.append(f"FK → {fk.ref_table}")
                if c.identity:
                    notes.append(c.identity)
                if c.generated:
                    notes.append(f"GENERATED ALWAYS AS {c.generated}" + (" HIDDEN" if c.hidden else ""))
                if c.name in dfs:
                    notes.append(f"DEFAULT {dfs[c.name]}")
                out.append(f"| {c.name} | {c.type} | {'NULL' if c.nullable else 'NN'} | {'; '.join(notes).replace('|', '/')} |")
            out.append("")
            keys = []
            if t.pk:
                keys.append(f"- PK `{t.pk.name}` ({', '.join(t.pk.columns)})")
            keys += [f"- UQ `{u.name}` ({', '.join(u.columns)})" for u in t.uqs]
            keys += [f"- FK `{f.name}` ({', '.join(f.columns)}) → {f.ref_table} ({', '.join(f.ref_columns)})"
                     f"{' ON DELETE CASCADE' if f.on_delete == 'CASCADE' else ''}" for f in t.fks]
            keys += [f"- CK `{c.name}`: `{c.definition}`" for c in t.cks]
            keys += [f"- IX `{i.name}` ({', '.join(i.columns)})"
                     f"{' INCLUDE (' + ', '.join(i.includes) + ')' if i.includes else ''}"
                     f"{' UNIQUE' if i.unique else ''}{' CLUSTERED' if i.clustered else ''}"
                     f"{' WHERE ' + i.filter if i.filter else ''}" for i in t.indexes]
            if keys:
                out.append("**Keys, constraints, indexes**\n")
                out += keys
                out.append("")
    (ROOT / "docs" / "TABLE_CATALOG.md").write_text("\n".join(out) + "\n", encoding="utf-8")

    rel = ["# Database Relationships", "",
           "> Generated by `tools/generate_docs.py` from the `sql/` scripts. Every foreign key in the database is listed.", "",
           "Cardinality notation (parent side `--` child side): `||` exactly one, `|o` zero or one (nullable FK),",
           "`o{` zero or many, `o|` zero or one (FK columns are also unique, e.g. a shared-PK subtype).", "",
           "ON DELETE is NO ACTION unless stated. CASCADE is used only for pure child rows that are never business history.", ""]
    total = 0
    for mod, cfg in MODULES.items():
        rows = []
        for t in module_tables(model, mod):
            for f in t.fks:
                rows.append(f"| `{f.name}` | {f.ref_table} ({', '.join(f.ref_columns)}) | `{crowfoot(t, f).replace('|', chr(92) + '|')}` | {t.full_name} ({', '.join(f.columns)}) | {f.on_delete} |")
        if rows:
            total += len(rows)
            rel += [f"## {cfg['title']}", "", "| Foreign key | Parent | Cardinality | Child | On delete |", "|---|---|---|---|---|"] + rows + [""]
    rel.insert(4, f"**{total} foreign keys.**\n")
    rel += ["## Cross-module dependency summary", "",
            "| Child module | Depends on |", "|---|---|"]
    from generate_diagrams import module_of
    deps: dict[str, set[str]] = {}
    for t in model.values():
        for f in t.fks:
            a, b = module_of(t.full_name), module_of(f.ref_table)
            if a != b:
                deps.setdefault(a, set()).add(b)
    for a in MODULES:
        if a in deps:
            rel.append(f"| {a} | {', '.join(sorted(deps[a]))} |")
    rel.append("")
    (ROOT / "docs" / "DATABASE_RELATIONSHIPS.md").write_text("\n".join(rel) + "\n", encoding="utf-8")
    print(f"Wrote TABLE_CATALOG.md ({len(model)} tables) and DATABASE_RELATIONSHIPS.md ({total} FKs).")
    return 0


if __name__ == "__main__":
    sys.exit(main())

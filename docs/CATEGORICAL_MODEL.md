# Categorical (EER) Model

The categorical level records **specialization / generalization** and **categories (union types)**. For each one it gives four things:
- disjoint or overlapping,
- total or partial participation,
- the defining condition,
- how it is implemented physically.

Diagrams: [master_categorical.puml](../diagrams/categorical/master_categorical.puml), [modules/people_roles.puml](../diagrams/categorical/modules/people_roles.puml), [modules/finance_payer.puml](../diagrams/categorical/modules/finance_payer.puml).

## 1. Person → {Student, Guardian, Employee}: overlapping, partial

| Property | Value | Justification |
|---|---|---|
| Superclass | Person (`people.Persons`) | Shared data: bilingual 4-part name, gender, date of birth, nationality, contacts, addresses, identity documents |
| Subclasses | Student, Guardian, Employee | Each has its own attributes: student number and admission date; occupation and employer; employee number, department and hire date |
| Disjointness | **Overlapping (o)** | A real school has teachers who are parents of enrolled students (in the sample data: Khaled, Omar and Ahmad). A graduate can later be employed. Disjoint subclasses would force duplicate person records. |
| Participation | **Partial** | Some people hold none of these roles: an applicant who isn't accepted yet (Jad in the sample data), an emergency contact. |
| Defining attribute | None (attribute-defined specialization isn't possible with overlap) | Membership is the **existence of a subtype row**. `people.vw_PersonRoles` derives the role flags. |
| Implementation | Class-table inheritance with a shared primary key | `Students.PersonId`, `Guardians.PersonId` and `Employees.PersonId` are each the PK **and** an FK to `Persons.PersonId`. Overlap needs no discriminator column, and a 1:0..1 link per subclass enforces "at most one Student row per person". |

## 2. Employee → {Teacher}: single subclass, partial

| Property | Value |
|---|---|
| Superclass | Employee (itself a subclass of Person) |
| Subclass | Teacher (licence, specialisation, maximum weekly periods) |
| Participation | **Partial**: accountants and registrars are employees but not teachers |
| Implementation | `Teachers.PersonId` = PK and FK → `Employees.PersonId`. A teacher therefore cannot exist without being an employee, so Teacher is a **subclass of Employee, not a sibling of it** (as required). |
| Extension point | A future `hr` module could add employee-specific tables keyed by `Employees.PersonId` without changing any existing table (see FUTURE_EXPANSION.md). |

## 3. Payer = Guardian ∪ Sponsor: a true category (union type)

| Property | Value | Justification |
|---|---|---|
| Superclasses | Guardian (`people.Guardians`), Sponsor (`finance.Sponsors`) | Invoices are billed to a family member or to a sponsoring organization, such as an employer education fund. In the sample data, Zaid's fees are split 50/50 between his father and his father's employer. |
| Category | Payer (`finance.Payers`) | Invoices, payments and responsibilities refer to *one* party type, whichever superclass it comes from |
| Why a category, not a specialization | Guardian and Sponsor have **different keys** and different supertypes (Person vs. organization). Payer is a subset of their *union*, not a specialization of either one. | |
| Category participation | **Total**: every Payer is exactly one Guardian or one Sponsor | `CK_Payers_ExactlyOne` plus the `PayerType` discriminator |
| Superclass participation | **Partial**: not every guardian or sponsor pays | A payer row is created only when needed |
| Uniqueness | At most one payer row per guardian / sponsor | Filtered UNIQUE indexes `IX_Payers_GuardianId` and `IX_Payers_SponsorId` |
| Implementation | Surrogate `PayerId` plus two nullable FKs, exactly one of which is set | Standard relational mapping of an EER category |

## Modules with no meaningful specialization

No specialization has been invented where the business has none.

| Module | Candidates considered | Why it isn't a specialization |
|---|---|---|
| organization | Room by room type; academic vs. administrative department | Types share every attribute and only differ by classification, so a lookup or CHECK value is enough. No type-specific attributes exist. |
| iam | Local vs. external accounts | Only the credential source differs. This is handled with `AuthProvider` plus a CHECK constraint, not with subtype tables. |
| academic | Core vs. elective subject; KG vs. school grade | A flag or a stage value; no distinct attributes. |
| enrollment | Enrolled / withdrawn / transferred | **States** of one enrollment over time, not kinds of enrollment. |
| timetable, attendance | Draft / published timetable; present / absent records | States and classifications. |
| assessment | Quiz / midterm / final; draft / published report cards | Classification (lookup) and states. |
| finance (other than Payer) | Taxable fee types; cash / cheque / card payments | Classification. Reference numbers are optional per method (`RequiresReference`), with no method-specific tables. |
| audit | Audit events vs. security events | Two independent logs with different shapes. They share no supertype data and are never queried as one entity. |

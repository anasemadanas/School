/* =============================================================================
   04_primary_foreign_keys.sql
   Purpose     : Add every PRIMARY KEY, then the alternate (UNIQUE) keys that
                 composite foreign keys reference, then every FOREIGN KEY.
   Dependencies: 03_create_tables.sql
   Run order   : 4 of 12
   Idempotent  : Yes (IF OBJECT_ID(<constraint>) IS NULL around each ADD).
   ON DELETE   : NO ACTION by default. CASCADE is used only for pure child rows
                 that are never business history:
                   iam.RolePermissions (from Roles and Permissions)
                   people.PersonContacts, people.PersonAddresses (from Persons)
                   timetable.TimetableEntries (from Timetables; procedures
                   only allow deleting Draft timetables)
                 Financial, academic, attendance, assessment and enrollment
                 history never cascades.
   Naming      : PK_<Schema>_<Table>, FK_<Child>_<Parent>[_<Column>],
                 UQ_<Table>_<Columns>.
   ============================================================================= */
USE [$(DatabaseName)];
GO

/* -----------------------------------------------------------------------------
   1. PRIMARY KEYS (all clustered on the surrogate key)
   ----------------------------------------------------------------------------- */
-- organization
IF OBJECT_ID(N'organization.PK_organization_Countries', N'PK') IS NULL ALTER TABLE organization.Countries ADD CONSTRAINT PK_organization_Countries PRIMARY KEY CLUSTERED (CountryId);
IF OBJECT_ID(N'organization.PK_organization_Schools', N'PK') IS NULL ALTER TABLE organization.Schools ADD CONSTRAINT PK_organization_Schools PRIMARY KEY CLUSTERED (SchoolId);
IF OBJECT_ID(N'organization.PK_organization_Branches', N'PK') IS NULL ALTER TABLE organization.Branches ADD CONSTRAINT PK_organization_Branches PRIMARY KEY CLUSTERED (BranchId);
IF OBJECT_ID(N'organization.PK_organization_Buildings', N'PK') IS NULL ALTER TABLE organization.Buildings ADD CONSTRAINT PK_organization_Buildings PRIMARY KEY CLUSTERED (BuildingId);
IF OBJECT_ID(N'organization.PK_organization_RoomTypes', N'PK') IS NULL ALTER TABLE organization.RoomTypes ADD CONSTRAINT PK_organization_RoomTypes PRIMARY KEY CLUSTERED (RoomTypeId);
IF OBJECT_ID(N'organization.PK_organization_Rooms', N'PK') IS NULL ALTER TABLE organization.Rooms ADD CONSTRAINT PK_organization_Rooms PRIMARY KEY CLUSTERED (RoomId);
IF OBJECT_ID(N'organization.PK_organization_Departments', N'PK') IS NULL ALTER TABLE organization.Departments ADD CONSTRAINT PK_organization_Departments PRIMARY KEY CLUSTERED (DepartmentId);
IF OBJECT_ID(N'organization.PK_organization_DocumentNumberSeries', N'PK') IS NULL ALTER TABLE organization.DocumentNumberSeries ADD CONSTRAINT PK_organization_DocumentNumberSeries PRIMARY KEY CLUSTERED (DocumentNumberSeriesId);
GO
-- iam
IF OBJECT_ID(N'iam.PK_iam_UserAccounts', N'PK') IS NULL ALTER TABLE iam.UserAccounts ADD CONSTRAINT PK_iam_UserAccounts PRIMARY KEY CLUSTERED (UserAccountId);
IF OBJECT_ID(N'iam.PK_iam_Roles', N'PK') IS NULL ALTER TABLE iam.Roles ADD CONSTRAINT PK_iam_Roles PRIMARY KEY CLUSTERED (RoleId);
IF OBJECT_ID(N'iam.PK_iam_Permissions', N'PK') IS NULL ALTER TABLE iam.Permissions ADD CONSTRAINT PK_iam_Permissions PRIMARY KEY CLUSTERED (PermissionId);
IF OBJECT_ID(N'iam.PK_iam_RolePermissions', N'PK') IS NULL ALTER TABLE iam.RolePermissions ADD CONSTRAINT PK_iam_RolePermissions PRIMARY KEY CLUSTERED (RoleId, PermissionId);
IF OBJECT_ID(N'iam.PK_iam_UserRoles', N'PK') IS NULL ALTER TABLE iam.UserRoles ADD CONSTRAINT PK_iam_UserRoles PRIMARY KEY CLUSTERED (UserRoleId);
GO
-- people
IF OBJECT_ID(N'people.PK_people_Persons', N'PK') IS NULL ALTER TABLE people.Persons ADD CONSTRAINT PK_people_Persons PRIMARY KEY CLUSTERED (PersonId);
IF OBJECT_ID(N'people.PK_people_PersonContacts', N'PK') IS NULL ALTER TABLE people.PersonContacts ADD CONSTRAINT PK_people_PersonContacts PRIMARY KEY CLUSTERED (PersonContactId);
IF OBJECT_ID(N'people.PK_people_PersonAddresses', N'PK') IS NULL ALTER TABLE people.PersonAddresses ADD CONSTRAINT PK_people_PersonAddresses PRIMARY KEY CLUSTERED (PersonAddressId);
IF OBJECT_ID(N'people.PK_people_IdentityDocumentTypes', N'PK') IS NULL ALTER TABLE people.IdentityDocumentTypes ADD CONSTRAINT PK_people_IdentityDocumentTypes PRIMARY KEY CLUSTERED (IdentityDocumentTypeId);
IF OBJECT_ID(N'people.PK_people_PersonIdentityDocuments', N'PK') IS NULL ALTER TABLE people.PersonIdentityDocuments ADD CONSTRAINT PK_people_PersonIdentityDocuments PRIMARY KEY CLUSTERED (PersonIdentityDocumentId);
IF OBJECT_ID(N'people.PK_people_Students', N'PK') IS NULL ALTER TABLE people.Students ADD CONSTRAINT PK_people_Students PRIMARY KEY CLUSTERED (PersonId);
IF OBJECT_ID(N'people.PK_people_Guardians', N'PK') IS NULL ALTER TABLE people.Guardians ADD CONSTRAINT PK_people_Guardians PRIMARY KEY CLUSTERED (PersonId);
IF OBJECT_ID(N'people.PK_people_Employees', N'PK') IS NULL ALTER TABLE people.Employees ADD CONSTRAINT PK_people_Employees PRIMARY KEY CLUSTERED (PersonId);
IF OBJECT_ID(N'people.PK_people_Teachers', N'PK') IS NULL ALTER TABLE people.Teachers ADD CONSTRAINT PK_people_Teachers PRIMARY KEY CLUSTERED (PersonId);
IF OBJECT_ID(N'people.PK_people_RelationshipTypes', N'PK') IS NULL ALTER TABLE people.RelationshipTypes ADD CONSTRAINT PK_people_RelationshipTypes PRIMARY KEY CLUSTERED (RelationshipTypeId);
IF OBJECT_ID(N'people.PK_people_StudentGuardians', N'PK') IS NULL ALTER TABLE people.StudentGuardians ADD CONSTRAINT PK_people_StudentGuardians PRIMARY KEY CLUSTERED (StudentGuardianId);
GO
-- academic
IF OBJECT_ID(N'academic.PK_academic_AcademicYears', N'PK') IS NULL ALTER TABLE academic.AcademicYears ADD CONSTRAINT PK_academic_AcademicYears PRIMARY KEY CLUSTERED (AcademicYearId);
IF OBJECT_ID(N'academic.PK_academic_Terms', N'PK') IS NULL ALTER TABLE academic.Terms ADD CONSTRAINT PK_academic_Terms PRIMARY KEY CLUSTERED (TermId);
IF OBJECT_ID(N'academic.PK_academic_Holidays', N'PK') IS NULL ALTER TABLE academic.Holidays ADD CONSTRAINT PK_academic_Holidays PRIMARY KEY CLUSTERED (HolidayId);
IF OBJECT_ID(N'academic.PK_academic_GradeLevels', N'PK') IS NULL ALTER TABLE academic.GradeLevels ADD CONSTRAINT PK_academic_GradeLevels PRIMARY KEY CLUSTERED (GradeLevelId);
IF OBJECT_ID(N'academic.PK_academic_Programs', N'PK') IS NULL ALTER TABLE academic.Programs ADD CONSTRAINT PK_academic_Programs PRIMARY KEY CLUSTERED (ProgramId);
IF OBJECT_ID(N'academic.PK_academic_Subjects', N'PK') IS NULL ALTER TABLE academic.Subjects ADD CONSTRAINT PK_academic_Subjects PRIMARY KEY CLUSTERED (SubjectId);
IF OBJECT_ID(N'academic.PK_academic_CurriculumSubjects', N'PK') IS NULL ALTER TABLE academic.CurriculumSubjects ADD CONSTRAINT PK_academic_CurriculumSubjects PRIMARY KEY CLUSTERED (CurriculumSubjectId);
IF OBJECT_ID(N'academic.PK_academic_Sections', N'PK') IS NULL ALTER TABLE academic.Sections ADD CONSTRAINT PK_academic_Sections PRIMARY KEY CLUSTERED (SectionId);
IF OBJECT_ID(N'academic.PK_academic_TeachingAssignments', N'PK') IS NULL ALTER TABLE academic.TeachingAssignments ADD CONSTRAINT PK_academic_TeachingAssignments PRIMARY KEY CLUSTERED (TeachingAssignmentId);
GO
-- enrollment
IF OBJECT_ID(N'enrollment.PK_enrollment_Applications', N'PK') IS NULL ALTER TABLE enrollment.Applications ADD CONSTRAINT PK_enrollment_Applications PRIMARY KEY CLUSTERED (ApplicationId);
IF OBJECT_ID(N'enrollment.PK_enrollment_ApplicationStatusHistory', N'PK') IS NULL ALTER TABLE enrollment.ApplicationStatusHistory ADD CONSTRAINT PK_enrollment_ApplicationStatusHistory PRIMARY KEY CLUSTERED (ApplicationStatusHistoryId);
IF OBJECT_ID(N'enrollment.PK_enrollment_Enrollments', N'PK') IS NULL ALTER TABLE enrollment.Enrollments ADD CONSTRAINT PK_enrollment_Enrollments PRIMARY KEY CLUSTERED (EnrollmentId);
IF OBJECT_ID(N'enrollment.PK_enrollment_SectionAssignments', N'PK') IS NULL ALTER TABLE enrollment.SectionAssignments ADD CONSTRAINT PK_enrollment_SectionAssignments PRIMARY KEY CLUSTERED (SectionAssignmentId);
IF OBJECT_ID(N'enrollment.PK_enrollment_EnrollmentSubjects', N'PK') IS NULL ALTER TABLE enrollment.EnrollmentSubjects ADD CONSTRAINT PK_enrollment_EnrollmentSubjects PRIMARY KEY CLUSTERED (EnrollmentSubjectId);
GO
-- timetable
IF OBJECT_ID(N'timetable.PK_timetable_BellSchedules', N'PK') IS NULL ALTER TABLE timetable.BellSchedules ADD CONSTRAINT PK_timetable_BellSchedules PRIMARY KEY CLUSTERED (BellScheduleId);
IF OBJECT_ID(N'timetable.PK_timetable_Periods', N'PK') IS NULL ALTER TABLE timetable.Periods ADD CONSTRAINT PK_timetable_Periods PRIMARY KEY CLUSTERED (PeriodId);
IF OBJECT_ID(N'timetable.PK_timetable_Timetables', N'PK') IS NULL ALTER TABLE timetable.Timetables ADD CONSTRAINT PK_timetable_Timetables PRIMARY KEY CLUSTERED (TimetableId);
IF OBJECT_ID(N'timetable.PK_timetable_TimetableEntries', N'PK') IS NULL ALTER TABLE timetable.TimetableEntries ADD CONSTRAINT PK_timetable_TimetableEntries PRIMARY KEY CLUSTERED (TimetableEntryId);
GO
-- attendance
IF OBJECT_ID(N'attendance.PK_attendance_AttendanceStatuses', N'PK') IS NULL ALTER TABLE attendance.AttendanceStatuses ADD CONSTRAINT PK_attendance_AttendanceStatuses PRIMARY KEY CLUSTERED (AttendanceStatusId);
IF OBJECT_ID(N'attendance.PK_attendance_AttendanceSessions', N'PK') IS NULL ALTER TABLE attendance.AttendanceSessions ADD CONSTRAINT PK_attendance_AttendanceSessions PRIMARY KEY CLUSTERED (AttendanceSessionId);
IF OBJECT_ID(N'attendance.PK_attendance_AttendanceRecords', N'PK') IS NULL ALTER TABLE attendance.AttendanceRecords ADD CONSTRAINT PK_attendance_AttendanceRecords PRIMARY KEY CLUSTERED (AttendanceRecordId);
GO
-- assessment
IF OBJECT_ID(N'assessment.PK_assessment_GradingScales', N'PK') IS NULL ALTER TABLE assessment.GradingScales ADD CONSTRAINT PK_assessment_GradingScales PRIMARY KEY CLUSTERED (GradingScaleId);
IF OBJECT_ID(N'assessment.PK_assessment_GradingScaleBands', N'PK') IS NULL ALTER TABLE assessment.GradingScaleBands ADD CONSTRAINT PK_assessment_GradingScaleBands PRIMARY KEY CLUSTERED (GradingScaleBandId);
IF OBJECT_ID(N'assessment.PK_assessment_AssessmentTypes', N'PK') IS NULL ALTER TABLE assessment.AssessmentTypes ADD CONSTRAINT PK_assessment_AssessmentTypes PRIMARY KEY CLUSTERED (AssessmentTypeId);
IF OBJECT_ID(N'assessment.PK_assessment_AssessmentWeights', N'PK') IS NULL ALTER TABLE assessment.AssessmentWeights ADD CONSTRAINT PK_assessment_AssessmentWeights PRIMARY KEY CLUSTERED (AssessmentWeightId);
IF OBJECT_ID(N'assessment.PK_assessment_Assessments', N'PK') IS NULL ALTER TABLE assessment.Assessments ADD CONSTRAINT PK_assessment_Assessments PRIMARY KEY CLUSTERED (AssessmentId);
IF OBJECT_ID(N'assessment.PK_assessment_AssessmentResults', N'PK') IS NULL ALTER TABLE assessment.AssessmentResults ADD CONSTRAINT PK_assessment_AssessmentResults PRIMARY KEY CLUSTERED (AssessmentResultId);
IF OBJECT_ID(N'assessment.PK_assessment_ReportCards', N'PK') IS NULL ALTER TABLE assessment.ReportCards ADD CONSTRAINT PK_assessment_ReportCards PRIMARY KEY CLUSTERED (ReportCardId);
IF OBJECT_ID(N'assessment.PK_assessment_ReportCardLines', N'PK') IS NULL ALTER TABLE assessment.ReportCardLines ADD CONSTRAINT PK_assessment_ReportCardLines PRIMARY KEY CLUSTERED (ReportCardLineId);
GO
-- finance
IF OBJECT_ID(N'finance.PK_finance_Currencies', N'PK') IS NULL ALTER TABLE finance.Currencies ADD CONSTRAINT PK_finance_Currencies PRIMARY KEY CLUSTERED (CurrencyId);
IF OBJECT_ID(N'finance.PK_finance_FeeTypes', N'PK') IS NULL ALTER TABLE finance.FeeTypes ADD CONSTRAINT PK_finance_FeeTypes PRIMARY KEY CLUSTERED (FeeTypeId);
IF OBJECT_ID(N'finance.PK_finance_FeeStructures', N'PK') IS NULL ALTER TABLE finance.FeeStructures ADD CONSTRAINT PK_finance_FeeStructures PRIMARY KEY CLUSTERED (FeeStructureId);
IF OBJECT_ID(N'finance.PK_finance_FeeStructureItems', N'PK') IS NULL ALTER TABLE finance.FeeStructureItems ADD CONSTRAINT PK_finance_FeeStructureItems PRIMARY KEY CLUSTERED (FeeStructureItemId);
IF OBJECT_ID(N'finance.PK_finance_FeeInstallments', N'PK') IS NULL ALTER TABLE finance.FeeInstallments ADD CONSTRAINT PK_finance_FeeInstallments PRIMARY KEY CLUSTERED (FeeInstallmentId);
IF OBJECT_ID(N'finance.PK_finance_DiscountTypes', N'PK') IS NULL ALTER TABLE finance.DiscountTypes ADD CONSTRAINT PK_finance_DiscountTypes PRIMARY KEY CLUSTERED (DiscountTypeId);
IF OBJECT_ID(N'finance.PK_finance_StudentDiscounts', N'PK') IS NULL ALTER TABLE finance.StudentDiscounts ADD CONSTRAINT PK_finance_StudentDiscounts PRIMARY KEY CLUSTERED (StudentDiscountId);
IF OBJECT_ID(N'finance.PK_finance_Sponsors', N'PK') IS NULL ALTER TABLE finance.Sponsors ADD CONSTRAINT PK_finance_Sponsors PRIMARY KEY CLUSTERED (SponsorId);
IF OBJECT_ID(N'finance.PK_finance_Payers', N'PK') IS NULL ALTER TABLE finance.Payers ADD CONSTRAINT PK_finance_Payers PRIMARY KEY CLUSTERED (PayerId);
IF OBJECT_ID(N'finance.PK_finance_StudentPayers', N'PK') IS NULL ALTER TABLE finance.StudentPayers ADD CONSTRAINT PK_finance_StudentPayers PRIMARY KEY CLUSTERED (StudentPayerId);
IF OBJECT_ID(N'finance.PK_finance_Invoices', N'PK') IS NULL ALTER TABLE finance.Invoices ADD CONSTRAINT PK_finance_Invoices PRIMARY KEY CLUSTERED (InvoiceId);
IF OBJECT_ID(N'finance.PK_finance_InvoiceLines', N'PK') IS NULL ALTER TABLE finance.InvoiceLines ADD CONSTRAINT PK_finance_InvoiceLines PRIMARY KEY CLUSTERED (InvoiceLineId);
IF OBJECT_ID(N'finance.PK_finance_CreditNotes', N'PK') IS NULL ALTER TABLE finance.CreditNotes ADD CONSTRAINT PK_finance_CreditNotes PRIMARY KEY CLUSTERED (CreditNoteId);
IF OBJECT_ID(N'finance.PK_finance_PaymentMethods', N'PK') IS NULL ALTER TABLE finance.PaymentMethods ADD CONSTRAINT PK_finance_PaymentMethods PRIMARY KEY CLUSTERED (PaymentMethodId);
IF OBJECT_ID(N'finance.PK_finance_Payments', N'PK') IS NULL ALTER TABLE finance.Payments ADD CONSTRAINT PK_finance_Payments PRIMARY KEY CLUSTERED (PaymentId);
IF OBJECT_ID(N'finance.PK_finance_PaymentAllocations', N'PK') IS NULL ALTER TABLE finance.PaymentAllocations ADD CONSTRAINT PK_finance_PaymentAllocations PRIMARY KEY CLUSTERED (PaymentAllocationId);
GO
-- audit
IF OBJECT_ID(N'audit.PK_audit_AuditEvents', N'PK') IS NULL ALTER TABLE audit.AuditEvents ADD CONSTRAINT PK_audit_AuditEvents PRIMARY KEY CLUSTERED (AuditEventId);
IF OBJECT_ID(N'audit.PK_audit_SecurityEvents', N'PK') IS NULL ALTER TABLE audit.SecurityEvents ADD CONSTRAINT PK_audit_SecurityEvents PRIMARY KEY CLUSTERED (SecurityEventId);
GO

/* -----------------------------------------------------------------------------
   2. ALTERNATE KEYS referenced by composite foreign keys
      (must exist before the FKs below; all other UNIQUE keys are in 05)
   ----------------------------------------------------------------------------- */
IF OBJECT_ID(N'academic.UQ_Sections_SectionId_AcademicYearId', N'UQ') IS NULL ALTER TABLE academic.Sections ADD CONSTRAINT UQ_Sections_SectionId_AcademicYearId UNIQUE (SectionId, AcademicYearId);
IF OBJECT_ID(N'enrollment.UQ_Enrollments_EnrollmentId_AcademicYearId', N'UQ') IS NULL ALTER TABLE enrollment.Enrollments ADD CONSTRAINT UQ_Enrollments_EnrollmentId_AcademicYearId UNIQUE (EnrollmentId, AcademicYearId);
IF OBJECT_ID(N'attendance.UQ_AttendanceSessions_SessionId_Date_Section', N'UQ') IS NULL ALTER TABLE attendance.AttendanceSessions ADD CONSTRAINT UQ_AttendanceSessions_SessionId_Date_Section UNIQUE (AttendanceSessionId, SessionDate, SectionId);
GO

/* -----------------------------------------------------------------------------
   3. FOREIGN KEYS
   ----------------------------------------------------------------------------- */
-- organization
IF OBJECT_ID(N'organization.FK_Schools_Countries', N'F') IS NULL ALTER TABLE organization.Schools ADD CONSTRAINT FK_Schools_Countries FOREIGN KEY (CountryId) REFERENCES organization.Countries (CountryId);
IF OBJECT_ID(N'organization.FK_Schools_Currencies_DefaultCurrencyId', N'F') IS NULL ALTER TABLE organization.Schools ADD CONSTRAINT FK_Schools_Currencies_DefaultCurrencyId FOREIGN KEY (DefaultCurrencyId) REFERENCES finance.Currencies (CurrencyId);
IF OBJECT_ID(N'organization.FK_Branches_Schools', N'F') IS NULL ALTER TABLE organization.Branches ADD CONSTRAINT FK_Branches_Schools FOREIGN KEY (SchoolId) REFERENCES organization.Schools (SchoolId);
IF OBJECT_ID(N'organization.FK_Buildings_Branches', N'F') IS NULL ALTER TABLE organization.Buildings ADD CONSTRAINT FK_Buildings_Branches FOREIGN KEY (BranchId) REFERENCES organization.Branches (BranchId);
IF OBJECT_ID(N'organization.FK_Rooms_Buildings', N'F') IS NULL ALTER TABLE organization.Rooms ADD CONSTRAINT FK_Rooms_Buildings FOREIGN KEY (BuildingId) REFERENCES organization.Buildings (BuildingId);
IF OBJECT_ID(N'organization.FK_Rooms_RoomTypes', N'F') IS NULL ALTER TABLE organization.Rooms ADD CONSTRAINT FK_Rooms_RoomTypes FOREIGN KEY (RoomTypeId) REFERENCES organization.RoomTypes (RoomTypeId);
IF OBJECT_ID(N'organization.FK_Departments_Schools', N'F') IS NULL ALTER TABLE organization.Departments ADD CONSTRAINT FK_Departments_Schools FOREIGN KEY (SchoolId) REFERENCES organization.Schools (SchoolId);
IF OBJECT_ID(N'organization.FK_DocumentNumberSeries_Branches', N'F') IS NULL ALTER TABLE organization.DocumentNumberSeries ADD CONSTRAINT FK_DocumentNumberSeries_Branches FOREIGN KEY (BranchId) REFERENCES organization.Branches (BranchId);
IF OBJECT_ID(N'organization.FK_DocumentNumberSeries_AcademicYears', N'F') IS NULL ALTER TABLE organization.DocumentNumberSeries ADD CONSTRAINT FK_DocumentNumberSeries_AcademicYears FOREIGN KEY (AcademicYearId) REFERENCES academic.AcademicYears (AcademicYearId);
GO
-- iam
IF OBJECT_ID(N'iam.FK_UserAccounts_Persons', N'F') IS NULL ALTER TABLE iam.UserAccounts ADD CONSTRAINT FK_UserAccounts_Persons FOREIGN KEY (PersonId) REFERENCES people.Persons (PersonId);
IF OBJECT_ID(N'iam.FK_RolePermissions_Roles', N'F') IS NULL ALTER TABLE iam.RolePermissions ADD CONSTRAINT FK_RolePermissions_Roles FOREIGN KEY (RoleId) REFERENCES iam.Roles (RoleId) ON DELETE CASCADE;
IF OBJECT_ID(N'iam.FK_RolePermissions_Permissions', N'F') IS NULL ALTER TABLE iam.RolePermissions ADD CONSTRAINT FK_RolePermissions_Permissions FOREIGN KEY (PermissionId) REFERENCES iam.Permissions (PermissionId) ON DELETE CASCADE;
IF OBJECT_ID(N'iam.FK_UserRoles_UserAccounts', N'F') IS NULL ALTER TABLE iam.UserRoles ADD CONSTRAINT FK_UserRoles_UserAccounts FOREIGN KEY (UserAccountId) REFERENCES iam.UserAccounts (UserAccountId);
IF OBJECT_ID(N'iam.FK_UserRoles_Roles', N'F') IS NULL ALTER TABLE iam.UserRoles ADD CONSTRAINT FK_UserRoles_Roles FOREIGN KEY (RoleId) REFERENCES iam.Roles (RoleId);
IF OBJECT_ID(N'iam.FK_UserRoles_Branches', N'F') IS NULL ALTER TABLE iam.UserRoles ADD CONSTRAINT FK_UserRoles_Branches FOREIGN KEY (BranchId) REFERENCES organization.Branches (BranchId);
GO
-- people
IF OBJECT_ID(N'people.FK_Persons_Countries_NationalityCountryId', N'F') IS NULL ALTER TABLE people.Persons ADD CONSTRAINT FK_Persons_Countries_NationalityCountryId FOREIGN KEY (NationalityCountryId) REFERENCES organization.Countries (CountryId);
IF OBJECT_ID(N'people.FK_PersonContacts_Persons', N'F') IS NULL ALTER TABLE people.PersonContacts ADD CONSTRAINT FK_PersonContacts_Persons FOREIGN KEY (PersonId) REFERENCES people.Persons (PersonId) ON DELETE CASCADE;
IF OBJECT_ID(N'people.FK_PersonAddresses_Persons', N'F') IS NULL ALTER TABLE people.PersonAddresses ADD CONSTRAINT FK_PersonAddresses_Persons FOREIGN KEY (PersonId) REFERENCES people.Persons (PersonId) ON DELETE CASCADE;
IF OBJECT_ID(N'people.FK_PersonAddresses_Countries', N'F') IS NULL ALTER TABLE people.PersonAddresses ADD CONSTRAINT FK_PersonAddresses_Countries FOREIGN KEY (CountryId) REFERENCES organization.Countries (CountryId);
IF OBJECT_ID(N'people.FK_PersonIdentityDocuments_Persons', N'F') IS NULL ALTER TABLE people.PersonIdentityDocuments ADD CONSTRAINT FK_PersonIdentityDocuments_Persons FOREIGN KEY (PersonId) REFERENCES people.Persons (PersonId);
IF OBJECT_ID(N'people.FK_PersonIdentityDocuments_IdentityDocumentTypes', N'F') IS NULL ALTER TABLE people.PersonIdentityDocuments ADD CONSTRAINT FK_PersonIdentityDocuments_IdentityDocumentTypes FOREIGN KEY (IdentityDocumentTypeId) REFERENCES people.IdentityDocumentTypes (IdentityDocumentTypeId);
IF OBJECT_ID(N'people.FK_PersonIdentityDocuments_Countries_IssuingCountryId', N'F') IS NULL ALTER TABLE people.PersonIdentityDocuments ADD CONSTRAINT FK_PersonIdentityDocuments_Countries_IssuingCountryId FOREIGN KEY (IssuingCountryId) REFERENCES organization.Countries (CountryId);
IF OBJECT_ID(N'people.FK_Students_Persons', N'F') IS NULL ALTER TABLE people.Students ADD CONSTRAINT FK_Students_Persons FOREIGN KEY (PersonId) REFERENCES people.Persons (PersonId);
IF OBJECT_ID(N'people.FK_Guardians_Persons', N'F') IS NULL ALTER TABLE people.Guardians ADD CONSTRAINT FK_Guardians_Persons FOREIGN KEY (PersonId) REFERENCES people.Persons (PersonId);
IF OBJECT_ID(N'people.FK_Employees_Persons', N'F') IS NULL ALTER TABLE people.Employees ADD CONSTRAINT FK_Employees_Persons FOREIGN KEY (PersonId) REFERENCES people.Persons (PersonId);
IF OBJECT_ID(N'people.FK_Employees_Departments', N'F') IS NULL ALTER TABLE people.Employees ADD CONSTRAINT FK_Employees_Departments FOREIGN KEY (DepartmentId) REFERENCES organization.Departments (DepartmentId);
IF OBJECT_ID(N'people.FK_Employees_Branches_PrimaryBranchId', N'F') IS NULL ALTER TABLE people.Employees ADD CONSTRAINT FK_Employees_Branches_PrimaryBranchId FOREIGN KEY (PrimaryBranchId) REFERENCES organization.Branches (BranchId);
IF OBJECT_ID(N'people.FK_Teachers_Employees', N'F') IS NULL ALTER TABLE people.Teachers ADD CONSTRAINT FK_Teachers_Employees FOREIGN KEY (PersonId) REFERENCES people.Employees (PersonId);
IF OBJECT_ID(N'people.FK_StudentGuardians_Students_StudentId', N'F') IS NULL ALTER TABLE people.StudentGuardians ADD CONSTRAINT FK_StudentGuardians_Students_StudentId FOREIGN KEY (StudentId) REFERENCES people.Students (PersonId);
IF OBJECT_ID(N'people.FK_StudentGuardians_Guardians_GuardianId', N'F') IS NULL ALTER TABLE people.StudentGuardians ADD CONSTRAINT FK_StudentGuardians_Guardians_GuardianId FOREIGN KEY (GuardianId) REFERENCES people.Guardians (PersonId);
IF OBJECT_ID(N'people.FK_StudentGuardians_RelationshipTypes', N'F') IS NULL ALTER TABLE people.StudentGuardians ADD CONSTRAINT FK_StudentGuardians_RelationshipTypes FOREIGN KEY (RelationshipTypeId) REFERENCES people.RelationshipTypes (RelationshipTypeId);
GO
-- academic
IF OBJECT_ID(N'academic.FK_AcademicYears_Schools', N'F') IS NULL ALTER TABLE academic.AcademicYears ADD CONSTRAINT FK_AcademicYears_Schools FOREIGN KEY (SchoolId) REFERENCES organization.Schools (SchoolId);
IF OBJECT_ID(N'academic.FK_Terms_AcademicYears', N'F') IS NULL ALTER TABLE academic.Terms ADD CONSTRAINT FK_Terms_AcademicYears FOREIGN KEY (AcademicYearId) REFERENCES academic.AcademicYears (AcademicYearId);
IF OBJECT_ID(N'academic.FK_Holidays_AcademicYears', N'F') IS NULL ALTER TABLE academic.Holidays ADD CONSTRAINT FK_Holidays_AcademicYears FOREIGN KEY (AcademicYearId) REFERENCES academic.AcademicYears (AcademicYearId);
IF OBJECT_ID(N'academic.FK_Holidays_Branches', N'F') IS NULL ALTER TABLE academic.Holidays ADD CONSTRAINT FK_Holidays_Branches FOREIGN KEY (BranchId) REFERENCES organization.Branches (BranchId);
IF OBJECT_ID(N'academic.FK_GradeLevels_GradeLevels_NextGradeLevelId', N'F') IS NULL ALTER TABLE academic.GradeLevels ADD CONSTRAINT FK_GradeLevels_GradeLevels_NextGradeLevelId FOREIGN KEY (NextGradeLevelId) REFERENCES academic.GradeLevels (GradeLevelId);
IF OBJECT_ID(N'academic.FK_Subjects_Departments', N'F') IS NULL ALTER TABLE academic.Subjects ADD CONSTRAINT FK_Subjects_Departments FOREIGN KEY (DepartmentId) REFERENCES organization.Departments (DepartmentId);
IF OBJECT_ID(N'academic.FK_CurriculumSubjects_AcademicYears', N'F') IS NULL ALTER TABLE academic.CurriculumSubjects ADD CONSTRAINT FK_CurriculumSubjects_AcademicYears FOREIGN KEY (AcademicYearId) REFERENCES academic.AcademicYears (AcademicYearId);
IF OBJECT_ID(N'academic.FK_CurriculumSubjects_GradeLevels', N'F') IS NULL ALTER TABLE academic.CurriculumSubjects ADD CONSTRAINT FK_CurriculumSubjects_GradeLevels FOREIGN KEY (GradeLevelId) REFERENCES academic.GradeLevels (GradeLevelId);
IF OBJECT_ID(N'academic.FK_CurriculumSubjects_Programs', N'F') IS NULL ALTER TABLE academic.CurriculumSubjects ADD CONSTRAINT FK_CurriculumSubjects_Programs FOREIGN KEY (ProgramId) REFERENCES academic.Programs (ProgramId);
IF OBJECT_ID(N'academic.FK_CurriculumSubjects_Subjects', N'F') IS NULL ALTER TABLE academic.CurriculumSubjects ADD CONSTRAINT FK_CurriculumSubjects_Subjects FOREIGN KEY (SubjectId) REFERENCES academic.Subjects (SubjectId);
IF OBJECT_ID(N'academic.FK_CurriculumSubjects_GradingScales', N'F') IS NULL ALTER TABLE academic.CurriculumSubjects ADD CONSTRAINT FK_CurriculumSubjects_GradingScales FOREIGN KEY (GradingScaleId) REFERENCES assessment.GradingScales (GradingScaleId);
IF OBJECT_ID(N'academic.FK_Sections_AcademicYears', N'F') IS NULL ALTER TABLE academic.Sections ADD CONSTRAINT FK_Sections_AcademicYears FOREIGN KEY (AcademicYearId) REFERENCES academic.AcademicYears (AcademicYearId);
IF OBJECT_ID(N'academic.FK_Sections_Branches', N'F') IS NULL ALTER TABLE academic.Sections ADD CONSTRAINT FK_Sections_Branches FOREIGN KEY (BranchId) REFERENCES organization.Branches (BranchId);
IF OBJECT_ID(N'academic.FK_Sections_GradeLevels', N'F') IS NULL ALTER TABLE academic.Sections ADD CONSTRAINT FK_Sections_GradeLevels FOREIGN KEY (GradeLevelId) REFERENCES academic.GradeLevels (GradeLevelId);
IF OBJECT_ID(N'academic.FK_Sections_Programs', N'F') IS NULL ALTER TABLE academic.Sections ADD CONSTRAINT FK_Sections_Programs FOREIGN KEY (ProgramId) REFERENCES academic.Programs (ProgramId);
IF OBJECT_ID(N'academic.FK_Sections_Teachers_HomeroomTeacherId', N'F') IS NULL ALTER TABLE academic.Sections ADD CONSTRAINT FK_Sections_Teachers_HomeroomTeacherId FOREIGN KEY (HomeroomTeacherId) REFERENCES people.Teachers (PersonId);
IF OBJECT_ID(N'academic.FK_Sections_Rooms_HomeRoomId', N'F') IS NULL ALTER TABLE academic.Sections ADD CONSTRAINT FK_Sections_Rooms_HomeRoomId FOREIGN KEY (HomeRoomId) REFERENCES organization.Rooms (RoomId);
IF OBJECT_ID(N'academic.FK_TeachingAssignments_Sections', N'F') IS NULL ALTER TABLE academic.TeachingAssignments ADD CONSTRAINT FK_TeachingAssignments_Sections FOREIGN KEY (SectionId) REFERENCES academic.Sections (SectionId);
IF OBJECT_ID(N'academic.FK_TeachingAssignments_CurriculumSubjects', N'F') IS NULL ALTER TABLE academic.TeachingAssignments ADD CONSTRAINT FK_TeachingAssignments_CurriculumSubjects FOREIGN KEY (CurriculumSubjectId) REFERENCES academic.CurriculumSubjects (CurriculumSubjectId);
IF OBJECT_ID(N'academic.FK_TeachingAssignments_Teachers_TeacherId', N'F') IS NULL ALTER TABLE academic.TeachingAssignments ADD CONSTRAINT FK_TeachingAssignments_Teachers_TeacherId FOREIGN KEY (TeacherId) REFERENCES people.Teachers (PersonId);
IF OBJECT_ID(N'academic.FK_TeachingAssignments_Terms', N'F') IS NULL ALTER TABLE academic.TeachingAssignments ADD CONSTRAINT FK_TeachingAssignments_Terms FOREIGN KEY (TermId) REFERENCES academic.Terms (TermId);
GO
-- enrollment
IF OBJECT_ID(N'enrollment.FK_Applications_Persons_ApplicantPersonId', N'F') IS NULL ALTER TABLE enrollment.Applications ADD CONSTRAINT FK_Applications_Persons_ApplicantPersonId FOREIGN KEY (ApplicantPersonId) REFERENCES people.Persons (PersonId);
IF OBJECT_ID(N'enrollment.FK_Applications_AcademicYears', N'F') IS NULL ALTER TABLE enrollment.Applications ADD CONSTRAINT FK_Applications_AcademicYears FOREIGN KEY (AcademicYearId) REFERENCES academic.AcademicYears (AcademicYearId);
IF OBJECT_ID(N'enrollment.FK_Applications_Branches', N'F') IS NULL ALTER TABLE enrollment.Applications ADD CONSTRAINT FK_Applications_Branches FOREIGN KEY (BranchId) REFERENCES organization.Branches (BranchId);
IF OBJECT_ID(N'enrollment.FK_Applications_GradeLevels', N'F') IS NULL ALTER TABLE enrollment.Applications ADD CONSTRAINT FK_Applications_GradeLevels FOREIGN KEY (GradeLevelId) REFERENCES academic.GradeLevels (GradeLevelId);
IF OBJECT_ID(N'enrollment.FK_Applications_Programs', N'F') IS NULL ALTER TABLE enrollment.Applications ADD CONSTRAINT FK_Applications_Programs FOREIGN KEY (ProgramId) REFERENCES academic.Programs (ProgramId);
IF OBJECT_ID(N'enrollment.FK_ApplicationStatusHistory_Applications', N'F') IS NULL ALTER TABLE enrollment.ApplicationStatusHistory ADD CONSTRAINT FK_ApplicationStatusHistory_Applications FOREIGN KEY (ApplicationId) REFERENCES enrollment.Applications (ApplicationId);
IF OBJECT_ID(N'enrollment.FK_Enrollments_Students_StudentId', N'F') IS NULL ALTER TABLE enrollment.Enrollments ADD CONSTRAINT FK_Enrollments_Students_StudentId FOREIGN KEY (StudentId) REFERENCES people.Students (PersonId);
IF OBJECT_ID(N'enrollment.FK_Enrollments_AcademicYears', N'F') IS NULL ALTER TABLE enrollment.Enrollments ADD CONSTRAINT FK_Enrollments_AcademicYears FOREIGN KEY (AcademicYearId) REFERENCES academic.AcademicYears (AcademicYearId);
IF OBJECT_ID(N'enrollment.FK_Enrollments_Branches', N'F') IS NULL ALTER TABLE enrollment.Enrollments ADD CONSTRAINT FK_Enrollments_Branches FOREIGN KEY (BranchId) REFERENCES organization.Branches (BranchId);
IF OBJECT_ID(N'enrollment.FK_Enrollments_GradeLevels', N'F') IS NULL ALTER TABLE enrollment.Enrollments ADD CONSTRAINT FK_Enrollments_GradeLevels FOREIGN KEY (GradeLevelId) REFERENCES academic.GradeLevels (GradeLevelId);
IF OBJECT_ID(N'enrollment.FK_Enrollments_Programs', N'F') IS NULL ALTER TABLE enrollment.Enrollments ADD CONSTRAINT FK_Enrollments_Programs FOREIGN KEY (ProgramId) REFERENCES academic.Programs (ProgramId);
IF OBJECT_ID(N'enrollment.FK_Enrollments_Applications', N'F') IS NULL ALTER TABLE enrollment.Enrollments ADD CONSTRAINT FK_Enrollments_Applications FOREIGN KEY (ApplicationId) REFERENCES enrollment.Applications (ApplicationId);
IF OBJECT_ID(N'enrollment.FK_SectionAssignments_Enrollments', N'F') IS NULL ALTER TABLE enrollment.SectionAssignments ADD CONSTRAINT FK_SectionAssignments_Enrollments FOREIGN KEY (EnrollmentId, AcademicYearId) REFERENCES enrollment.Enrollments (EnrollmentId, AcademicYearId);
IF OBJECT_ID(N'enrollment.FK_SectionAssignments_Sections', N'F') IS NULL ALTER TABLE enrollment.SectionAssignments ADD CONSTRAINT FK_SectionAssignments_Sections FOREIGN KEY (SectionId, AcademicYearId) REFERENCES academic.Sections (SectionId, AcademicYearId);
IF OBJECT_ID(N'enrollment.FK_EnrollmentSubjects_Enrollments', N'F') IS NULL ALTER TABLE enrollment.EnrollmentSubjects ADD CONSTRAINT FK_EnrollmentSubjects_Enrollments FOREIGN KEY (EnrollmentId) REFERENCES enrollment.Enrollments (EnrollmentId);
IF OBJECT_ID(N'enrollment.FK_EnrollmentSubjects_CurriculumSubjects', N'F') IS NULL ALTER TABLE enrollment.EnrollmentSubjects ADD CONSTRAINT FK_EnrollmentSubjects_CurriculumSubjects FOREIGN KEY (CurriculumSubjectId) REFERENCES academic.CurriculumSubjects (CurriculumSubjectId);
GO
-- timetable
IF OBJECT_ID(N'timetable.FK_BellSchedules_Branches', N'F') IS NULL ALTER TABLE timetable.BellSchedules ADD CONSTRAINT FK_BellSchedules_Branches FOREIGN KEY (BranchId) REFERENCES organization.Branches (BranchId);
IF OBJECT_ID(N'timetable.FK_BellSchedules_AcademicYears', N'F') IS NULL ALTER TABLE timetable.BellSchedules ADD CONSTRAINT FK_BellSchedules_AcademicYears FOREIGN KEY (AcademicYearId) REFERENCES academic.AcademicYears (AcademicYearId);
IF OBJECT_ID(N'timetable.FK_Periods_BellSchedules', N'F') IS NULL ALTER TABLE timetable.Periods ADD CONSTRAINT FK_Periods_BellSchedules FOREIGN KEY (BellScheduleId) REFERENCES timetable.BellSchedules (BellScheduleId);
IF OBJECT_ID(N'timetable.FK_Timetables_Sections', N'F') IS NULL ALTER TABLE timetable.Timetables ADD CONSTRAINT FK_Timetables_Sections FOREIGN KEY (SectionId) REFERENCES academic.Sections (SectionId);
IF OBJECT_ID(N'timetable.FK_Timetables_Terms', N'F') IS NULL ALTER TABLE timetable.Timetables ADD CONSTRAINT FK_Timetables_Terms FOREIGN KEY (TermId) REFERENCES academic.Terms (TermId);
IF OBJECT_ID(N'timetable.FK_Timetables_BellSchedules', N'F') IS NULL ALTER TABLE timetable.Timetables ADD CONSTRAINT FK_Timetables_BellSchedules FOREIGN KEY (BellScheduleId) REFERENCES timetable.BellSchedules (BellScheduleId);
IF OBJECT_ID(N'timetable.FK_TimetableEntries_Timetables', N'F') IS NULL ALTER TABLE timetable.TimetableEntries ADD CONSTRAINT FK_TimetableEntries_Timetables FOREIGN KEY (TimetableId) REFERENCES timetable.Timetables (TimetableId) ON DELETE CASCADE;
IF OBJECT_ID(N'timetable.FK_TimetableEntries_Periods', N'F') IS NULL ALTER TABLE timetable.TimetableEntries ADD CONSTRAINT FK_TimetableEntries_Periods FOREIGN KEY (PeriodId) REFERENCES timetable.Periods (PeriodId);
IF OBJECT_ID(N'timetable.FK_TimetableEntries_TeachingAssignments', N'F') IS NULL ALTER TABLE timetable.TimetableEntries ADD CONSTRAINT FK_TimetableEntries_TeachingAssignments FOREIGN KEY (TeachingAssignmentId) REFERENCES academic.TeachingAssignments (TeachingAssignmentId);
IF OBJECT_ID(N'timetable.FK_TimetableEntries_Rooms', N'F') IS NULL ALTER TABLE timetable.TimetableEntries ADD CONSTRAINT FK_TimetableEntries_Rooms FOREIGN KEY (RoomId) REFERENCES organization.Rooms (RoomId);
GO
-- attendance
IF OBJECT_ID(N'attendance.FK_AttendanceSessions_Sections', N'F') IS NULL ALTER TABLE attendance.AttendanceSessions ADD CONSTRAINT FK_AttendanceSessions_Sections FOREIGN KEY (SectionId) REFERENCES academic.Sections (SectionId);
IF OBJECT_ID(N'attendance.FK_AttendanceSessions_Periods', N'F') IS NULL ALTER TABLE attendance.AttendanceSessions ADD CONSTRAINT FK_AttendanceSessions_Periods FOREIGN KEY (PeriodId) REFERENCES timetable.Periods (PeriodId);
IF OBJECT_ID(N'attendance.FK_AttendanceSessions_Employees_TakenByEmployeeId', N'F') IS NULL ALTER TABLE attendance.AttendanceSessions ADD CONSTRAINT FK_AttendanceSessions_Employees_TakenByEmployeeId FOREIGN KEY (TakenByEmployeeId) REFERENCES people.Employees (PersonId);
IF OBJECT_ID(N'attendance.FK_AttendanceRecords_AttendanceSessions', N'F') IS NULL ALTER TABLE attendance.AttendanceRecords ADD CONSTRAINT FK_AttendanceRecords_AttendanceSessions FOREIGN KEY (AttendanceSessionId, SessionDate, SectionId) REFERENCES attendance.AttendanceSessions (AttendanceSessionId, SessionDate, SectionId);
IF OBJECT_ID(N'attendance.FK_AttendanceRecords_Enrollments', N'F') IS NULL ALTER TABLE attendance.AttendanceRecords ADD CONSTRAINT FK_AttendanceRecords_Enrollments FOREIGN KEY (EnrollmentId) REFERENCES enrollment.Enrollments (EnrollmentId);
IF OBJECT_ID(N'attendance.FK_AttendanceRecords_AttendanceStatuses', N'F') IS NULL ALTER TABLE attendance.AttendanceRecords ADD CONSTRAINT FK_AttendanceRecords_AttendanceStatuses FOREIGN KEY (AttendanceStatusId) REFERENCES attendance.AttendanceStatuses (AttendanceStatusId);
GO
-- assessment
IF OBJECT_ID(N'assessment.FK_GradingScaleBands_GradingScales', N'F') IS NULL ALTER TABLE assessment.GradingScaleBands ADD CONSTRAINT FK_GradingScaleBands_GradingScales FOREIGN KEY (GradingScaleId) REFERENCES assessment.GradingScales (GradingScaleId);
IF OBJECT_ID(N'assessment.FK_AssessmentWeights_CurriculumSubjects', N'F') IS NULL ALTER TABLE assessment.AssessmentWeights ADD CONSTRAINT FK_AssessmentWeights_CurriculumSubjects FOREIGN KEY (CurriculumSubjectId) REFERENCES academic.CurriculumSubjects (CurriculumSubjectId);
IF OBJECT_ID(N'assessment.FK_AssessmentWeights_Terms', N'F') IS NULL ALTER TABLE assessment.AssessmentWeights ADD CONSTRAINT FK_AssessmentWeights_Terms FOREIGN KEY (TermId) REFERENCES academic.Terms (TermId);
IF OBJECT_ID(N'assessment.FK_AssessmentWeights_AssessmentTypes', N'F') IS NULL ALTER TABLE assessment.AssessmentWeights ADD CONSTRAINT FK_AssessmentWeights_AssessmentTypes FOREIGN KEY (AssessmentTypeId) REFERENCES assessment.AssessmentTypes (AssessmentTypeId);
IF OBJECT_ID(N'assessment.FK_Assessments_TeachingAssignments', N'F') IS NULL ALTER TABLE assessment.Assessments ADD CONSTRAINT FK_Assessments_TeachingAssignments FOREIGN KEY (TeachingAssignmentId) REFERENCES academic.TeachingAssignments (TeachingAssignmentId);
IF OBJECT_ID(N'assessment.FK_Assessments_Terms', N'F') IS NULL ALTER TABLE assessment.Assessments ADD CONSTRAINT FK_Assessments_Terms FOREIGN KEY (TermId) REFERENCES academic.Terms (TermId);
IF OBJECT_ID(N'assessment.FK_Assessments_AssessmentTypes', N'F') IS NULL ALTER TABLE assessment.Assessments ADD CONSTRAINT FK_Assessments_AssessmentTypes FOREIGN KEY (AssessmentTypeId) REFERENCES assessment.AssessmentTypes (AssessmentTypeId);
IF OBJECT_ID(N'assessment.FK_AssessmentResults_Assessments', N'F') IS NULL ALTER TABLE assessment.AssessmentResults ADD CONSTRAINT FK_AssessmentResults_Assessments FOREIGN KEY (AssessmentId) REFERENCES assessment.Assessments (AssessmentId);
IF OBJECT_ID(N'assessment.FK_AssessmentResults_Enrollments', N'F') IS NULL ALTER TABLE assessment.AssessmentResults ADD CONSTRAINT FK_AssessmentResults_Enrollments FOREIGN KEY (EnrollmentId) REFERENCES enrollment.Enrollments (EnrollmentId);
IF OBJECT_ID(N'assessment.FK_ReportCards_Enrollments', N'F') IS NULL ALTER TABLE assessment.ReportCards ADD CONSTRAINT FK_ReportCards_Enrollments FOREIGN KEY (EnrollmentId) REFERENCES enrollment.Enrollments (EnrollmentId);
IF OBJECT_ID(N'assessment.FK_ReportCards_Terms', N'F') IS NULL ALTER TABLE assessment.ReportCards ADD CONSTRAINT FK_ReportCards_Terms FOREIGN KEY (TermId) REFERENCES academic.Terms (TermId);
IF OBJECT_ID(N'assessment.FK_ReportCardLines_ReportCards', N'F') IS NULL ALTER TABLE assessment.ReportCardLines ADD CONSTRAINT FK_ReportCardLines_ReportCards FOREIGN KEY (ReportCardId) REFERENCES assessment.ReportCards (ReportCardId);
IF OBJECT_ID(N'assessment.FK_ReportCardLines_CurriculumSubjects', N'F') IS NULL ALTER TABLE assessment.ReportCardLines ADD CONSTRAINT FK_ReportCardLines_CurriculumSubjects FOREIGN KEY (CurriculumSubjectId) REFERENCES academic.CurriculumSubjects (CurriculumSubjectId);
GO
-- finance
IF OBJECT_ID(N'finance.FK_FeeStructures_AcademicYears', N'F') IS NULL ALTER TABLE finance.FeeStructures ADD CONSTRAINT FK_FeeStructures_AcademicYears FOREIGN KEY (AcademicYearId) REFERENCES academic.AcademicYears (AcademicYearId);
IF OBJECT_ID(N'finance.FK_FeeStructures_Branches', N'F') IS NULL ALTER TABLE finance.FeeStructures ADD CONSTRAINT FK_FeeStructures_Branches FOREIGN KEY (BranchId) REFERENCES organization.Branches (BranchId);
IF OBJECT_ID(N'finance.FK_FeeStructures_GradeLevels', N'F') IS NULL ALTER TABLE finance.FeeStructures ADD CONSTRAINT FK_FeeStructures_GradeLevels FOREIGN KEY (GradeLevelId) REFERENCES academic.GradeLevels (GradeLevelId);
IF OBJECT_ID(N'finance.FK_FeeStructures_Programs', N'F') IS NULL ALTER TABLE finance.FeeStructures ADD CONSTRAINT FK_FeeStructures_Programs FOREIGN KEY (ProgramId) REFERENCES academic.Programs (ProgramId);
IF OBJECT_ID(N'finance.FK_FeeStructures_Currencies', N'F') IS NULL ALTER TABLE finance.FeeStructures ADD CONSTRAINT FK_FeeStructures_Currencies FOREIGN KEY (CurrencyId) REFERENCES finance.Currencies (CurrencyId);
IF OBJECT_ID(N'finance.FK_FeeStructureItems_FeeStructures', N'F') IS NULL ALTER TABLE finance.FeeStructureItems ADD CONSTRAINT FK_FeeStructureItems_FeeStructures FOREIGN KEY (FeeStructureId) REFERENCES finance.FeeStructures (FeeStructureId);
IF OBJECT_ID(N'finance.FK_FeeStructureItems_FeeTypes', N'F') IS NULL ALTER TABLE finance.FeeStructureItems ADD CONSTRAINT FK_FeeStructureItems_FeeTypes FOREIGN KEY (FeeTypeId) REFERENCES finance.FeeTypes (FeeTypeId);
IF OBJECT_ID(N'finance.FK_FeeInstallments_FeeStructures', N'F') IS NULL ALTER TABLE finance.FeeInstallments ADD CONSTRAINT FK_FeeInstallments_FeeStructures FOREIGN KEY (FeeStructureId) REFERENCES finance.FeeStructures (FeeStructureId);
IF OBJECT_ID(N'finance.FK_StudentDiscounts_Enrollments', N'F') IS NULL ALTER TABLE finance.StudentDiscounts ADD CONSTRAINT FK_StudentDiscounts_Enrollments FOREIGN KEY (EnrollmentId) REFERENCES enrollment.Enrollments (EnrollmentId);
IF OBJECT_ID(N'finance.FK_StudentDiscounts_DiscountTypes', N'F') IS NULL ALTER TABLE finance.StudentDiscounts ADD CONSTRAINT FK_StudentDiscounts_DiscountTypes FOREIGN KEY (DiscountTypeId) REFERENCES finance.DiscountTypes (DiscountTypeId);
IF OBJECT_ID(N'finance.FK_StudentDiscounts_FeeTypes', N'F') IS NULL ALTER TABLE finance.StudentDiscounts ADD CONSTRAINT FK_StudentDiscounts_FeeTypes FOREIGN KEY (FeeTypeId) REFERENCES finance.FeeTypes (FeeTypeId);
IF OBJECT_ID(N'finance.FK_Payers_Guardians_GuardianId', N'F') IS NULL ALTER TABLE finance.Payers ADD CONSTRAINT FK_Payers_Guardians_GuardianId FOREIGN KEY (GuardianId) REFERENCES people.Guardians (PersonId);
IF OBJECT_ID(N'finance.FK_Payers_Sponsors', N'F') IS NULL ALTER TABLE finance.Payers ADD CONSTRAINT FK_Payers_Sponsors FOREIGN KEY (SponsorId) REFERENCES finance.Sponsors (SponsorId);
IF OBJECT_ID(N'finance.FK_StudentPayers_Enrollments', N'F') IS NULL ALTER TABLE finance.StudentPayers ADD CONSTRAINT FK_StudentPayers_Enrollments FOREIGN KEY (EnrollmentId) REFERENCES enrollment.Enrollments (EnrollmentId);
IF OBJECT_ID(N'finance.FK_StudentPayers_Payers', N'F') IS NULL ALTER TABLE finance.StudentPayers ADD CONSTRAINT FK_StudentPayers_Payers FOREIGN KEY (PayerId) REFERENCES finance.Payers (PayerId);
IF OBJECT_ID(N'finance.FK_Invoices_Branches', N'F') IS NULL ALTER TABLE finance.Invoices ADD CONSTRAINT FK_Invoices_Branches FOREIGN KEY (BranchId) REFERENCES organization.Branches (BranchId);
IF OBJECT_ID(N'finance.FK_Invoices_Enrollments', N'F') IS NULL ALTER TABLE finance.Invoices ADD CONSTRAINT FK_Invoices_Enrollments FOREIGN KEY (EnrollmentId) REFERENCES enrollment.Enrollments (EnrollmentId);
IF OBJECT_ID(N'finance.FK_Invoices_Payers', N'F') IS NULL ALTER TABLE finance.Invoices ADD CONSTRAINT FK_Invoices_Payers FOREIGN KEY (PayerId) REFERENCES finance.Payers (PayerId);
IF OBJECT_ID(N'finance.FK_Invoices_FeeInstallments', N'F') IS NULL ALTER TABLE finance.Invoices ADD CONSTRAINT FK_Invoices_FeeInstallments FOREIGN KEY (FeeInstallmentId) REFERENCES finance.FeeInstallments (FeeInstallmentId);
IF OBJECT_ID(N'finance.FK_Invoices_Currencies', N'F') IS NULL ALTER TABLE finance.Invoices ADD CONSTRAINT FK_Invoices_Currencies FOREIGN KEY (CurrencyId) REFERENCES finance.Currencies (CurrencyId);
IF OBJECT_ID(N'finance.FK_InvoiceLines_Invoices', N'F') IS NULL ALTER TABLE finance.InvoiceLines ADD CONSTRAINT FK_InvoiceLines_Invoices FOREIGN KEY (InvoiceId) REFERENCES finance.Invoices (InvoiceId);
IF OBJECT_ID(N'finance.FK_InvoiceLines_FeeTypes', N'F') IS NULL ALTER TABLE finance.InvoiceLines ADD CONSTRAINT FK_InvoiceLines_FeeTypes FOREIGN KEY (FeeTypeId) REFERENCES finance.FeeTypes (FeeTypeId);
IF OBJECT_ID(N'finance.FK_CreditNotes_Invoices', N'F') IS NULL ALTER TABLE finance.CreditNotes ADD CONSTRAINT FK_CreditNotes_Invoices FOREIGN KEY (InvoiceId) REFERENCES finance.Invoices (InvoiceId);
IF OBJECT_ID(N'finance.FK_Payments_Branches', N'F') IS NULL ALTER TABLE finance.Payments ADD CONSTRAINT FK_Payments_Branches FOREIGN KEY (BranchId) REFERENCES organization.Branches (BranchId);
IF OBJECT_ID(N'finance.FK_Payments_Payers', N'F') IS NULL ALTER TABLE finance.Payments ADD CONSTRAINT FK_Payments_Payers FOREIGN KEY (PayerId) REFERENCES finance.Payers (PayerId);
IF OBJECT_ID(N'finance.FK_Payments_PaymentMethods', N'F') IS NULL ALTER TABLE finance.Payments ADD CONSTRAINT FK_Payments_PaymentMethods FOREIGN KEY (PaymentMethodId) REFERENCES finance.PaymentMethods (PaymentMethodId);
IF OBJECT_ID(N'finance.FK_Payments_Currencies', N'F') IS NULL ALTER TABLE finance.Payments ADD CONSTRAINT FK_Payments_Currencies FOREIGN KEY (CurrencyId) REFERENCES finance.Currencies (CurrencyId);
IF OBJECT_ID(N'finance.FK_PaymentAllocations_Payments', N'F') IS NULL ALTER TABLE finance.PaymentAllocations ADD CONSTRAINT FK_PaymentAllocations_Payments FOREIGN KEY (PaymentId) REFERENCES finance.Payments (PaymentId);
IF OBJECT_ID(N'finance.FK_PaymentAllocations_Invoices', N'F') IS NULL ALTER TABLE finance.PaymentAllocations ADD CONSTRAINT FK_PaymentAllocations_Invoices FOREIGN KEY (InvoiceId) REFERENCES finance.Invoices (InvoiceId);
GO

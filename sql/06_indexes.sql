/* =============================================================================
   06_indexes.sql
   Purpose     : Nonclustered indexes: every FK column that is not already the
                 leading column of a PK/UNIQUE index, real access-path
                 (composite / covering) indexes, and filtered (unique) indexes
                 for business rules. Also renames the clustered indexes that SQL
                 Server auto-creates on temporal history tables.
   Dependencies: 05_constraints.sql
   Run order   : 6 of 12
   Idempotent  : Yes (IF NOT EXISTS on sys.indexes).
   Notes       : FK columns already covered by a PK/UQ leading column are listed
                 in docs/PHYSICAL_MODEL.md; 12_validation_queries.sql reports any
                 FK without a supporting index.
   ============================================================================= */
USE [$(DatabaseName)];
GO

/* ---------------------------------------------------------------- organization */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'organization.Schools') AND name = N'IX_Schools_CountryId') CREATE NONCLUSTERED INDEX IX_Schools_CountryId ON organization.Schools (CountryId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'organization.Schools') AND name = N'IX_Schools_DefaultCurrencyId') CREATE NONCLUSTERED INDEX IX_Schools_DefaultCurrencyId ON organization.Schools (DefaultCurrencyId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'organization.Rooms') AND name = N'IX_Rooms_RoomTypeId') CREATE NONCLUSTERED INDEX IX_Rooms_RoomTypeId ON organization.Rooms (RoomTypeId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'organization.DocumentNumberSeries') AND name = N'IX_DocumentNumberSeries_BranchId') CREATE NONCLUSTERED INDEX IX_DocumentNumberSeries_BranchId ON organization.DocumentNumberSeries (BranchId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'organization.DocumentNumberSeries') AND name = N'IX_DocumentNumberSeries_AcademicYearId') CREATE NONCLUSTERED INDEX IX_DocumentNumberSeries_AcademicYearId ON organization.DocumentNumberSeries (AcademicYearId);
GO

/* ------------------------------------------------------------------------- iam */
-- A person has at most one user account (filtered: accounts without a person are allowed).
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'iam.UserAccounts') AND name = N'IX_UserAccounts_PersonId') CREATE UNIQUE NONCLUSTERED INDEX IX_UserAccounts_PersonId ON iam.UserAccounts (PersonId) WHERE PersonId IS NOT NULL;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'iam.UserAccounts') AND name = N'IX_UserAccounts_Email') CREATE UNIQUE NONCLUSTERED INDEX IX_UserAccounts_Email ON iam.UserAccounts (Email) WHERE Email IS NOT NULL;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'iam.UserAccounts') AND name = N'IX_UserAccounts_ExternalSubjectId') CREATE UNIQUE NONCLUSTERED INDEX IX_UserAccounts_ExternalSubjectId ON iam.UserAccounts (AuthProvider, ExternalSubjectId) WHERE ExternalSubjectId IS NOT NULL;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'iam.RolePermissions') AND name = N'IX_RolePermissions_PermissionId') CREATE NONCLUSTERED INDEX IX_RolePermissions_PermissionId ON iam.RolePermissions (PermissionId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'iam.UserRoles') AND name = N'IX_UserRoles_RoleId') CREATE NONCLUSTERED INDEX IX_UserRoles_RoleId ON iam.UserRoles (RoleId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'iam.UserRoles') AND name = N'IX_UserRoles_BranchId') CREATE NONCLUSTERED INDEX IX_UserRoles_BranchId ON iam.UserRoles (BranchId);
GO

/* ---------------------------------------------------------------------- people */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'people.Persons') AND name = N'IX_Persons_NationalityCountryId') CREATE NONCLUSTERED INDEX IX_Persons_NationalityCountryId ON people.Persons (NationalityCountryId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'people.Persons') AND name = N'IX_Persons_NameEn') CREATE NONCLUSTERED INDEX IX_Persons_NameEn ON people.Persons (FamilyNameEn, FirstNameEn) INCLUDE (FatherNameEn);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'people.Persons') AND name = N'IX_Persons_NameAr') CREATE NONCLUSTERED INDEX IX_Persons_NameAr ON people.Persons (FamilyNameAr, FirstNameAr) INCLUDE (FatherNameAr);
-- One primary contact per person per contact type.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'people.PersonContacts') AND name = N'IX_PersonContacts_PrimaryPerType') CREATE UNIQUE NONCLUSTERED INDEX IX_PersonContacts_PrimaryPerType ON people.PersonContacts (PersonId, ContactType) WHERE IsPrimary = 1;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'people.PersonContacts') AND name = N'IX_PersonContacts_ContactValue') CREATE NONCLUSTERED INDEX IX_PersonContacts_ContactValue ON people.PersonContacts (ContactValue) INCLUDE (PersonId, ContactType);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'people.PersonAddresses') AND name = N'IX_PersonAddresses_PersonId') CREATE NONCLUSTERED INDEX IX_PersonAddresses_PersonId ON people.PersonAddresses (PersonId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'people.PersonAddresses') AND name = N'IX_PersonAddresses_CountryId') CREATE NONCLUSTERED INDEX IX_PersonAddresses_CountryId ON people.PersonAddresses (CountryId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'people.PersonIdentityDocuments') AND name = N'IX_PersonIdentityDocuments_PersonId') CREATE NONCLUSTERED INDEX IX_PersonIdentityDocuments_PersonId ON people.PersonIdentityDocuments (PersonId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'people.PersonIdentityDocuments') AND name = N'IX_PersonIdentityDocuments_IssuingCountryId') CREATE NONCLUSTERED INDEX IX_PersonIdentityDocuments_IssuingCountryId ON people.PersonIdentityDocuments (IssuingCountryId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'people.Employees') AND name = N'IX_Employees_DepartmentId') CREATE NONCLUSTERED INDEX IX_Employees_DepartmentId ON people.Employees (DepartmentId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'people.Employees') AND name = N'IX_Employees_PrimaryBranchId') CREATE NONCLUSTERED INDEX IX_Employees_PrimaryBranchId ON people.Employees (PrimaryBranchId) INCLUDE (EmploymentStatus);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'people.StudentGuardians') AND name = N'IX_StudentGuardians_GuardianId') CREATE NONCLUSTERED INDEX IX_StudentGuardians_GuardianId ON people.StudentGuardians (GuardianId) INCLUDE (StudentId, RelationshipTypeId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'people.StudentGuardians') AND name = N'IX_StudentGuardians_RelationshipTypeId') CREATE NONCLUSTERED INDEX IX_StudentGuardians_RelationshipTypeId ON people.StudentGuardians (RelationshipTypeId);
-- At most one primary-contact guardian per student.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'people.StudentGuardians') AND name = N'IX_StudentGuardians_PrimaryContact') CREATE UNIQUE NONCLUSTERED INDEX IX_StudentGuardians_PrimaryContact ON people.StudentGuardians (StudentId) WHERE IsPrimaryContact = 1;
GO

/* -------------------------------------------------------------------- academic */
-- At most one Active academic year per school.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'academic.AcademicYears') AND name = N'IX_AcademicYears_ActivePerSchool') CREATE UNIQUE NONCLUSTERED INDEX IX_AcademicYears_ActivePerSchool ON academic.AcademicYears (SchoolId) WHERE YearStatus = N'Active';
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'academic.Holidays') AND name = N'IX_Holidays_AcademicYearId_StartDate') CREATE NONCLUSTERED INDEX IX_Holidays_AcademicYearId_StartDate ON academic.Holidays (AcademicYearId, StartDate) INCLUDE (EndDate, BranchId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'academic.Holidays') AND name = N'IX_Holidays_BranchId') CREATE NONCLUSTERED INDEX IX_Holidays_BranchId ON academic.Holidays (BranchId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'academic.GradeLevels') AND name = N'IX_GradeLevels_NextGradeLevelId') CREATE NONCLUSTERED INDEX IX_GradeLevels_NextGradeLevelId ON academic.GradeLevels (NextGradeLevelId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'academic.Subjects') AND name = N'IX_Subjects_DepartmentId') CREATE NONCLUSTERED INDEX IX_Subjects_DepartmentId ON academic.Subjects (DepartmentId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'academic.CurriculumSubjects') AND name = N'IX_CurriculumSubjects_GradeLevelId') CREATE NONCLUSTERED INDEX IX_CurriculumSubjects_GradeLevelId ON academic.CurriculumSubjects (GradeLevelId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'academic.CurriculumSubjects') AND name = N'IX_CurriculumSubjects_ProgramId') CREATE NONCLUSTERED INDEX IX_CurriculumSubjects_ProgramId ON academic.CurriculumSubjects (ProgramId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'academic.CurriculumSubjects') AND name = N'IX_CurriculumSubjects_SubjectId') CREATE NONCLUSTERED INDEX IX_CurriculumSubjects_SubjectId ON academic.CurriculumSubjects (SubjectId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'academic.CurriculumSubjects') AND name = N'IX_CurriculumSubjects_GradingScaleId') CREATE NONCLUSTERED INDEX IX_CurriculumSubjects_GradingScaleId ON academic.CurriculumSubjects (GradingScaleId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'academic.Sections') AND name = N'IX_Sections_BranchId') CREATE NONCLUSTERED INDEX IX_Sections_BranchId ON academic.Sections (BranchId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'academic.Sections') AND name = N'IX_Sections_GradeLevelId') CREATE NONCLUSTERED INDEX IX_Sections_GradeLevelId ON academic.Sections (GradeLevelId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'academic.Sections') AND name = N'IX_Sections_ProgramId') CREATE NONCLUSTERED INDEX IX_Sections_ProgramId ON academic.Sections (ProgramId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'academic.Sections') AND name = N'IX_Sections_HomeroomTeacherId') CREATE NONCLUSTERED INDEX IX_Sections_HomeroomTeacherId ON academic.Sections (HomeroomTeacherId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'academic.Sections') AND name = N'IX_Sections_HomeRoomId') CREATE NONCLUSTERED INDEX IX_Sections_HomeRoomId ON academic.Sections (HomeRoomId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'academic.TeachingAssignments') AND name = N'IX_TeachingAssignments_CurriculumSubjectId') CREATE NONCLUSTERED INDEX IX_TeachingAssignments_CurriculumSubjectId ON academic.TeachingAssignments (CurriculumSubjectId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'academic.TeachingAssignments') AND name = N'IX_TeachingAssignments_TeacherId') CREATE NONCLUSTERED INDEX IX_TeachingAssignments_TeacherId ON academic.TeachingAssignments (TeacherId) INCLUDE (SectionId, CurriculumSubjectId, TermId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'academic.TeachingAssignments') AND name = N'IX_TeachingAssignments_TermId') CREATE NONCLUSTERED INDEX IX_TeachingAssignments_TermId ON academic.TeachingAssignments (TermId);
GO

/* ------------------------------------------------------------------ enrollment */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'enrollment.Applications') AND name = N'IX_Applications_ApplicantPersonId') CREATE NONCLUSTERED INDEX IX_Applications_ApplicantPersonId ON enrollment.Applications (ApplicantPersonId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'enrollment.Applications') AND name = N'IX_Applications_Year_Status') CREATE NONCLUSTERED INDEX IX_Applications_Year_Status ON enrollment.Applications (AcademicYearId, ApplicationStatus) INCLUDE (BranchId, GradeLevelId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'enrollment.Applications') AND name = N'IX_Applications_BranchId') CREATE NONCLUSTERED INDEX IX_Applications_BranchId ON enrollment.Applications (BranchId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'enrollment.Applications') AND name = N'IX_Applications_GradeLevelId') CREATE NONCLUSTERED INDEX IX_Applications_GradeLevelId ON enrollment.Applications (GradeLevelId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'enrollment.Applications') AND name = N'IX_Applications_ProgramId') CREATE NONCLUSTERED INDEX IX_Applications_ProgramId ON enrollment.Applications (ProgramId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'enrollment.ApplicationStatusHistory') AND name = N'IX_ApplicationStatusHistory_ApplicationId') CREATE NONCLUSTERED INDEX IX_ApplicationStatusHistory_ApplicationId ON enrollment.ApplicationStatusHistory (ApplicationId, ChangedAt);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'enrollment.Enrollments') AND name = N'IX_Enrollments_Year_Branch_Grade') CREATE NONCLUSTERED INDEX IX_Enrollments_Year_Branch_Grade ON enrollment.Enrollments (AcademicYearId, BranchId, GradeLevelId) INCLUDE (StudentId, EnrollmentStatus);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'enrollment.Enrollments') AND name = N'IX_Enrollments_BranchId') CREATE NONCLUSTERED INDEX IX_Enrollments_BranchId ON enrollment.Enrollments (BranchId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'enrollment.Enrollments') AND name = N'IX_Enrollments_GradeLevelId') CREATE NONCLUSTERED INDEX IX_Enrollments_GradeLevelId ON enrollment.Enrollments (GradeLevelId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'enrollment.Enrollments') AND name = N'IX_Enrollments_ProgramId') CREATE NONCLUSTERED INDEX IX_Enrollments_ProgramId ON enrollment.Enrollments (ProgramId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'enrollment.Enrollments') AND name = N'IX_Enrollments_ApplicationId') CREATE NONCLUSTERED INDEX IX_Enrollments_ApplicationId ON enrollment.Enrollments (ApplicationId) WHERE ApplicationId IS NOT NULL;
-- At most one open (EndDate IS NULL) section assignment per enrollment.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'enrollment.SectionAssignments') AND name = N'IX_SectionAssignments_OpenPerEnrollment') CREATE UNIQUE NONCLUSTERED INDEX IX_SectionAssignments_OpenPerEnrollment ON enrollment.SectionAssignments (EnrollmentId) WHERE EndDate IS NULL;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'enrollment.SectionAssignments') AND name = N'IX_SectionAssignments_Enrollment_Year') CREATE NONCLUSTERED INDEX IX_SectionAssignments_Enrollment_Year ON enrollment.SectionAssignments (EnrollmentId, AcademicYearId) INCLUDE (SectionId, StartDate, EndDate);
-- Section roster path.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'enrollment.SectionAssignments') AND name = N'IX_SectionAssignments_Section_Year') CREATE NONCLUSTERED INDEX IX_SectionAssignments_Section_Year ON enrollment.SectionAssignments (SectionId, AcademicYearId) INCLUDE (EnrollmentId, StartDate, EndDate);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'enrollment.EnrollmentSubjects') AND name = N'IX_EnrollmentSubjects_CurriculumSubjectId') CREATE NONCLUSTERED INDEX IX_EnrollmentSubjects_CurriculumSubjectId ON enrollment.EnrollmentSubjects (CurriculumSubjectId);
GO

/* ------------------------------------------------------------------- timetable */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'timetable.BellSchedules') AND name = N'IX_BellSchedules_AcademicYearId') CREATE NONCLUSTERED INDEX IX_BellSchedules_AcademicYearId ON timetable.BellSchedules (AcademicYearId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'timetable.Timetables') AND name = N'IX_Timetables_TermId') CREATE NONCLUSTERED INDEX IX_Timetables_TermId ON timetable.Timetables (TermId) INCLUDE (SectionId, TimetableStatus);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'timetable.Timetables') AND name = N'IX_Timetables_BellScheduleId') CREATE NONCLUSTERED INDEX IX_Timetables_BellScheduleId ON timetable.Timetables (BellScheduleId);
-- One published timetable per section and term.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'timetable.Timetables') AND name = N'IX_Timetables_PublishedPerSectionTerm') CREATE UNIQUE NONCLUSTERED INDEX IX_Timetables_PublishedPerSectionTerm ON timetable.Timetables (SectionId, TermId) WHERE TimetableStatus = N'Published';
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'timetable.TimetableEntries') AND name = N'IX_TimetableEntries_PeriodId') CREATE NONCLUSTERED INDEX IX_TimetableEntries_PeriodId ON timetable.TimetableEntries (PeriodId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'timetable.TimetableEntries') AND name = N'IX_TimetableEntries_TeachingAssignmentId') CREATE NONCLUSTERED INDEX IX_TimetableEntries_TeachingAssignmentId ON timetable.TimetableEntries (TeachingAssignmentId) INCLUDE (DayOfWeek, PeriodId);
-- Room clash detection path.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'timetable.TimetableEntries') AND name = N'IX_TimetableEntries_Room_Day_Period') CREATE NONCLUSTERED INDEX IX_TimetableEntries_Room_Day_Period ON timetable.TimetableEntries (RoomId, DayOfWeek, PeriodId) INCLUDE (TimetableId);
GO

/* ------------------------------------------------------------------ attendance */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'attendance.AttendanceSessions') AND name = N'IX_AttendanceSessions_PeriodId') CREATE NONCLUSTERED INDEX IX_AttendanceSessions_PeriodId ON attendance.AttendanceSessions (PeriodId) WHERE PeriodId IS NOT NULL;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'attendance.AttendanceSessions') AND name = N'IX_AttendanceSessions_TakenByEmployeeId') CREATE NONCLUSTERED INDEX IX_AttendanceSessions_TakenByEmployeeId ON attendance.AttendanceSessions (TakenByEmployeeId);
-- Attendance by student (enrollment) + date.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'attendance.AttendanceRecords') AND name = N'IX_AttendanceRecords_Enrollment_Date') CREATE NONCLUSTERED INDEX IX_AttendanceRecords_Enrollment_Date ON attendance.AttendanceRecords (EnrollmentId, SessionDate) INCLUDE (AttendanceStatusId, MinutesLate);
-- Attendance by section + date.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'attendance.AttendanceRecords') AND name = N'IX_AttendanceRecords_Section_Date') CREATE NONCLUSTERED INDEX IX_AttendanceRecords_Section_Date ON attendance.AttendanceRecords (SectionId, SessionDate) INCLUDE (EnrollmentId, AttendanceStatusId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'attendance.AttendanceRecords') AND name = N'IX_AttendanceRecords_AttendanceStatusId') CREATE NONCLUSTERED INDEX IX_AttendanceRecords_AttendanceStatusId ON attendance.AttendanceRecords (AttendanceStatusId);
GO

/* ------------------------------------------------------------------ assessment */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'assessment.AssessmentWeights') AND name = N'IX_AssessmentWeights_TermId') CREATE NONCLUSTERED INDEX IX_AssessmentWeights_TermId ON assessment.AssessmentWeights (TermId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'assessment.AssessmentWeights') AND name = N'IX_AssessmentWeights_AssessmentTypeId') CREATE NONCLUSTERED INDEX IX_AssessmentWeights_AssessmentTypeId ON assessment.AssessmentWeights (AssessmentTypeId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'assessment.Assessments') AND name = N'IX_Assessments_TeachingAssignment_Term') CREATE NONCLUSTERED INDEX IX_Assessments_TeachingAssignment_Term ON assessment.Assessments (TeachingAssignmentId, TermId) INCLUDE (AssessmentTypeId, MaxScore, AssessmentDate);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'assessment.Assessments') AND name = N'IX_Assessments_TermId') CREATE NONCLUSTERED INDEX IX_Assessments_TermId ON assessment.Assessments (TermId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'assessment.Assessments') AND name = N'IX_Assessments_AssessmentTypeId') CREATE NONCLUSTERED INDEX IX_Assessments_AssessmentTypeId ON assessment.Assessments (AssessmentTypeId);
-- Results by student (results by assessment use UQ_AssessmentResults_AssessmentId_EnrollmentId).
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'assessment.AssessmentResults') AND name = N'IX_AssessmentResults_EnrollmentId') CREATE NONCLUSTERED INDEX IX_AssessmentResults_EnrollmentId ON assessment.AssessmentResults (EnrollmentId) INCLUDE (AssessmentId, Score, IsAbsent, IsExempt);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'assessment.ReportCards') AND name = N'IX_ReportCards_TermId') CREATE NONCLUSTERED INDEX IX_ReportCards_TermId ON assessment.ReportCards (TermId) INCLUDE (ReportCardStatus);
-- One published report card per enrollment and term.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'assessment.ReportCards') AND name = N'IX_ReportCards_PublishedPerEnrollmentTerm') CREATE UNIQUE NONCLUSTERED INDEX IX_ReportCards_PublishedPerEnrollmentTerm ON assessment.ReportCards (EnrollmentId, TermId) WHERE ReportCardStatus = N'Published';
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'assessment.ReportCardLines') AND name = N'IX_ReportCardLines_CurriculumSubjectId') CREATE NONCLUSTERED INDEX IX_ReportCardLines_CurriculumSubjectId ON assessment.ReportCardLines (CurriculumSubjectId);
GO

/* --------------------------------------------------------------------- finance */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'finance.FeeStructures') AND name = N'IX_FeeStructures_BranchId') CREATE NONCLUSTERED INDEX IX_FeeStructures_BranchId ON finance.FeeStructures (BranchId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'finance.FeeStructures') AND name = N'IX_FeeStructures_GradeLevelId') CREATE NONCLUSTERED INDEX IX_FeeStructures_GradeLevelId ON finance.FeeStructures (GradeLevelId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'finance.FeeStructures') AND name = N'IX_FeeStructures_ProgramId') CREATE NONCLUSTERED INDEX IX_FeeStructures_ProgramId ON finance.FeeStructures (ProgramId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'finance.FeeStructures') AND name = N'IX_FeeStructures_CurrencyId') CREATE NONCLUSTERED INDEX IX_FeeStructures_CurrencyId ON finance.FeeStructures (CurrencyId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'finance.FeeStructureItems') AND name = N'IX_FeeStructureItems_FeeTypeId') CREATE NONCLUSTERED INDEX IX_FeeStructureItems_FeeTypeId ON finance.FeeStructureItems (FeeTypeId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'finance.StudentDiscounts') AND name = N'IX_StudentDiscounts_EnrollmentId') CREATE NONCLUSTERED INDEX IX_StudentDiscounts_EnrollmentId ON finance.StudentDiscounts (EnrollmentId) INCLUDE (DiscountTypeId, FeeTypeId, IsActive);
-- One active discount of a given type per enrollment and fee type.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'finance.StudentDiscounts') AND name = N'IX_StudentDiscounts_ActivePerType') CREATE UNIQUE NONCLUSTERED INDEX IX_StudentDiscounts_ActivePerType ON finance.StudentDiscounts (EnrollmentId, DiscountTypeId, FeeTypeId) WHERE IsActive = 1;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'finance.StudentDiscounts') AND name = N'IX_StudentDiscounts_DiscountTypeId') CREATE NONCLUSTERED INDEX IX_StudentDiscounts_DiscountTypeId ON finance.StudentDiscounts (DiscountTypeId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'finance.StudentDiscounts') AND name = N'IX_StudentDiscounts_FeeTypeId') CREATE NONCLUSTERED INDEX IX_StudentDiscounts_FeeTypeId ON finance.StudentDiscounts (FeeTypeId);
-- Payer category: each guardian / sponsor maps to at most one payer row.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'finance.Payers') AND name = N'IX_Payers_GuardianId') CREATE UNIQUE NONCLUSTERED INDEX IX_Payers_GuardianId ON finance.Payers (GuardianId) WHERE GuardianId IS NOT NULL;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'finance.Payers') AND name = N'IX_Payers_SponsorId') CREATE UNIQUE NONCLUSTERED INDEX IX_Payers_SponsorId ON finance.Payers (SponsorId) WHERE SponsorId IS NOT NULL;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'finance.StudentPayers') AND name = N'IX_StudentPayers_PayerId') CREATE NONCLUSTERED INDEX IX_StudentPayers_PayerId ON finance.StudentPayers (PayerId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'finance.Invoices') AND name = N'IX_Invoices_Branch_InvoiceDate') CREATE NONCLUSTERED INDEX IX_Invoices_Branch_InvoiceDate ON finance.Invoices (BranchId, InvoiceDate) INCLUDE (TotalAmount, InvoiceStatus);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'finance.Invoices') AND name = N'IX_Invoices_Enrollment_InvoiceDate') CREATE NONCLUSTERED INDEX IX_Invoices_Enrollment_InvoiceDate ON finance.Invoices (EnrollmentId, InvoiceDate) INCLUDE (TotalAmount, PaidAmount, CreditedAmount, InvoiceStatus);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'finance.Invoices') AND name = N'IX_Invoices_Payer_InvoiceDate') CREATE NONCLUSTERED INDEX IX_Invoices_Payer_InvoiceDate ON finance.Invoices (PayerId, InvoiceDate) INCLUDE (TotalAmount, PaidAmount, CreditedAmount, InvoiceStatus, DueDate);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'finance.Invoices') AND name = N'IX_Invoices_FeeInstallmentId') CREATE NONCLUSTERED INDEX IX_Invoices_FeeInstallmentId ON finance.Invoices (FeeInstallmentId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'finance.Invoices') AND name = N'IX_Invoices_CurrencyId') CREATE NONCLUSTERED INDEX IX_Invoices_CurrencyId ON finance.Invoices (CurrencyId);
-- No duplicate live invoice for the same enrollment, installment and payer.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'finance.Invoices') AND name = N'IX_Invoices_LivePerInstallmentPayer') CREATE UNIQUE NONCLUSTERED INDEX IX_Invoices_LivePerInstallmentPayer ON finance.Invoices (EnrollmentId, FeeInstallmentId, PayerId) WHERE FeeInstallmentId IS NOT NULL AND InvoiceStatus IN (N'Issued', N'PartiallyPaid', N'Paid');
-- Open receivables / overdue path.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'finance.Invoices') AND name = N'IX_Invoices_Open_DueDate') CREATE NONCLUSTERED INDEX IX_Invoices_Open_DueDate ON finance.Invoices (DueDate) INCLUDE (PayerId, EnrollmentId, TotalAmount, PaidAmount, CreditedAmount) WHERE InvoiceStatus IN (N'Issued', N'PartiallyPaid');
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'finance.InvoiceLines') AND name = N'IX_InvoiceLines_FeeTypeId') CREATE NONCLUSTERED INDEX IX_InvoiceLines_FeeTypeId ON finance.InvoiceLines (FeeTypeId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'finance.CreditNotes') AND name = N'IX_CreditNotes_InvoiceId') CREATE NONCLUSTERED INDEX IX_CreditNotes_InvoiceId ON finance.CreditNotes (InvoiceId) INCLUDE (Amount);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'finance.Payments') AND name = N'IX_Payments_Payer_PaymentDate') CREATE NONCLUSTERED INDEX IX_Payments_Payer_PaymentDate ON finance.Payments (PayerId, PaymentDate) INCLUDE (Amount, PaymentStatus);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'finance.Payments') AND name = N'IX_Payments_Branch_PaymentDate') CREATE NONCLUSTERED INDEX IX_Payments_Branch_PaymentDate ON finance.Payments (BranchId, PaymentDate) INCLUDE (Amount, PaymentMethodId, PaymentStatus);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'finance.Payments') AND name = N'IX_Payments_PaymentMethodId') CREATE NONCLUSTERED INDEX IX_Payments_PaymentMethodId ON finance.Payments (PaymentMethodId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'finance.Payments') AND name = N'IX_Payments_CurrencyId') CREATE NONCLUSTERED INDEX IX_Payments_CurrencyId ON finance.Payments (CurrencyId);
-- Prevents double-posting the same bank / eFAWATEERcom reference.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'finance.Payments') AND name = N'IX_Payments_Method_Reference') CREATE UNIQUE NONCLUSTERED INDEX IX_Payments_Method_Reference ON finance.Payments (PaymentMethodId, ReferenceNumber) WHERE ReferenceNumber IS NOT NULL AND PaymentStatus = N'Received';
-- Payments by student: allocations -> invoices -> enrollment.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'finance.PaymentAllocations') AND name = N'IX_PaymentAllocations_InvoiceId') CREATE NONCLUSTERED INDEX IX_PaymentAllocations_InvoiceId ON finance.PaymentAllocations (InvoiceId) INCLUDE (PaymentId, AllocatedAmount);
GO

/* ----------------------------------------------------------------------- audit */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'audit.AuditEvents') AND name = N'IX_AuditEvents_Entity') CREATE NONCLUSTERED INDEX IX_AuditEvents_Entity ON audit.AuditEvents (SchemaName, TableName, EntityKey, OccurredAt);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'audit.AuditEvents') AND name = N'IX_AuditEvents_OccurredAt') CREATE NONCLUSTERED INDEX IX_AuditEvents_OccurredAt ON audit.AuditEvents (OccurredAt) INCLUDE (EventType, UserAccountId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'audit.AuditEvents') AND name = N'IX_AuditEvents_User_OccurredAt') CREATE NONCLUSTERED INDEX IX_AuditEvents_User_OccurredAt ON audit.AuditEvents (UserAccountId, OccurredAt);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'audit.SecurityEvents') AND name = N'IX_SecurityEvents_User_OccurredAt') CREATE NONCLUSTERED INDEX IX_SecurityEvents_User_OccurredAt ON audit.SecurityEvents (UserAccountId, OccurredAt);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'audit.SecurityEvents') AND name = N'IX_SecurityEvents_OccurredAt') CREATE NONCLUSTERED INDEX IX_SecurityEvents_OccurredAt ON audit.SecurityEvents (OccurredAt) INCLUDE (EventType);
GO

-- Temporal history tables: give the auto-created clustered index a convention name.
IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'audit.PersonsHistory') AND name = N'ix_PersonsHistory') EXEC sys.sp_rename N'audit.PersonsHistory.ix_PersonsHistory', N'IX_PersonsHistory_Period', N'INDEX';
IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'audit.EnrollmentsHistory') AND name = N'ix_EnrollmentsHistory') EXEC sys.sp_rename N'audit.EnrollmentsHistory.ix_EnrollmentsHistory', N'IX_EnrollmentsHistory_Period', N'INDEX';
IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'audit.AssessmentResultsHistory') AND name = N'ix_AssessmentResultsHistory') EXEC sys.sp_rename N'audit.AssessmentResultsHistory.ix_AssessmentResultsHistory', N'IX_AssessmentResultsHistory_Period', N'INDEX';
IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'audit.FeeStructureItemsHistory') AND name = N'ix_FeeStructureItemsHistory') EXEC sys.sp_rename N'audit.FeeStructureItemsHistory.ix_FeeStructureItemsHistory', N'IX_FeeStructureItemsHistory_Period', N'INDEX';
GO
-- Grade-change lookups by result id over time.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'audit.AssessmentResultsHistory') AND name = N'IX_AssessmentResultsHistory_AssessmentResultId') CREATE NONCLUSTERED INDEX IX_AssessmentResultsHistory_AssessmentResultId ON audit.AssessmentResultsHistory (AssessmentResultId, SysEndTime);
GO

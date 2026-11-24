/* =============================================================================
   05_constraints.sql
   Purpose     : Named UNIQUE, CHECK and DEFAULT constraints, then switch the
                 temporal tables to SYSTEM_VERSIONING = ON.
   Dependencies: 04_primary_foreign_keys.sql (system versioning needs the PK)
   Run order   : 5 of 12
   Idempotent  : Yes (IF OBJECT_ID(<constraint>) IS NULL; versioning is
                 enabled only when OBJECTPROPERTY(..., 'TableTemporalType') = 0).
   Notes       : - UNIQUE constraints referenced by composite FKs are in 04.
                 - Filtered UNIQUE rules (e.g. one open section assignment per
                   enrollment) are filtered unique indexes in 06.
                 - Cross-table rules (score <= MaxScore, weights sum to 100,
                   payer percentages sum to 100, ...) are enforced by stored
                   procedures in 09 and checked by 12; see docs/BUSINESS_RULES.md.
                 - No constraint limits the total number of students.
   ============================================================================= */
USE [$(DatabaseName)];
GO

/* =============================================================================
   1. UNIQUE constraints (business / natural keys)
   ============================================================================= */
-- organization
IF OBJECT_ID(N'organization.UQ_Countries_IsoAlpha2', N'UQ') IS NULL ALTER TABLE organization.Countries ADD CONSTRAINT UQ_Countries_IsoAlpha2 UNIQUE (IsoAlpha2);
IF OBJECT_ID(N'organization.UQ_Countries_IsoAlpha3', N'UQ') IS NULL ALTER TABLE organization.Countries ADD CONSTRAINT UQ_Countries_IsoAlpha3 UNIQUE (IsoAlpha3);
IF OBJECT_ID(N'organization.UQ_Schools_SchoolCode', N'UQ') IS NULL ALTER TABLE organization.Schools ADD CONSTRAINT UQ_Schools_SchoolCode UNIQUE (SchoolCode);
IF OBJECT_ID(N'organization.UQ_Branches_SchoolId_BranchCode', N'UQ') IS NULL ALTER TABLE organization.Branches ADD CONSTRAINT UQ_Branches_SchoolId_BranchCode UNIQUE (SchoolId, BranchCode);
IF OBJECT_ID(N'organization.UQ_Buildings_BranchId_BuildingCode', N'UQ') IS NULL ALTER TABLE organization.Buildings ADD CONSTRAINT UQ_Buildings_BranchId_BuildingCode UNIQUE (BranchId, BuildingCode);
IF OBJECT_ID(N'organization.UQ_RoomTypes_Code', N'UQ') IS NULL ALTER TABLE organization.RoomTypes ADD CONSTRAINT UQ_RoomTypes_Code UNIQUE (Code);
IF OBJECT_ID(N'organization.UQ_Rooms_BuildingId_RoomCode', N'UQ') IS NULL ALTER TABLE organization.Rooms ADD CONSTRAINT UQ_Rooms_BuildingId_RoomCode UNIQUE (BuildingId, RoomCode);
IF OBJECT_ID(N'organization.UQ_Departments_SchoolId_DepartmentCode', N'UQ') IS NULL ALTER TABLE organization.Departments ADD CONSTRAINT UQ_Departments_SchoolId_DepartmentCode UNIQUE (SchoolId, DepartmentCode);
IF OBJECT_ID(N'organization.UQ_DocumentNumberSeries_Type_Branch_Year', N'UQ') IS NULL ALTER TABLE organization.DocumentNumberSeries ADD CONSTRAINT UQ_DocumentNumberSeries_Type_Branch_Year UNIQUE (DocumentType, BranchId, AcademicYearId);
GO
-- iam
IF OBJECT_ID(N'iam.UQ_UserAccounts_UserName', N'UQ') IS NULL ALTER TABLE iam.UserAccounts ADD CONSTRAINT UQ_UserAccounts_UserName UNIQUE (UserName);
IF OBJECT_ID(N'iam.UQ_Roles_RoleCode', N'UQ') IS NULL ALTER TABLE iam.Roles ADD CONSTRAINT UQ_Roles_RoleCode UNIQUE (RoleCode);
IF OBJECT_ID(N'iam.UQ_Permissions_PermissionCode', N'UQ') IS NULL ALTER TABLE iam.Permissions ADD CONSTRAINT UQ_Permissions_PermissionCode UNIQUE (PermissionCode);
IF OBJECT_ID(N'iam.UQ_UserRoles_User_Role_Branch_ValidFrom', N'UQ') IS NULL ALTER TABLE iam.UserRoles ADD CONSTRAINT UQ_UserRoles_User_Role_Branch_ValidFrom UNIQUE (UserAccountId, RoleId, BranchId, ValidFrom);
GO
-- people
IF OBJECT_ID(N'people.UQ_PersonContacts_Person_Type_Value', N'UQ') IS NULL ALTER TABLE people.PersonContacts ADD CONSTRAINT UQ_PersonContacts_Person_Type_Value UNIQUE (PersonId, ContactType, ContactValue);
IF OBJECT_ID(N'people.UQ_IdentityDocumentTypes_Code', N'UQ') IS NULL ALTER TABLE people.IdentityDocumentTypes ADD CONSTRAINT UQ_IdentityDocumentTypes_Code UNIQUE (Code);
IF OBJECT_ID(N'people.UQ_PersonIdentityDocuments_Type_Country_Number', N'UQ') IS NULL ALTER TABLE people.PersonIdentityDocuments ADD CONSTRAINT UQ_PersonIdentityDocuments_Type_Country_Number UNIQUE (IdentityDocumentTypeId, IssuingCountryId, DocumentNumber);
IF OBJECT_ID(N'people.UQ_Students_StudentNumber', N'UQ') IS NULL ALTER TABLE people.Students ADD CONSTRAINT UQ_Students_StudentNumber UNIQUE (StudentNumber);
IF OBJECT_ID(N'people.UQ_Employees_EmployeeNumber', N'UQ') IS NULL ALTER TABLE people.Employees ADD CONSTRAINT UQ_Employees_EmployeeNumber UNIQUE (EmployeeNumber);
IF OBJECT_ID(N'people.UQ_RelationshipTypes_Code', N'UQ') IS NULL ALTER TABLE people.RelationshipTypes ADD CONSTRAINT UQ_RelationshipTypes_Code UNIQUE (Code);
IF OBJECT_ID(N'people.UQ_StudentGuardians_StudentId_GuardianId', N'UQ') IS NULL ALTER TABLE people.StudentGuardians ADD CONSTRAINT UQ_StudentGuardians_StudentId_GuardianId UNIQUE (StudentId, GuardianId);
GO
-- academic
IF OBJECT_ID(N'academic.UQ_AcademicYears_SchoolId_YearCode', N'UQ') IS NULL ALTER TABLE academic.AcademicYears ADD CONSTRAINT UQ_AcademicYears_SchoolId_YearCode UNIQUE (SchoolId, YearCode);
IF OBJECT_ID(N'academic.UQ_Terms_AcademicYearId_TermNumber', N'UQ') IS NULL ALTER TABLE academic.Terms ADD CONSTRAINT UQ_Terms_AcademicYearId_TermNumber UNIQUE (AcademicYearId, TermNumber);
IF OBJECT_ID(N'academic.UQ_GradeLevels_Code', N'UQ') IS NULL ALTER TABLE academic.GradeLevels ADD CONSTRAINT UQ_GradeLevels_Code UNIQUE (Code);
IF OBJECT_ID(N'academic.UQ_GradeLevels_SortOrder', N'UQ') IS NULL ALTER TABLE academic.GradeLevels ADD CONSTRAINT UQ_GradeLevels_SortOrder UNIQUE (SortOrder);
IF OBJECT_ID(N'academic.UQ_Programs_Code', N'UQ') IS NULL ALTER TABLE academic.Programs ADD CONSTRAINT UQ_Programs_Code UNIQUE (Code);
IF OBJECT_ID(N'academic.UQ_Subjects_SubjectCode', N'UQ') IS NULL ALTER TABLE academic.Subjects ADD CONSTRAINT UQ_Subjects_SubjectCode UNIQUE (SubjectCode);
IF OBJECT_ID(N'academic.UQ_CurriculumSubjects_Year_Grade_Program_Subject', N'UQ') IS NULL ALTER TABLE academic.CurriculumSubjects ADD CONSTRAINT UQ_CurriculumSubjects_Year_Grade_Program_Subject UNIQUE (AcademicYearId, GradeLevelId, ProgramId, SubjectId);
IF OBJECT_ID(N'academic.UQ_Sections_Year_Branch_Grade_Code', N'UQ') IS NULL ALTER TABLE academic.Sections ADD CONSTRAINT UQ_Sections_Year_Branch_Grade_Code UNIQUE (AcademicYearId, BranchId, GradeLevelId, SectionCode);
IF OBJECT_ID(N'academic.UQ_TeachingAssignments_Section_Subject_Teacher_Term', N'UQ') IS NULL ALTER TABLE academic.TeachingAssignments ADD CONSTRAINT UQ_TeachingAssignments_Section_Subject_Teacher_Term UNIQUE (SectionId, CurriculumSubjectId, TeacherId, TermId);
GO
-- enrollment
IF OBJECT_ID(N'enrollment.UQ_Applications_ApplicationNumber', N'UQ') IS NULL ALTER TABLE enrollment.Applications ADD CONSTRAINT UQ_Applications_ApplicationNumber UNIQUE (ApplicationNumber);
IF OBJECT_ID(N'enrollment.UQ_Enrollments_StudentId_AcademicYearId', N'UQ') IS NULL ALTER TABLE enrollment.Enrollments ADD CONSTRAINT UQ_Enrollments_StudentId_AcademicYearId UNIQUE (StudentId, AcademicYearId);
IF OBJECT_ID(N'enrollment.UQ_EnrollmentSubjects_EnrollmentId_CurriculumSubjectId', N'UQ') IS NULL ALTER TABLE enrollment.EnrollmentSubjects ADD CONSTRAINT UQ_EnrollmentSubjects_EnrollmentId_CurriculumSubjectId UNIQUE (EnrollmentId, CurriculumSubjectId);
GO
-- timetable
IF OBJECT_ID(N'timetable.UQ_BellSchedules_Branch_Year_NameEn', N'UQ') IS NULL ALTER TABLE timetable.BellSchedules ADD CONSTRAINT UQ_BellSchedules_Branch_Year_NameEn UNIQUE (BranchId, AcademicYearId, NameEn);
IF OBJECT_ID(N'timetable.UQ_Periods_BellScheduleId_PeriodNumber', N'UQ') IS NULL ALTER TABLE timetable.Periods ADD CONSTRAINT UQ_Periods_BellScheduleId_PeriodNumber UNIQUE (BellScheduleId, PeriodNumber);
IF OBJECT_ID(N'timetable.UQ_Timetables_Section_Term_Version', N'UQ') IS NULL ALTER TABLE timetable.Timetables ADD CONSTRAINT UQ_Timetables_Section_Term_Version UNIQUE (SectionId, TermId, VersionNumber);
IF OBJECT_ID(N'timetable.UQ_TimetableEntries_Timetable_Day_Period', N'UQ') IS NULL ALTER TABLE timetable.TimetableEntries ADD CONSTRAINT UQ_TimetableEntries_Timetable_Day_Period UNIQUE (TimetableId, DayOfWeek, PeriodId);
GO
-- attendance
IF OBJECT_ID(N'attendance.UQ_AttendanceStatuses_Code', N'UQ') IS NULL ALTER TABLE attendance.AttendanceStatuses ADD CONSTRAINT UQ_AttendanceStatuses_Code UNIQUE (Code);
IF OBJECT_ID(N'attendance.UQ_AttendanceSessions_Section_Date_Period', N'UQ') IS NULL ALTER TABLE attendance.AttendanceSessions ADD CONSTRAINT UQ_AttendanceSessions_Section_Date_Period UNIQUE (SectionId, SessionDate, PeriodId);
IF OBJECT_ID(N'attendance.UQ_AttendanceRecords_SessionId_EnrollmentId', N'UQ') IS NULL ALTER TABLE attendance.AttendanceRecords ADD CONSTRAINT UQ_AttendanceRecords_SessionId_EnrollmentId UNIQUE (AttendanceSessionId, EnrollmentId);
GO
-- assessment
IF OBJECT_ID(N'assessment.UQ_GradingScales_Code', N'UQ') IS NULL ALTER TABLE assessment.GradingScales ADD CONSTRAINT UQ_GradingScales_Code UNIQUE (Code);
IF OBJECT_ID(N'assessment.UQ_GradingScaleBands_Scale_Letter', N'UQ') IS NULL ALTER TABLE assessment.GradingScaleBands ADD CONSTRAINT UQ_GradingScaleBands_Scale_Letter UNIQUE (GradingScaleId, LetterGrade);
IF OBJECT_ID(N'assessment.UQ_AssessmentTypes_Code', N'UQ') IS NULL ALTER TABLE assessment.AssessmentTypes ADD CONSTRAINT UQ_AssessmentTypes_Code UNIQUE (Code);
IF OBJECT_ID(N'assessment.UQ_AssessmentWeights_Subject_Term_Type', N'UQ') IS NULL ALTER TABLE assessment.AssessmentWeights ADD CONSTRAINT UQ_AssessmentWeights_Subject_Term_Type UNIQUE (CurriculumSubjectId, TermId, AssessmentTypeId);
IF OBJECT_ID(N'assessment.UQ_AssessmentResults_AssessmentId_EnrollmentId', N'UQ') IS NULL ALTER TABLE assessment.AssessmentResults ADD CONSTRAINT UQ_AssessmentResults_AssessmentId_EnrollmentId UNIQUE (AssessmentId, EnrollmentId);
IF OBJECT_ID(N'assessment.UQ_ReportCards_Enrollment_Term_Version', N'UQ') IS NULL ALTER TABLE assessment.ReportCards ADD CONSTRAINT UQ_ReportCards_Enrollment_Term_Version UNIQUE (EnrollmentId, TermId, VersionNumber);
IF OBJECT_ID(N'assessment.UQ_ReportCardLines_ReportCardId_CurriculumSubjectId', N'UQ') IS NULL ALTER TABLE assessment.ReportCardLines ADD CONSTRAINT UQ_ReportCardLines_ReportCardId_CurriculumSubjectId UNIQUE (ReportCardId, CurriculumSubjectId);
GO
-- finance
IF OBJECT_ID(N'finance.UQ_Currencies_CurrencyCode', N'UQ') IS NULL ALTER TABLE finance.Currencies ADD CONSTRAINT UQ_Currencies_CurrencyCode UNIQUE (CurrencyCode);
IF OBJECT_ID(N'finance.UQ_FeeTypes_Code', N'UQ') IS NULL ALTER TABLE finance.FeeTypes ADD CONSTRAINT UQ_FeeTypes_Code UNIQUE (Code);
IF OBJECT_ID(N'finance.UQ_FeeStructures_Year_Branch_Grade_Program', N'UQ') IS NULL ALTER TABLE finance.FeeStructures ADD CONSTRAINT UQ_FeeStructures_Year_Branch_Grade_Program UNIQUE (AcademicYearId, BranchId, GradeLevelId, ProgramId);
IF OBJECT_ID(N'finance.UQ_FeeStructureItems_FeeStructureId_FeeTypeId', N'UQ') IS NULL ALTER TABLE finance.FeeStructureItems ADD CONSTRAINT UQ_FeeStructureItems_FeeStructureId_FeeTypeId UNIQUE (FeeStructureId, FeeTypeId);
IF OBJECT_ID(N'finance.UQ_FeeInstallments_FeeStructureId_InstallmentNumber', N'UQ') IS NULL ALTER TABLE finance.FeeInstallments ADD CONSTRAINT UQ_FeeInstallments_FeeStructureId_InstallmentNumber UNIQUE (FeeStructureId, InstallmentNumber);
IF OBJECT_ID(N'finance.UQ_DiscountTypes_Code', N'UQ') IS NULL ALTER TABLE finance.DiscountTypes ADD CONSTRAINT UQ_DiscountTypes_Code UNIQUE (Code);
IF OBJECT_ID(N'finance.UQ_Sponsors_SponsorCode', N'UQ') IS NULL ALTER TABLE finance.Sponsors ADD CONSTRAINT UQ_Sponsors_SponsorCode UNIQUE (SponsorCode);
IF OBJECT_ID(N'finance.UQ_StudentPayers_EnrollmentId_PayerId', N'UQ') IS NULL ALTER TABLE finance.StudentPayers ADD CONSTRAINT UQ_StudentPayers_EnrollmentId_PayerId UNIQUE (EnrollmentId, PayerId);
IF OBJECT_ID(N'finance.UQ_Invoices_InvoiceNumber', N'UQ') IS NULL ALTER TABLE finance.Invoices ADD CONSTRAINT UQ_Invoices_InvoiceNumber UNIQUE (InvoiceNumber);
IF OBJECT_ID(N'finance.UQ_InvoiceLines_InvoiceId_LineNumber', N'UQ') IS NULL ALTER TABLE finance.InvoiceLines ADD CONSTRAINT UQ_InvoiceLines_InvoiceId_LineNumber UNIQUE (InvoiceId, LineNumber);
IF OBJECT_ID(N'finance.UQ_CreditNotes_CreditNoteNumber', N'UQ') IS NULL ALTER TABLE finance.CreditNotes ADD CONSTRAINT UQ_CreditNotes_CreditNoteNumber UNIQUE (CreditNoteNumber);
IF OBJECT_ID(N'finance.UQ_PaymentMethods_Code', N'UQ') IS NULL ALTER TABLE finance.PaymentMethods ADD CONSTRAINT UQ_PaymentMethods_Code UNIQUE (Code);
IF OBJECT_ID(N'finance.UQ_Payments_ReceiptNumber', N'UQ') IS NULL ALTER TABLE finance.Payments ADD CONSTRAINT UQ_Payments_ReceiptNumber UNIQUE (ReceiptNumber);
IF OBJECT_ID(N'finance.UQ_PaymentAllocations_PaymentId_InvoiceId', N'UQ') IS NULL ALTER TABLE finance.PaymentAllocations ADD CONSTRAINT UQ_PaymentAllocations_PaymentId_InvoiceId UNIQUE (PaymentId, InvoiceId);
GO

/* =============================================================================
   2. CHECK constraints
   ============================================================================= */
-- organization
IF OBJECT_ID(N'organization.CK_Countries_IsoAlpha2', N'C') IS NULL ALTER TABLE organization.Countries ADD CONSTRAINT CK_Countries_IsoAlpha2 CHECK (LEN(IsoAlpha2) = 2);
IF OBJECT_ID(N'organization.CK_Countries_IsoAlpha3', N'C') IS NULL ALTER TABLE organization.Countries ADD CONSTRAINT CK_Countries_IsoAlpha3 CHECK (LEN(IsoAlpha3) = 3);
IF OBJECT_ID(N'organization.CK_Branches_WorkingDaysMask', N'C') IS NULL ALTER TABLE organization.Branches ADD CONSTRAINT CK_Branches_WorkingDaysMask CHECK (WorkingDaysMask BETWEEN 1 AND 127);
IF OBJECT_ID(N'organization.CK_Rooms_SeatCapacity', N'C') IS NULL ALTER TABLE organization.Rooms ADD CONSTRAINT CK_Rooms_SeatCapacity CHECK (SeatCapacity IS NULL OR SeatCapacity > 0);
IF OBJECT_ID(N'organization.CK_Departments_DepartmentType', N'C') IS NULL ALTER TABLE organization.Departments ADD CONSTRAINT CK_Departments_DepartmentType CHECK (DepartmentType IN (N'Academic', N'Administrative'));
IF OBJECT_ID(N'organization.CK_DocumentNumberSeries_DocumentType', N'C') IS NULL ALTER TABLE organization.DocumentNumberSeries ADD CONSTRAINT CK_DocumentNumberSeries_DocumentType CHECK (DocumentType IN (N'Application', N'Invoice', N'Receipt', N'CreditNote'));
IF OBJECT_ID(N'organization.CK_DocumentNumberSeries_NextNumber', N'C') IS NULL ALTER TABLE organization.DocumentNumberSeries ADD CONSTRAINT CK_DocumentNumberSeries_NextNumber CHECK (NextNumber > 0);
IF OBJECT_ID(N'organization.CK_DocumentNumberSeries_PadLength', N'C') IS NULL ALTER TABLE organization.DocumentNumberSeries ADD CONSTRAINT CK_DocumentNumberSeries_PadLength CHECK (PadLength BETWEEN 1 AND 12);
GO
-- iam
IF OBJECT_ID(N'iam.CK_UserAccounts_AuthProvider', N'C') IS NULL ALTER TABLE iam.UserAccounts ADD CONSTRAINT CK_UserAccounts_AuthProvider CHECK (AuthProvider IN (N'Local', N'AzureAD', N'Google'));
IF OBJECT_ID(N'iam.CK_UserAccounts_Credential', N'C') IS NULL ALTER TABLE iam.UserAccounts ADD CONSTRAINT CK_UserAccounts_Credential CHECK ((AuthProvider = N'Local' AND PasswordHash IS NOT NULL) OR (AuthProvider <> N'Local' AND ExternalSubjectId IS NOT NULL));
IF OBJECT_ID(N'iam.CK_UserAccounts_AccountStatus', N'C') IS NULL ALTER TABLE iam.UserAccounts ADD CONSTRAINT CK_UserAccounts_AccountStatus CHECK (AccountStatus IN (N'Active', N'Locked', N'Disabled'));
IF OBJECT_ID(N'iam.CK_UserAccounts_FailedLoginCount', N'C') IS NULL ALTER TABLE iam.UserAccounts ADD CONSTRAINT CK_UserAccounts_FailedLoginCount CHECK (FailedLoginCount >= 0);
IF OBJECT_ID(N'iam.CK_UserAccounts_PreferredLanguage', N'C') IS NULL ALTER TABLE iam.UserAccounts ADD CONSTRAINT CK_UserAccounts_PreferredLanguage CHECK (PreferredLanguage IN (N'ar', N'en'));
IF OBJECT_ID(N'iam.CK_UserRoles_ValidDates', N'C') IS NULL ALTER TABLE iam.UserRoles ADD CONSTRAINT CK_UserRoles_ValidDates CHECK (ValidTo IS NULL OR ValidTo >= ValidFrom);
GO
-- people
IF OBJECT_ID(N'people.CK_Persons_Gender', N'C') IS NULL ALTER TABLE people.Persons ADD CONSTRAINT CK_Persons_Gender CHECK (Gender IN (N'M', N'F'));
IF OBJECT_ID(N'people.CK_Persons_DateOfBirth', N'C') IS NULL ALTER TABLE people.Persons ADD CONSTRAINT CK_Persons_DateOfBirth CHECK (DateOfBirth IS NULL OR DateOfBirth >= '19000101');
IF OBJECT_ID(N'people.CK_Persons_PrimaryLanguage', N'C') IS NULL ALTER TABLE people.Persons ADD CONSTRAINT CK_Persons_PrimaryLanguage CHECK (PrimaryLanguage IS NULL OR PrimaryLanguage IN (N'ar', N'en'));
IF OBJECT_ID(N'people.CK_PersonContacts_ContactType', N'C') IS NULL ALTER TABLE people.PersonContacts ADD CONSTRAINT CK_PersonContacts_ContactType CHECK (ContactType IN (N'Mobile', N'Phone', N'Email', N'WhatsApp'));
IF OBJECT_ID(N'people.CK_PersonAddresses_AddressType', N'C') IS NULL ALTER TABLE people.PersonAddresses ADD CONSTRAINT CK_PersonAddresses_AddressType CHECK (AddressType IN (N'Home', N'Work', N'Mailing'));
IF OBJECT_ID(N'people.CK_PersonIdentityDocuments_Dates', N'C') IS NULL ALTER TABLE people.PersonIdentityDocuments ADD CONSTRAINT CK_PersonIdentityDocuments_Dates CHECK (ExpiryDate IS NULL OR IssueDate IS NULL OR ExpiryDate >= IssueDate);
IF OBJECT_ID(N'people.CK_Students_StudentStatus', N'C') IS NULL ALTER TABLE people.Students ADD CONSTRAINT CK_Students_StudentStatus CHECK (StudentStatus IN (N'Active', N'Graduated', N'Withdrawn', N'Transferred', N'Suspended'));
IF OBJECT_ID(N'people.CK_Guardians_PreferredLanguage', N'C') IS NULL ALTER TABLE people.Guardians ADD CONSTRAINT CK_Guardians_PreferredLanguage CHECK (PreferredLanguage IN (N'ar', N'en'));
IF OBJECT_ID(N'people.CK_Employees_EmploymentStatus', N'C') IS NULL ALTER TABLE people.Employees ADD CONSTRAINT CK_Employees_EmploymentStatus CHECK (EmploymentStatus IN (N'Active', N'OnLeave', N'Terminated'));
IF OBJECT_ID(N'people.CK_Employees_Dates', N'C') IS NULL ALTER TABLE people.Employees ADD CONSTRAINT CK_Employees_Dates CHECK (TerminationDate IS NULL OR TerminationDate >= HireDate);
IF OBJECT_ID(N'people.CK_Teachers_MaxWeeklyPeriods', N'C') IS NULL ALTER TABLE people.Teachers ADD CONSTRAINT CK_Teachers_MaxWeeklyPeriods CHECK (MaxWeeklyPeriods IS NULL OR MaxWeeklyPeriods > 0);
IF OBJECT_ID(N'people.CK_StudentGuardians_NotSelf', N'C') IS NULL ALTER TABLE people.StudentGuardians ADD CONSTRAINT CK_StudentGuardians_NotSelf CHECK (StudentId <> GuardianId);
GO
-- academic
IF OBJECT_ID(N'academic.CK_AcademicYears_YearCode', N'C') IS NULL ALTER TABLE academic.AcademicYears ADD CONSTRAINT CK_AcademicYears_YearCode CHECK (YearCode LIKE N'[0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9]');
IF OBJECT_ID(N'academic.CK_AcademicYears_Dates', N'C') IS NULL ALTER TABLE academic.AcademicYears ADD CONSTRAINT CK_AcademicYears_Dates CHECK (EndDate > StartDate);
IF OBJECT_ID(N'academic.CK_AcademicYears_YearStatus', N'C') IS NULL ALTER TABLE academic.AcademicYears ADD CONSTRAINT CK_AcademicYears_YearStatus CHECK (YearStatus IN (N'Planned', N'Active', N'Closed'));
IF OBJECT_ID(N'academic.CK_Terms_Dates', N'C') IS NULL ALTER TABLE academic.Terms ADD CONSTRAINT CK_Terms_Dates CHECK (EndDate > StartDate);
IF OBJECT_ID(N'academic.CK_Terms_TermNumber', N'C') IS NULL ALTER TABLE academic.Terms ADD CONSTRAINT CK_Terms_TermNumber CHECK (TermNumber > 0);
IF OBJECT_ID(N'academic.CK_Holidays_Dates', N'C') IS NULL ALTER TABLE academic.Holidays ADD CONSTRAINT CK_Holidays_Dates CHECK (EndDate >= StartDate);
IF OBJECT_ID(N'academic.CK_GradeLevels_Stage', N'C') IS NULL ALTER TABLE academic.GradeLevels ADD CONSTRAINT CK_GradeLevels_Stage CHECK (Stage IN (N'KG', N'Primary', N'Middle', N'Secondary'));
IF OBJECT_ID(N'academic.CK_GradeLevels_NextGradeLevel', N'C') IS NULL ALTER TABLE academic.GradeLevels ADD CONSTRAINT CK_GradeLevels_NextGradeLevel CHECK (NextGradeLevelId IS NULL OR NextGradeLevelId <> GradeLevelId);
IF OBJECT_ID(N'academic.CK_CurriculumSubjects_WeeklyPeriods', N'C') IS NULL ALTER TABLE academic.CurriculumSubjects ADD CONSTRAINT CK_CurriculumSubjects_WeeklyPeriods CHECK (WeeklyPeriods > 0);
IF OBJECT_ID(N'academic.CK_Sections_Capacity', N'C') IS NULL ALTER TABLE academic.Sections ADD CONSTRAINT CK_Sections_Capacity CHECK (Capacity IS NULL OR Capacity > 0);
GO
-- enrollment
IF OBJECT_ID(N'enrollment.CK_Applications_ApplicationStatus', N'C') IS NULL ALTER TABLE enrollment.Applications ADD CONSTRAINT CK_Applications_ApplicationStatus CHECK (ApplicationStatus IN (N'Submitted', N'UnderReview', N'Accepted', N'Rejected', N'Waitlisted', N'Withdrawn', N'Enrolled'));
IF OBJECT_ID(N'enrollment.CK_Applications_DecisionDate', N'C') IS NULL ALTER TABLE enrollment.Applications ADD CONSTRAINT CK_Applications_DecisionDate CHECK (DecisionDate IS NULL OR DecisionDate >= ApplicationDate);
IF OBJECT_ID(N'enrollment.CK_ApplicationStatusHistory_ToStatus', N'C') IS NULL ALTER TABLE enrollment.ApplicationStatusHistory ADD CONSTRAINT CK_ApplicationStatusHistory_ToStatus CHECK (ToStatus IN (N'Submitted', N'UnderReview', N'Accepted', N'Rejected', N'Waitlisted', N'Withdrawn', N'Enrolled'));
IF OBJECT_ID(N'enrollment.CK_Enrollments_EnrollmentStatus', N'C') IS NULL ALTER TABLE enrollment.Enrollments ADD CONSTRAINT CK_Enrollments_EnrollmentStatus CHECK (EnrollmentStatus IN (N'Enrolled', N'Withdrawn', N'Completed', N'Transferred'));
IF OBJECT_ID(N'enrollment.CK_Enrollments_PromotionOutcome', N'C') IS NULL ALTER TABLE enrollment.Enrollments ADD CONSTRAINT CK_Enrollments_PromotionOutcome CHECK (PromotionOutcome IS NULL OR PromotionOutcome IN (N'Promoted', N'Retained', N'Graduated'));
IF OBJECT_ID(N'enrollment.CK_Enrollments_WithdrawalDate', N'C') IS NULL ALTER TABLE enrollment.Enrollments ADD CONSTRAINT CK_Enrollments_WithdrawalDate CHECK (WithdrawalDate IS NULL OR WithdrawalDate >= EnrollmentDate);
IF OBJECT_ID(N'enrollment.CK_Enrollments_WithdrawnHasDate', N'C') IS NULL ALTER TABLE enrollment.Enrollments ADD CONSTRAINT CK_Enrollments_WithdrawnHasDate CHECK (EnrollmentStatus NOT IN (N'Withdrawn', N'Transferred') OR WithdrawalDate IS NOT NULL);
IF OBJECT_ID(N'enrollment.CK_SectionAssignments_Dates', N'C') IS NULL ALTER TABLE enrollment.SectionAssignments ADD CONSTRAINT CK_SectionAssignments_Dates CHECK (EndDate IS NULL OR EndDate >= StartDate);
GO
-- timetable
IF OBJECT_ID(N'timetable.CK_Periods_Times', N'C') IS NULL ALTER TABLE timetable.Periods ADD CONSTRAINT CK_Periods_Times CHECK (EndTime > StartTime);
IF OBJECT_ID(N'timetable.CK_Periods_PeriodNumber', N'C') IS NULL ALTER TABLE timetable.Periods ADD CONSTRAINT CK_Periods_PeriodNumber CHECK (PeriodNumber > 0);
IF OBJECT_ID(N'timetable.CK_Timetables_TimetableStatus', N'C') IS NULL ALTER TABLE timetable.Timetables ADD CONSTRAINT CK_Timetables_TimetableStatus CHECK (TimetableStatus IN (N'Draft', N'Published', N'Archived'));
IF OBJECT_ID(N'timetable.CK_Timetables_Dates', N'C') IS NULL ALTER TABLE timetable.Timetables ADD CONSTRAINT CK_Timetables_Dates CHECK (EffectiveTo IS NULL OR EffectiveTo >= EffectiveFrom);
IF OBJECT_ID(N'timetable.CK_Timetables_VersionNumber', N'C') IS NULL ALTER TABLE timetable.Timetables ADD CONSTRAINT CK_Timetables_VersionNumber CHECK (VersionNumber > 0);
IF OBJECT_ID(N'timetable.CK_Timetables_PublishedAt', N'C') IS NULL ALTER TABLE timetable.Timetables ADD CONSTRAINT CK_Timetables_PublishedAt CHECK (TimetableStatus = N'Draft' OR PublishedAt IS NOT NULL);
IF OBJECT_ID(N'timetable.CK_TimetableEntries_DayOfWeek', N'C') IS NULL ALTER TABLE timetable.TimetableEntries ADD CONSTRAINT CK_TimetableEntries_DayOfWeek CHECK (DayOfWeek BETWEEN 1 AND 7);
GO
-- attendance
IF OBJECT_ID(N'attendance.CK_AttendanceStatuses_PresentNotExcused', N'C') IS NULL ALTER TABLE attendance.AttendanceStatuses ADD CONSTRAINT CK_AttendanceStatuses_PresentNotExcused CHECK (NOT (CountsAsPresent = 1 AND IsExcused = 1));
IF OBJECT_ID(N'attendance.CK_AttendanceRecords_MinutesLate', N'C') IS NULL ALTER TABLE attendance.AttendanceRecords ADD CONSTRAINT CK_AttendanceRecords_MinutesLate CHECK (MinutesLate IS NULL OR MinutesLate >= 0);
GO
-- assessment
IF OBJECT_ID(N'assessment.CK_GradingScales_PassPercent', N'C') IS NULL ALTER TABLE assessment.GradingScales ADD CONSTRAINT CK_GradingScales_PassPercent CHECK (PassPercent BETWEEN 0 AND 100);
IF OBJECT_ID(N'assessment.CK_GradingScaleBands_Range', N'C') IS NULL ALTER TABLE assessment.GradingScaleBands ADD CONSTRAINT CK_GradingScaleBands_Range CHECK (MinPercent >= 0 AND MaxPercent <= 100 AND MinPercent <= MaxPercent);
IF OBJECT_ID(N'assessment.CK_AssessmentWeights_WeightPercent', N'C') IS NULL ALTER TABLE assessment.AssessmentWeights ADD CONSTRAINT CK_AssessmentWeights_WeightPercent CHECK (WeightPercent > 0 AND WeightPercent <= 100);
IF OBJECT_ID(N'assessment.CK_Assessments_MaxScore', N'C') IS NULL ALTER TABLE assessment.Assessments ADD CONSTRAINT CK_Assessments_MaxScore CHECK (MaxScore > 0);
IF OBJECT_ID(N'assessment.CK_AssessmentResults_Score', N'C') IS NULL ALTER TABLE assessment.AssessmentResults ADD CONSTRAINT CK_AssessmentResults_Score CHECK (Score IS NULL OR Score >= 0);
IF OBJECT_ID(N'assessment.CK_AssessmentResults_ScoreOrFlag', N'C') IS NULL ALTER TABLE assessment.AssessmentResults ADD CONSTRAINT CK_AssessmentResults_ScoreOrFlag CHECK (Score IS NOT NULL OR IsAbsent = 1 OR IsExempt = 1);
IF OBJECT_ID(N'assessment.CK_ReportCards_ReportCardStatus', N'C') IS NULL ALTER TABLE assessment.ReportCards ADD CONSTRAINT CK_ReportCards_ReportCardStatus CHECK (ReportCardStatus IN (N'Draft', N'Published', N'Superseded'));
IF OBJECT_ID(N'assessment.CK_ReportCards_VersionNumber', N'C') IS NULL ALTER TABLE assessment.ReportCards ADD CONSTRAINT CK_ReportCards_VersionNumber CHECK (VersionNumber > 0);
IF OBJECT_ID(N'assessment.CK_ReportCards_PublishedAt', N'C') IS NULL ALTER TABLE assessment.ReportCards ADD CONSTRAINT CK_ReportCards_PublishedAt CHECK (ReportCardStatus = N'Draft' OR PublishedAt IS NOT NULL);
IF OBJECT_ID(N'assessment.CK_ReportCards_Days', N'C') IS NULL ALTER TABLE assessment.ReportCards ADD CONSTRAINT CK_ReportCards_Days CHECK (ISNULL(DaysPresent, 0) >= 0 AND ISNULL(DaysAbsent, 0) >= 0 AND ISNULL(DaysLate, 0) >= 0);
IF OBJECT_ID(N'assessment.CK_ReportCardLines_SubjectPercent', N'C') IS NULL ALTER TABLE assessment.ReportCardLines ADD CONSTRAINT CK_ReportCardLines_SubjectPercent CHECK (SubjectPercent IS NULL OR SubjectPercent BETWEEN 0 AND 100);
GO
-- finance
IF OBJECT_ID(N'finance.CK_Currencies_CurrencyCode', N'C') IS NULL ALTER TABLE finance.Currencies ADD CONSTRAINT CK_Currencies_CurrencyCode CHECK (LEN(CurrencyCode) = 3);
IF OBJECT_ID(N'finance.CK_Currencies_MinorUnits', N'C') IS NULL ALTER TABLE finance.Currencies ADD CONSTRAINT CK_Currencies_MinorUnits CHECK (MinorUnits BETWEEN 0 AND 4);
IF OBJECT_ID(N'finance.CK_FeeTypes_TaxPercent', N'C') IS NULL ALTER TABLE finance.FeeTypes ADD CONSTRAINT CK_FeeTypes_TaxPercent CHECK (TaxPercent BETWEEN 0 AND 100 AND (IsTaxable = 1 OR TaxPercent = 0));
IF OBJECT_ID(N'finance.CK_FeeStructureItems_Amount', N'C') IS NULL ALTER TABLE finance.FeeStructureItems ADD CONSTRAINT CK_FeeStructureItems_Amount CHECK (Amount >= 0);
IF OBJECT_ID(N'finance.CK_FeeInstallments_InstallmentPercent', N'C') IS NULL ALTER TABLE finance.FeeInstallments ADD CONSTRAINT CK_FeeInstallments_InstallmentPercent CHECK (InstallmentPercent > 0 AND InstallmentPercent <= 100);
IF OBJECT_ID(N'finance.CK_FeeInstallments_InstallmentNumber', N'C') IS NULL ALTER TABLE finance.FeeInstallments ADD CONSTRAINT CK_FeeInstallments_InstallmentNumber CHECK (InstallmentNumber > 0);
IF OBJECT_ID(N'finance.CK_DiscountTypes_DefaultPercent', N'C') IS NULL ALTER TABLE finance.DiscountTypes ADD CONSTRAINT CK_DiscountTypes_DefaultPercent CHECK (DefaultPercent IS NULL OR (DefaultPercent > 0 AND DefaultPercent <= 100));
IF OBJECT_ID(N'finance.CK_StudentDiscounts_Value', N'C') IS NULL ALTER TABLE finance.StudentDiscounts ADD CONSTRAINT CK_StudentDiscounts_Value CHECK ((DiscountPercent IS NOT NULL AND DiscountAmount IS NULL AND DiscountPercent > 0 AND DiscountPercent <= 100) OR (DiscountAmount IS NOT NULL AND DiscountPercent IS NULL AND DiscountAmount > 0));
IF OBJECT_ID(N'finance.CK_StudentDiscounts_AmountNeedsFeeType', N'C') IS NULL ALTER TABLE finance.StudentDiscounts ADD CONSTRAINT CK_StudentDiscounts_AmountNeedsFeeType CHECK (DiscountAmount IS NULL OR FeeTypeId IS NOT NULL);
IF OBJECT_ID(N'finance.CK_Sponsors_SponsorType', N'C') IS NULL ALTER TABLE finance.Sponsors ADD CONSTRAINT CK_Sponsors_SponsorType CHECK (SponsorType IN (N'Employer', N'NGO', N'ScholarshipFund', N'Government', N'Other'));
IF OBJECT_ID(N'finance.CK_Payers_PayerType', N'C') IS NULL ALTER TABLE finance.Payers ADD CONSTRAINT CK_Payers_PayerType CHECK (PayerType IN (N'Guardian', N'Sponsor'));
IF OBJECT_ID(N'finance.CK_Payers_ExactlyOne', N'C') IS NULL ALTER TABLE finance.Payers ADD CONSTRAINT CK_Payers_ExactlyOne CHECK ((PayerType = N'Guardian' AND GuardianId IS NOT NULL AND SponsorId IS NULL) OR (PayerType = N'Sponsor' AND SponsorId IS NOT NULL AND GuardianId IS NULL));
IF OBJECT_ID(N'finance.CK_StudentPayers_ResponsibilityPercent', N'C') IS NULL ALTER TABLE finance.StudentPayers ADD CONSTRAINT CK_StudentPayers_ResponsibilityPercent CHECK (ResponsibilityPercent > 0 AND ResponsibilityPercent <= 100);
IF OBJECT_ID(N'finance.CK_Invoices_InvoiceStatus', N'C') IS NULL ALTER TABLE finance.Invoices ADD CONSTRAINT CK_Invoices_InvoiceStatus CHECK (InvoiceStatus IN (N'Issued', N'PartiallyPaid', N'Paid', N'Cancelled'));
IF OBJECT_ID(N'finance.CK_Invoices_Amounts', N'C') IS NULL ALTER TABLE finance.Invoices ADD CONSTRAINT CK_Invoices_Amounts CHECK (SubtotalAmount >= 0 AND DiscountAmount >= 0 AND TaxAmount >= 0 AND TotalAmount >= 0 AND PaidAmount >= 0 AND CreditedAmount >= 0);
IF OBJECT_ID(N'finance.CK_Invoices_Total', N'C') IS NULL ALTER TABLE finance.Invoices ADD CONSTRAINT CK_Invoices_Total CHECK (TotalAmount = SubtotalAmount - DiscountAmount + TaxAmount);
IF OBJECT_ID(N'finance.CK_Invoices_Settlement', N'C') IS NULL ALTER TABLE finance.Invoices ADD CONSTRAINT CK_Invoices_Settlement CHECK (PaidAmount + CreditedAmount <= TotalAmount);
IF OBJECT_ID(N'finance.CK_Invoices_DueDate', N'C') IS NULL ALTER TABLE finance.Invoices ADD CONSTRAINT CK_Invoices_DueDate CHECK (DueDate >= InvoiceDate);
IF OBJECT_ID(N'finance.CK_Invoices_Cancellation', N'C') IS NULL ALTER TABLE finance.Invoices ADD CONSTRAINT CK_Invoices_Cancellation CHECK ((InvoiceStatus = N'Cancelled' AND CancelledAt IS NOT NULL) OR (InvoiceStatus <> N'Cancelled' AND CancelledAt IS NULL));
IF OBJECT_ID(N'finance.CK_InvoiceLines_LineNumber', N'C') IS NULL ALTER TABLE finance.InvoiceLines ADD CONSTRAINT CK_InvoiceLines_LineNumber CHECK (LineNumber > 0);
IF OBJECT_ID(N'finance.CK_InvoiceLines_Quantity', N'C') IS NULL ALTER TABLE finance.InvoiceLines ADD CONSTRAINT CK_InvoiceLines_Quantity CHECK (Quantity > 0);
IF OBJECT_ID(N'finance.CK_InvoiceLines_Amounts', N'C') IS NULL ALTER TABLE finance.InvoiceLines ADD CONSTRAINT CK_InvoiceLines_Amounts CHECK (UnitAmount >= 0 AND DiscountAmount >= 0 AND TaxAmount >= 0 AND LineTotal >= 0);
IF OBJECT_ID(N'finance.CK_CreditNotes_Amount', N'C') IS NULL ALTER TABLE finance.CreditNotes ADD CONSTRAINT CK_CreditNotes_Amount CHECK (Amount > 0);
IF OBJECT_ID(N'finance.CK_Payments_Amount', N'C') IS NULL ALTER TABLE finance.Payments ADD CONSTRAINT CK_Payments_Amount CHECK (Amount > 0);
IF OBJECT_ID(N'finance.CK_Payments_PaymentStatus', N'C') IS NULL ALTER TABLE finance.Payments ADD CONSTRAINT CK_Payments_PaymentStatus CHECK (PaymentStatus IN (N'Received', N'Reversed'));
IF OBJECT_ID(N'finance.CK_PaymentAllocations_AllocatedAmount', N'C') IS NULL ALTER TABLE finance.PaymentAllocations ADD CONSTRAINT CK_PaymentAllocations_AllocatedAmount CHECK (AllocatedAmount > 0);
GO
-- audit
IF OBJECT_ID(N'audit.CK_AuditEvents_EventAction', N'C') IS NULL ALTER TABLE audit.AuditEvents ADD CONSTRAINT CK_AuditEvents_EventAction CHECK (EventAction IN (N'Insert', N'Update', N'Delete', N'Execute'));
IF OBJECT_ID(N'audit.CK_AuditEvents_OldValues', N'C') IS NULL ALTER TABLE audit.AuditEvents ADD CONSTRAINT CK_AuditEvents_OldValues CHECK (OldValues IS NULL OR ISJSON(OldValues) = 1);
IF OBJECT_ID(N'audit.CK_AuditEvents_NewValues', N'C') IS NULL ALTER TABLE audit.AuditEvents ADD CONSTRAINT CK_AuditEvents_NewValues CHECK (NewValues IS NULL OR ISJSON(NewValues) = 1);
IF OBJECT_ID(N'audit.CK_SecurityEvents_EventType', N'C') IS NULL ALTER TABLE audit.SecurityEvents ADD CONSTRAINT CK_SecurityEvents_EventType CHECK (EventType IN (N'LoginSuccess', N'LoginFailure', N'Logout', N'RoleGranted', N'RoleRevoked', N'PasswordChanged', N'AccountLocked', N'AccountUnlocked'));
GO

/* =============================================================================
   3. DEFAULT constraints — business defaults
   ============================================================================= */
-- organization
IF OBJECT_ID(N'organization.DF_Countries_IsActive', N'D') IS NULL ALTER TABLE organization.Countries ADD CONSTRAINT DF_Countries_IsActive DEFAULT (1) FOR IsActive;
IF OBJECT_ID(N'organization.DF_Schools_IsActive', N'D') IS NULL ALTER TABLE organization.Schools ADD CONSTRAINT DF_Schools_IsActive DEFAULT (1) FOR IsActive;
IF OBJECT_ID(N'organization.DF_Branches_WorkingDaysMask', N'D') IS NULL ALTER TABLE organization.Branches ADD CONSTRAINT DF_Branches_WorkingDaysMask DEFAULT (79) FOR WorkingDaysMask; -- Sun..Thu (ISO bits: Mon=1,Tue=2,Wed=4,Thu=8,Sun=64)
IF OBJECT_ID(N'organization.DF_Branches_IsActive', N'D') IS NULL ALTER TABLE organization.Branches ADD CONSTRAINT DF_Branches_IsActive DEFAULT (1) FOR IsActive;
IF OBJECT_ID(N'organization.DF_Buildings_IsActive', N'D') IS NULL ALTER TABLE organization.Buildings ADD CONSTRAINT DF_Buildings_IsActive DEFAULT (1) FOR IsActive;
IF OBJECT_ID(N'organization.DF_RoomTypes_IsActive', N'D') IS NULL ALTER TABLE organization.RoomTypes ADD CONSTRAINT DF_RoomTypes_IsActive DEFAULT (1) FOR IsActive;
IF OBJECT_ID(N'organization.DF_Rooms_IsActive', N'D') IS NULL ALTER TABLE organization.Rooms ADD CONSTRAINT DF_Rooms_IsActive DEFAULT (1) FOR IsActive;
IF OBJECT_ID(N'organization.DF_Departments_IsActive', N'D') IS NULL ALTER TABLE organization.Departments ADD CONSTRAINT DF_Departments_IsActive DEFAULT (1) FOR IsActive;
IF OBJECT_ID(N'organization.DF_DocumentNumberSeries_NextNumber', N'D') IS NULL ALTER TABLE organization.DocumentNumberSeries ADD CONSTRAINT DF_DocumentNumberSeries_NextNumber DEFAULT (1) FOR NextNumber;
IF OBJECT_ID(N'organization.DF_DocumentNumberSeries_PadLength', N'D') IS NULL ALTER TABLE organization.DocumentNumberSeries ADD CONSTRAINT DF_DocumentNumberSeries_PadLength DEFAULT (6) FOR PadLength;
GO
-- iam
IF OBJECT_ID(N'iam.DF_UserAccounts_AuthProvider', N'D') IS NULL ALTER TABLE iam.UserAccounts ADD CONSTRAINT DF_UserAccounts_AuthProvider DEFAULT (N'Local') FOR AuthProvider;
IF OBJECT_ID(N'iam.DF_UserAccounts_AccountStatus', N'D') IS NULL ALTER TABLE iam.UserAccounts ADD CONSTRAINT DF_UserAccounts_AccountStatus DEFAULT (N'Active') FOR AccountStatus;
IF OBJECT_ID(N'iam.DF_UserAccounts_FailedLoginCount', N'D') IS NULL ALTER TABLE iam.UserAccounts ADD CONSTRAINT DF_UserAccounts_FailedLoginCount DEFAULT (0) FOR FailedLoginCount;
IF OBJECT_ID(N'iam.DF_UserAccounts_PreferredLanguage', N'D') IS NULL ALTER TABLE iam.UserAccounts ADD CONSTRAINT DF_UserAccounts_PreferredLanguage DEFAULT (N'ar') FOR PreferredLanguage;
IF OBJECT_ID(N'iam.DF_Roles_IsSystem', N'D') IS NULL ALTER TABLE iam.Roles ADD CONSTRAINT DF_Roles_IsSystem DEFAULT (0) FOR IsSystem;
IF OBJECT_ID(N'iam.DF_UserRoles_ValidFrom', N'D') IS NULL ALTER TABLE iam.UserRoles ADD CONSTRAINT DF_UserRoles_ValidFrom DEFAULT (CONVERT(DATE, SYSUTCDATETIME())) FOR ValidFrom;
GO
-- people
IF OBJECT_ID(N'people.DF_PersonContacts_IsPrimary', N'D') IS NULL ALTER TABLE people.PersonContacts ADD CONSTRAINT DF_PersonContacts_IsPrimary DEFAULT (0) FOR IsPrimary;
IF OBJECT_ID(N'people.DF_PersonAddresses_IsPrimary', N'D') IS NULL ALTER TABLE people.PersonAddresses ADD CONSTRAINT DF_PersonAddresses_IsPrimary DEFAULT (0) FOR IsPrimary;
IF OBJECT_ID(N'people.DF_IdentityDocumentTypes_IsActive', N'D') IS NULL ALTER TABLE people.IdentityDocumentTypes ADD CONSTRAINT DF_IdentityDocumentTypes_IsActive DEFAULT (1) FOR IsActive;
IF OBJECT_ID(N'people.DF_Students_StudentStatus', N'D') IS NULL ALTER TABLE people.Students ADD CONSTRAINT DF_Students_StudentStatus DEFAULT (N'Active') FOR StudentStatus;
IF OBJECT_ID(N'people.DF_Guardians_PreferredLanguage', N'D') IS NULL ALTER TABLE people.Guardians ADD CONSTRAINT DF_Guardians_PreferredLanguage DEFAULT (N'ar') FOR PreferredLanguage;
IF OBJECT_ID(N'people.DF_Employees_EmploymentStatus', N'D') IS NULL ALTER TABLE people.Employees ADD CONSTRAINT DF_Employees_EmploymentStatus DEFAULT (N'Active') FOR EmploymentStatus;
IF OBJECT_ID(N'people.DF_RelationshipTypes_IsActive', N'D') IS NULL ALTER TABLE people.RelationshipTypes ADD CONSTRAINT DF_RelationshipTypes_IsActive DEFAULT (1) FOR IsActive;
IF OBJECT_ID(N'people.DF_StudentGuardians_IsPrimaryContact', N'D') IS NULL ALTER TABLE people.StudentGuardians ADD CONSTRAINT DF_StudentGuardians_IsPrimaryContact DEFAULT (0) FOR IsPrimaryContact;
IF OBJECT_ID(N'people.DF_StudentGuardians_HasCustody', N'D') IS NULL ALTER TABLE people.StudentGuardians ADD CONSTRAINT DF_StudentGuardians_HasCustody DEFAULT (1) FOR HasCustody;
IF OBJECT_ID(N'people.DF_StudentGuardians_CanPickUp', N'D') IS NULL ALTER TABLE people.StudentGuardians ADD CONSTRAINT DF_StudentGuardians_CanPickUp DEFAULT (1) FOR CanPickUp;
IF OBJECT_ID(N'people.DF_StudentGuardians_IsEmergencyContact', N'D') IS NULL ALTER TABLE people.StudentGuardians ADD CONSTRAINT DF_StudentGuardians_IsEmergencyContact DEFAULT (0) FOR IsEmergencyContact;
IF OBJECT_ID(N'people.DF_StudentGuardians_LivesWithStudent', N'D') IS NULL ALTER TABLE people.StudentGuardians ADD CONSTRAINT DF_StudentGuardians_LivesWithStudent DEFAULT (1) FOR LivesWithStudent;
GO
-- academic
IF OBJECT_ID(N'academic.DF_AcademicYears_YearStatus', N'D') IS NULL ALTER TABLE academic.AcademicYears ADD CONSTRAINT DF_AcademicYears_YearStatus DEFAULT (N'Planned') FOR YearStatus;
IF OBJECT_ID(N'academic.DF_GradeLevels_IsActive', N'D') IS NULL ALTER TABLE academic.GradeLevels ADD CONSTRAINT DF_GradeLevels_IsActive DEFAULT (1) FOR IsActive;
IF OBJECT_ID(N'academic.DF_Programs_IsActive', N'D') IS NULL ALTER TABLE academic.Programs ADD CONSTRAINT DF_Programs_IsActive DEFAULT (1) FOR IsActive;
IF OBJECT_ID(N'academic.DF_Subjects_IsActive', N'D') IS NULL ALTER TABLE academic.Subjects ADD CONSTRAINT DF_Subjects_IsActive DEFAULT (1) FOR IsActive;
IF OBJECT_ID(N'academic.DF_CurriculumSubjects_IsElective', N'D') IS NULL ALTER TABLE academic.CurriculumSubjects ADD CONSTRAINT DF_CurriculumSubjects_IsElective DEFAULT (0) FOR IsElective;
IF OBJECT_ID(N'academic.DF_CurriculumSubjects_ReportOrder', N'D') IS NULL ALTER TABLE academic.CurriculumSubjects ADD CONSTRAINT DF_CurriculumSubjects_ReportOrder DEFAULT (0) FOR ReportOrder;
IF OBJECT_ID(N'academic.DF_Sections_IsActive', N'D') IS NULL ALTER TABLE academic.Sections ADD CONSTRAINT DF_Sections_IsActive DEFAULT (1) FOR IsActive;
GO
-- enrollment
IF OBJECT_ID(N'enrollment.DF_Applications_ApplicationDate', N'D') IS NULL ALTER TABLE enrollment.Applications ADD CONSTRAINT DF_Applications_ApplicationDate DEFAULT (CONVERT(DATE, SYSUTCDATETIME())) FOR ApplicationDate;
IF OBJECT_ID(N'enrollment.DF_Applications_ApplicationStatus', N'D') IS NULL ALTER TABLE enrollment.Applications ADD CONSTRAINT DF_Applications_ApplicationStatus DEFAULT (N'Submitted') FOR ApplicationStatus;
IF OBJECT_ID(N'enrollment.DF_ApplicationStatusHistory_ChangedAt', N'D') IS NULL ALTER TABLE enrollment.ApplicationStatusHistory ADD CONSTRAINT DF_ApplicationStatusHistory_ChangedAt DEFAULT (SYSUTCDATETIME()) FOR ChangedAt;
IF OBJECT_ID(N'enrollment.DF_ApplicationStatusHistory_ChangedBy', N'D') IS NULL ALTER TABLE enrollment.ApplicationStatusHistory ADD CONSTRAINT DF_ApplicationStatusHistory_ChangedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR ChangedBy;
IF OBJECT_ID(N'enrollment.DF_Enrollments_EnrollmentStatus', N'D') IS NULL ALTER TABLE enrollment.Enrollments ADD CONSTRAINT DF_Enrollments_EnrollmentStatus DEFAULT (N'Enrolled') FOR EnrollmentStatus;
GO
-- timetable
IF OBJECT_ID(N'timetable.DF_BellSchedules_IsDefault', N'D') IS NULL ALTER TABLE timetable.BellSchedules ADD CONSTRAINT DF_BellSchedules_IsDefault DEFAULT (0) FOR IsDefault;
IF OBJECT_ID(N'timetable.DF_Periods_IsBreak', N'D') IS NULL ALTER TABLE timetable.Periods ADD CONSTRAINT DF_Periods_IsBreak DEFAULT (0) FOR IsBreak;
IF OBJECT_ID(N'timetable.DF_Timetables_VersionNumber', N'D') IS NULL ALTER TABLE timetable.Timetables ADD CONSTRAINT DF_Timetables_VersionNumber DEFAULT (1) FOR VersionNumber;
IF OBJECT_ID(N'timetable.DF_Timetables_TimetableStatus', N'D') IS NULL ALTER TABLE timetable.Timetables ADD CONSTRAINT DF_Timetables_TimetableStatus DEFAULT (N'Draft') FOR TimetableStatus;
GO
-- attendance
IF OBJECT_ID(N'attendance.DF_AttendanceStatuses_IsExcused', N'D') IS NULL ALTER TABLE attendance.AttendanceStatuses ADD CONSTRAINT DF_AttendanceStatuses_IsExcused DEFAULT (0) FOR IsExcused;
IF OBJECT_ID(N'attendance.DF_AttendanceStatuses_SortOrder', N'D') IS NULL ALTER TABLE attendance.AttendanceStatuses ADD CONSTRAINT DF_AttendanceStatuses_SortOrder DEFAULT (0) FOR SortOrder;
IF OBJECT_ID(N'attendance.DF_AttendanceStatuses_IsActive', N'D') IS NULL ALTER TABLE attendance.AttendanceStatuses ADD CONSTRAINT DF_AttendanceStatuses_IsActive DEFAULT (1) FOR IsActive;
IF OBJECT_ID(N'attendance.DF_AttendanceSessions_TakenAt', N'D') IS NULL ALTER TABLE attendance.AttendanceSessions ADD CONSTRAINT DF_AttendanceSessions_TakenAt DEFAULT (SYSUTCDATETIME()) FOR TakenAt;
GO
-- assessment
IF OBJECT_ID(N'assessment.DF_GradingScales_IsActive', N'D') IS NULL ALTER TABLE assessment.GradingScales ADD CONSTRAINT DF_GradingScales_IsActive DEFAULT (1) FOR IsActive;
IF OBJECT_ID(N'assessment.DF_AssessmentTypes_IsActive', N'D') IS NULL ALTER TABLE assessment.AssessmentTypes ADD CONSTRAINT DF_AssessmentTypes_IsActive DEFAULT (1) FOR IsActive;
IF OBJECT_ID(N'assessment.DF_Assessments_IsPublished', N'D') IS NULL ALTER TABLE assessment.Assessments ADD CONSTRAINT DF_Assessments_IsPublished DEFAULT (0) FOR IsPublished;
IF OBJECT_ID(N'assessment.DF_AssessmentResults_IsAbsent', N'D') IS NULL ALTER TABLE assessment.AssessmentResults ADD CONSTRAINT DF_AssessmentResults_IsAbsent DEFAULT (0) FOR IsAbsent;
IF OBJECT_ID(N'assessment.DF_AssessmentResults_IsExempt', N'D') IS NULL ALTER TABLE assessment.AssessmentResults ADD CONSTRAINT DF_AssessmentResults_IsExempt DEFAULT (0) FOR IsExempt;
IF OBJECT_ID(N'assessment.DF_ReportCards_VersionNumber', N'D') IS NULL ALTER TABLE assessment.ReportCards ADD CONSTRAINT DF_ReportCards_VersionNumber DEFAULT (1) FOR VersionNumber;
IF OBJECT_ID(N'assessment.DF_ReportCards_ReportCardStatus', N'D') IS NULL ALTER TABLE assessment.ReportCards ADD CONSTRAINT DF_ReportCards_ReportCardStatus DEFAULT (N'Draft') FOR ReportCardStatus;
IF OBJECT_ID(N'assessment.DF_ReportCards_GeneratedAt', N'D') IS NULL ALTER TABLE assessment.ReportCards ADD CONSTRAINT DF_ReportCards_GeneratedAt DEFAULT (SYSUTCDATETIME()) FOR GeneratedAt;
GO
-- finance
IF OBJECT_ID(N'finance.DF_Currencies_IsActive', N'D') IS NULL ALTER TABLE finance.Currencies ADD CONSTRAINT DF_Currencies_IsActive DEFAULT (1) FOR IsActive;
IF OBJECT_ID(N'finance.DF_FeeTypes_IsTaxable', N'D') IS NULL ALTER TABLE finance.FeeTypes ADD CONSTRAINT DF_FeeTypes_IsTaxable DEFAULT (0) FOR IsTaxable;
IF OBJECT_ID(N'finance.DF_FeeTypes_TaxPercent', N'D') IS NULL ALTER TABLE finance.FeeTypes ADD CONSTRAINT DF_FeeTypes_TaxPercent DEFAULT (0) FOR TaxPercent;
IF OBJECT_ID(N'finance.DF_FeeTypes_IsActive', N'D') IS NULL ALTER TABLE finance.FeeTypes ADD CONSTRAINT DF_FeeTypes_IsActive DEFAULT (1) FOR IsActive;
IF OBJECT_ID(N'finance.DF_FeeStructures_IsActive', N'D') IS NULL ALTER TABLE finance.FeeStructures ADD CONSTRAINT DF_FeeStructures_IsActive DEFAULT (1) FOR IsActive;
IF OBJECT_ID(N'finance.DF_FeeStructureItems_IsMandatory', N'D') IS NULL ALTER TABLE finance.FeeStructureItems ADD CONSTRAINT DF_FeeStructureItems_IsMandatory DEFAULT (1) FOR IsMandatory;
IF OBJECT_ID(N'finance.DF_FeeStructureItems_IsInstallable', N'D') IS NULL ALTER TABLE finance.FeeStructureItems ADD CONSTRAINT DF_FeeStructureItems_IsInstallable DEFAULT (1) FOR IsInstallable;
IF OBJECT_ID(N'finance.DF_DiscountTypes_IsActive', N'D') IS NULL ALTER TABLE finance.DiscountTypes ADD CONSTRAINT DF_DiscountTypes_IsActive DEFAULT (1) FOR IsActive;
IF OBJECT_ID(N'finance.DF_StudentDiscounts_IsActive', N'D') IS NULL ALTER TABLE finance.StudentDiscounts ADD CONSTRAINT DF_StudentDiscounts_IsActive DEFAULT (1) FOR IsActive;
IF OBJECT_ID(N'finance.DF_Sponsors_IsActive', N'D') IS NULL ALTER TABLE finance.Sponsors ADD CONSTRAINT DF_Sponsors_IsActive DEFAULT (1) FOR IsActive;
IF OBJECT_ID(N'finance.DF_Payers_IsActive', N'D') IS NULL ALTER TABLE finance.Payers ADD CONSTRAINT DF_Payers_IsActive DEFAULT (1) FOR IsActive;
IF OBJECT_ID(N'finance.DF_StudentPayers_ResponsibilityPercent', N'D') IS NULL ALTER TABLE finance.StudentPayers ADD CONSTRAINT DF_StudentPayers_ResponsibilityPercent DEFAULT (100) FOR ResponsibilityPercent;
IF OBJECT_ID(N'finance.DF_Invoices_DiscountAmount', N'D') IS NULL ALTER TABLE finance.Invoices ADD CONSTRAINT DF_Invoices_DiscountAmount DEFAULT (0) FOR DiscountAmount;
IF OBJECT_ID(N'finance.DF_Invoices_TaxAmount', N'D') IS NULL ALTER TABLE finance.Invoices ADD CONSTRAINT DF_Invoices_TaxAmount DEFAULT (0) FOR TaxAmount;
IF OBJECT_ID(N'finance.DF_Invoices_PaidAmount', N'D') IS NULL ALTER TABLE finance.Invoices ADD CONSTRAINT DF_Invoices_PaidAmount DEFAULT (0) FOR PaidAmount;
IF OBJECT_ID(N'finance.DF_Invoices_CreditedAmount', N'D') IS NULL ALTER TABLE finance.Invoices ADD CONSTRAINT DF_Invoices_CreditedAmount DEFAULT (0) FOR CreditedAmount;
IF OBJECT_ID(N'finance.DF_Invoices_InvoiceStatus', N'D') IS NULL ALTER TABLE finance.Invoices ADD CONSTRAINT DF_Invoices_InvoiceStatus DEFAULT (N'Issued') FOR InvoiceStatus;
IF OBJECT_ID(N'finance.DF_Invoices_IssuedAt', N'D') IS NULL ALTER TABLE finance.Invoices ADD CONSTRAINT DF_Invoices_IssuedAt DEFAULT (SYSUTCDATETIME()) FOR IssuedAt;
IF OBJECT_ID(N'finance.DF_InvoiceLines_Quantity', N'D') IS NULL ALTER TABLE finance.InvoiceLines ADD CONSTRAINT DF_InvoiceLines_Quantity DEFAULT (1) FOR Quantity;
IF OBJECT_ID(N'finance.DF_InvoiceLines_DiscountAmount', N'D') IS NULL ALTER TABLE finance.InvoiceLines ADD CONSTRAINT DF_InvoiceLines_DiscountAmount DEFAULT (0) FOR DiscountAmount;
IF OBJECT_ID(N'finance.DF_InvoiceLines_TaxAmount', N'D') IS NULL ALTER TABLE finance.InvoiceLines ADD CONSTRAINT DF_InvoiceLines_TaxAmount DEFAULT (0) FOR TaxAmount;
IF OBJECT_ID(N'finance.DF_PaymentMethods_RequiresReference', N'D') IS NULL ALTER TABLE finance.PaymentMethods ADD CONSTRAINT DF_PaymentMethods_RequiresReference DEFAULT (0) FOR RequiresReference;
IF OBJECT_ID(N'finance.DF_PaymentMethods_IsActive', N'D') IS NULL ALTER TABLE finance.PaymentMethods ADD CONSTRAINT DF_PaymentMethods_IsActive DEFAULT (1) FOR IsActive;
IF OBJECT_ID(N'finance.DF_Payments_PaymentStatus', N'D') IS NULL ALTER TABLE finance.Payments ADD CONSTRAINT DF_Payments_PaymentStatus DEFAULT (N'Received') FOR PaymentStatus;
GO
-- audit
IF OBJECT_ID(N'audit.DF_AuditEvents_UserAccountId', N'D') IS NULL ALTER TABLE audit.AuditEvents ADD CONSTRAINT DF_AuditEvents_UserAccountId DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UserAccountId;
IF OBJECT_ID(N'audit.DF_AuditEvents_HostName', N'D') IS NULL ALTER TABLE audit.AuditEvents ADD CONSTRAINT DF_AuditEvents_HostName DEFAULT (HOST_NAME()) FOR HostName;
IF OBJECT_ID(N'audit.DF_AuditEvents_OccurredAt', N'D') IS NULL ALTER TABLE audit.AuditEvents ADD CONSTRAINT DF_AuditEvents_OccurredAt DEFAULT (SYSUTCDATETIME()) FOR OccurredAt;
IF OBJECT_ID(N'audit.DF_SecurityEvents_OccurredAt', N'D') IS NULL ALTER TABLE audit.SecurityEvents ADD CONSTRAINT DF_SecurityEvents_OccurredAt DEFAULT (SYSUTCDATETIME()) FOR OccurredAt;
GO

/* =============================================================================
   4. DEFAULT constraints — standard audit columns
      CreatedAt/UpdatedAt = SYSUTCDATETIME();
      CreatedBy/UpdatedBy = the application user set by the caller with
      EXEC sys.sp_set_session_context @key = N'UserAccountId', @value = <id>;
   ============================================================================= */
IF OBJECT_ID(N'organization.DF_Countries_CreatedAt', N'D') IS NULL ALTER TABLE organization.Countries ADD CONSTRAINT DF_Countries_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'organization.DF_Countries_CreatedBy', N'D') IS NULL ALTER TABLE organization.Countries ADD CONSTRAINT DF_Countries_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'organization.DF_Countries_UpdatedAt', N'D') IS NULL ALTER TABLE organization.Countries ADD CONSTRAINT DF_Countries_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'organization.DF_Countries_UpdatedBy', N'D') IS NULL ALTER TABLE organization.Countries ADD CONSTRAINT DF_Countries_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'organization.DF_Schools_CreatedAt', N'D') IS NULL ALTER TABLE organization.Schools ADD CONSTRAINT DF_Schools_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'organization.DF_Schools_CreatedBy', N'D') IS NULL ALTER TABLE organization.Schools ADD CONSTRAINT DF_Schools_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'organization.DF_Schools_UpdatedAt', N'D') IS NULL ALTER TABLE organization.Schools ADD CONSTRAINT DF_Schools_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'organization.DF_Schools_UpdatedBy', N'D') IS NULL ALTER TABLE organization.Schools ADD CONSTRAINT DF_Schools_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'organization.DF_Branches_CreatedAt', N'D') IS NULL ALTER TABLE organization.Branches ADD CONSTRAINT DF_Branches_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'organization.DF_Branches_CreatedBy', N'D') IS NULL ALTER TABLE organization.Branches ADD CONSTRAINT DF_Branches_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'organization.DF_Branches_UpdatedAt', N'D') IS NULL ALTER TABLE organization.Branches ADD CONSTRAINT DF_Branches_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'organization.DF_Branches_UpdatedBy', N'D') IS NULL ALTER TABLE organization.Branches ADD CONSTRAINT DF_Branches_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'organization.DF_Buildings_CreatedAt', N'D') IS NULL ALTER TABLE organization.Buildings ADD CONSTRAINT DF_Buildings_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'organization.DF_Buildings_CreatedBy', N'D') IS NULL ALTER TABLE organization.Buildings ADD CONSTRAINT DF_Buildings_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'organization.DF_Buildings_UpdatedAt', N'D') IS NULL ALTER TABLE organization.Buildings ADD CONSTRAINT DF_Buildings_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'organization.DF_Buildings_UpdatedBy', N'D') IS NULL ALTER TABLE organization.Buildings ADD CONSTRAINT DF_Buildings_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'organization.DF_RoomTypes_CreatedAt', N'D') IS NULL ALTER TABLE organization.RoomTypes ADD CONSTRAINT DF_RoomTypes_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'organization.DF_RoomTypes_CreatedBy', N'D') IS NULL ALTER TABLE organization.RoomTypes ADD CONSTRAINT DF_RoomTypes_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'organization.DF_RoomTypes_UpdatedAt', N'D') IS NULL ALTER TABLE organization.RoomTypes ADD CONSTRAINT DF_RoomTypes_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'organization.DF_RoomTypes_UpdatedBy', N'D') IS NULL ALTER TABLE organization.RoomTypes ADD CONSTRAINT DF_RoomTypes_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'organization.DF_Rooms_CreatedAt', N'D') IS NULL ALTER TABLE organization.Rooms ADD CONSTRAINT DF_Rooms_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'organization.DF_Rooms_CreatedBy', N'D') IS NULL ALTER TABLE organization.Rooms ADD CONSTRAINT DF_Rooms_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'organization.DF_Rooms_UpdatedAt', N'D') IS NULL ALTER TABLE organization.Rooms ADD CONSTRAINT DF_Rooms_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'organization.DF_Rooms_UpdatedBy', N'D') IS NULL ALTER TABLE organization.Rooms ADD CONSTRAINT DF_Rooms_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'organization.DF_Departments_CreatedAt', N'D') IS NULL ALTER TABLE organization.Departments ADD CONSTRAINT DF_Departments_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'organization.DF_Departments_CreatedBy', N'D') IS NULL ALTER TABLE organization.Departments ADD CONSTRAINT DF_Departments_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'organization.DF_Departments_UpdatedAt', N'D') IS NULL ALTER TABLE organization.Departments ADD CONSTRAINT DF_Departments_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'organization.DF_Departments_UpdatedBy', N'D') IS NULL ALTER TABLE organization.Departments ADD CONSTRAINT DF_Departments_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'organization.DF_DocumentNumberSeries_CreatedAt', N'D') IS NULL ALTER TABLE organization.DocumentNumberSeries ADD CONSTRAINT DF_DocumentNumberSeries_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'organization.DF_DocumentNumberSeries_CreatedBy', N'D') IS NULL ALTER TABLE organization.DocumentNumberSeries ADD CONSTRAINT DF_DocumentNumberSeries_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'organization.DF_DocumentNumberSeries_UpdatedAt', N'D') IS NULL ALTER TABLE organization.DocumentNumberSeries ADD CONSTRAINT DF_DocumentNumberSeries_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'organization.DF_DocumentNumberSeries_UpdatedBy', N'D') IS NULL ALTER TABLE organization.DocumentNumberSeries ADD CONSTRAINT DF_DocumentNumberSeries_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'iam.DF_UserAccounts_CreatedAt', N'D') IS NULL ALTER TABLE iam.UserAccounts ADD CONSTRAINT DF_UserAccounts_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'iam.DF_UserAccounts_CreatedBy', N'D') IS NULL ALTER TABLE iam.UserAccounts ADD CONSTRAINT DF_UserAccounts_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'iam.DF_UserAccounts_UpdatedAt', N'D') IS NULL ALTER TABLE iam.UserAccounts ADD CONSTRAINT DF_UserAccounts_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'iam.DF_UserAccounts_UpdatedBy', N'D') IS NULL ALTER TABLE iam.UserAccounts ADD CONSTRAINT DF_UserAccounts_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'iam.DF_Roles_CreatedAt', N'D') IS NULL ALTER TABLE iam.Roles ADD CONSTRAINT DF_Roles_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'iam.DF_Roles_CreatedBy', N'D') IS NULL ALTER TABLE iam.Roles ADD CONSTRAINT DF_Roles_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'iam.DF_Roles_UpdatedAt', N'D') IS NULL ALTER TABLE iam.Roles ADD CONSTRAINT DF_Roles_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'iam.DF_Roles_UpdatedBy', N'D') IS NULL ALTER TABLE iam.Roles ADD CONSTRAINT DF_Roles_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'iam.DF_Permissions_CreatedAt', N'D') IS NULL ALTER TABLE iam.Permissions ADD CONSTRAINT DF_Permissions_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'iam.DF_Permissions_CreatedBy', N'D') IS NULL ALTER TABLE iam.Permissions ADD CONSTRAINT DF_Permissions_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'iam.DF_Permissions_UpdatedAt', N'D') IS NULL ALTER TABLE iam.Permissions ADD CONSTRAINT DF_Permissions_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'iam.DF_Permissions_UpdatedBy', N'D') IS NULL ALTER TABLE iam.Permissions ADD CONSTRAINT DF_Permissions_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'iam.DF_RolePermissions_CreatedAt', N'D') IS NULL ALTER TABLE iam.RolePermissions ADD CONSTRAINT DF_RolePermissions_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'iam.DF_RolePermissions_CreatedBy', N'D') IS NULL ALTER TABLE iam.RolePermissions ADD CONSTRAINT DF_RolePermissions_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'iam.DF_RolePermissions_UpdatedAt', N'D') IS NULL ALTER TABLE iam.RolePermissions ADD CONSTRAINT DF_RolePermissions_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'iam.DF_RolePermissions_UpdatedBy', N'D') IS NULL ALTER TABLE iam.RolePermissions ADD CONSTRAINT DF_RolePermissions_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'iam.DF_UserRoles_CreatedAt', N'D') IS NULL ALTER TABLE iam.UserRoles ADD CONSTRAINT DF_UserRoles_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'iam.DF_UserRoles_CreatedBy', N'D') IS NULL ALTER TABLE iam.UserRoles ADD CONSTRAINT DF_UserRoles_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'iam.DF_UserRoles_UpdatedAt', N'D') IS NULL ALTER TABLE iam.UserRoles ADD CONSTRAINT DF_UserRoles_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'iam.DF_UserRoles_UpdatedBy', N'D') IS NULL ALTER TABLE iam.UserRoles ADD CONSTRAINT DF_UserRoles_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'people.DF_Persons_CreatedAt', N'D') IS NULL ALTER TABLE people.Persons ADD CONSTRAINT DF_Persons_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'people.DF_Persons_CreatedBy', N'D') IS NULL ALTER TABLE people.Persons ADD CONSTRAINT DF_Persons_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'people.DF_Persons_UpdatedAt', N'D') IS NULL ALTER TABLE people.Persons ADD CONSTRAINT DF_Persons_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'people.DF_Persons_UpdatedBy', N'D') IS NULL ALTER TABLE people.Persons ADD CONSTRAINT DF_Persons_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'people.DF_PersonContacts_CreatedAt', N'D') IS NULL ALTER TABLE people.PersonContacts ADD CONSTRAINT DF_PersonContacts_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'people.DF_PersonContacts_CreatedBy', N'D') IS NULL ALTER TABLE people.PersonContacts ADD CONSTRAINT DF_PersonContacts_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'people.DF_PersonContacts_UpdatedAt', N'D') IS NULL ALTER TABLE people.PersonContacts ADD CONSTRAINT DF_PersonContacts_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'people.DF_PersonContacts_UpdatedBy', N'D') IS NULL ALTER TABLE people.PersonContacts ADD CONSTRAINT DF_PersonContacts_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'people.DF_PersonAddresses_CreatedAt', N'D') IS NULL ALTER TABLE people.PersonAddresses ADD CONSTRAINT DF_PersonAddresses_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'people.DF_PersonAddresses_CreatedBy', N'D') IS NULL ALTER TABLE people.PersonAddresses ADD CONSTRAINT DF_PersonAddresses_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'people.DF_PersonAddresses_UpdatedAt', N'D') IS NULL ALTER TABLE people.PersonAddresses ADD CONSTRAINT DF_PersonAddresses_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'people.DF_PersonAddresses_UpdatedBy', N'D') IS NULL ALTER TABLE people.PersonAddresses ADD CONSTRAINT DF_PersonAddresses_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'people.DF_IdentityDocumentTypes_CreatedAt', N'D') IS NULL ALTER TABLE people.IdentityDocumentTypes ADD CONSTRAINT DF_IdentityDocumentTypes_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'people.DF_IdentityDocumentTypes_CreatedBy', N'D') IS NULL ALTER TABLE people.IdentityDocumentTypes ADD CONSTRAINT DF_IdentityDocumentTypes_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'people.DF_IdentityDocumentTypes_UpdatedAt', N'D') IS NULL ALTER TABLE people.IdentityDocumentTypes ADD CONSTRAINT DF_IdentityDocumentTypes_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'people.DF_IdentityDocumentTypes_UpdatedBy', N'D') IS NULL ALTER TABLE people.IdentityDocumentTypes ADD CONSTRAINT DF_IdentityDocumentTypes_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'people.DF_PersonIdentityDocuments_CreatedAt', N'D') IS NULL ALTER TABLE people.PersonIdentityDocuments ADD CONSTRAINT DF_PersonIdentityDocuments_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'people.DF_PersonIdentityDocuments_CreatedBy', N'D') IS NULL ALTER TABLE people.PersonIdentityDocuments ADD CONSTRAINT DF_PersonIdentityDocuments_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'people.DF_PersonIdentityDocuments_UpdatedAt', N'D') IS NULL ALTER TABLE people.PersonIdentityDocuments ADD CONSTRAINT DF_PersonIdentityDocuments_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'people.DF_PersonIdentityDocuments_UpdatedBy', N'D') IS NULL ALTER TABLE people.PersonIdentityDocuments ADD CONSTRAINT DF_PersonIdentityDocuments_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'people.DF_Students_CreatedAt', N'D') IS NULL ALTER TABLE people.Students ADD CONSTRAINT DF_Students_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'people.DF_Students_CreatedBy', N'D') IS NULL ALTER TABLE people.Students ADD CONSTRAINT DF_Students_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'people.DF_Students_UpdatedAt', N'D') IS NULL ALTER TABLE people.Students ADD CONSTRAINT DF_Students_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'people.DF_Students_UpdatedBy', N'D') IS NULL ALTER TABLE people.Students ADD CONSTRAINT DF_Students_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'people.DF_Guardians_CreatedAt', N'D') IS NULL ALTER TABLE people.Guardians ADD CONSTRAINT DF_Guardians_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'people.DF_Guardians_CreatedBy', N'D') IS NULL ALTER TABLE people.Guardians ADD CONSTRAINT DF_Guardians_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'people.DF_Guardians_UpdatedAt', N'D') IS NULL ALTER TABLE people.Guardians ADD CONSTRAINT DF_Guardians_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'people.DF_Guardians_UpdatedBy', N'D') IS NULL ALTER TABLE people.Guardians ADD CONSTRAINT DF_Guardians_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'people.DF_Employees_CreatedAt', N'D') IS NULL ALTER TABLE people.Employees ADD CONSTRAINT DF_Employees_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'people.DF_Employees_CreatedBy', N'D') IS NULL ALTER TABLE people.Employees ADD CONSTRAINT DF_Employees_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'people.DF_Employees_UpdatedAt', N'D') IS NULL ALTER TABLE people.Employees ADD CONSTRAINT DF_Employees_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'people.DF_Employees_UpdatedBy', N'D') IS NULL ALTER TABLE people.Employees ADD CONSTRAINT DF_Employees_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'people.DF_Teachers_CreatedAt', N'D') IS NULL ALTER TABLE people.Teachers ADD CONSTRAINT DF_Teachers_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'people.DF_Teachers_CreatedBy', N'D') IS NULL ALTER TABLE people.Teachers ADD CONSTRAINT DF_Teachers_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'people.DF_Teachers_UpdatedAt', N'D') IS NULL ALTER TABLE people.Teachers ADD CONSTRAINT DF_Teachers_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'people.DF_Teachers_UpdatedBy', N'D') IS NULL ALTER TABLE people.Teachers ADD CONSTRAINT DF_Teachers_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'people.DF_RelationshipTypes_CreatedAt', N'D') IS NULL ALTER TABLE people.RelationshipTypes ADD CONSTRAINT DF_RelationshipTypes_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'people.DF_RelationshipTypes_CreatedBy', N'D') IS NULL ALTER TABLE people.RelationshipTypes ADD CONSTRAINT DF_RelationshipTypes_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'people.DF_RelationshipTypes_UpdatedAt', N'D') IS NULL ALTER TABLE people.RelationshipTypes ADD CONSTRAINT DF_RelationshipTypes_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'people.DF_RelationshipTypes_UpdatedBy', N'D') IS NULL ALTER TABLE people.RelationshipTypes ADD CONSTRAINT DF_RelationshipTypes_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'people.DF_StudentGuardians_CreatedAt', N'D') IS NULL ALTER TABLE people.StudentGuardians ADD CONSTRAINT DF_StudentGuardians_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'people.DF_StudentGuardians_CreatedBy', N'D') IS NULL ALTER TABLE people.StudentGuardians ADD CONSTRAINT DF_StudentGuardians_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'people.DF_StudentGuardians_UpdatedAt', N'D') IS NULL ALTER TABLE people.StudentGuardians ADD CONSTRAINT DF_StudentGuardians_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'people.DF_StudentGuardians_UpdatedBy', N'D') IS NULL ALTER TABLE people.StudentGuardians ADD CONSTRAINT DF_StudentGuardians_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'academic.DF_AcademicYears_CreatedAt', N'D') IS NULL ALTER TABLE academic.AcademicYears ADD CONSTRAINT DF_AcademicYears_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'academic.DF_AcademicYears_CreatedBy', N'D') IS NULL ALTER TABLE academic.AcademicYears ADD CONSTRAINT DF_AcademicYears_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'academic.DF_AcademicYears_UpdatedAt', N'D') IS NULL ALTER TABLE academic.AcademicYears ADD CONSTRAINT DF_AcademicYears_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'academic.DF_AcademicYears_UpdatedBy', N'D') IS NULL ALTER TABLE academic.AcademicYears ADD CONSTRAINT DF_AcademicYears_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'academic.DF_Terms_CreatedAt', N'D') IS NULL ALTER TABLE academic.Terms ADD CONSTRAINT DF_Terms_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'academic.DF_Terms_CreatedBy', N'D') IS NULL ALTER TABLE academic.Terms ADD CONSTRAINT DF_Terms_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'academic.DF_Terms_UpdatedAt', N'D') IS NULL ALTER TABLE academic.Terms ADD CONSTRAINT DF_Terms_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'academic.DF_Terms_UpdatedBy', N'D') IS NULL ALTER TABLE academic.Terms ADD CONSTRAINT DF_Terms_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'academic.DF_Holidays_CreatedAt', N'D') IS NULL ALTER TABLE academic.Holidays ADD CONSTRAINT DF_Holidays_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'academic.DF_Holidays_CreatedBy', N'D') IS NULL ALTER TABLE academic.Holidays ADD CONSTRAINT DF_Holidays_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'academic.DF_Holidays_UpdatedAt', N'D') IS NULL ALTER TABLE academic.Holidays ADD CONSTRAINT DF_Holidays_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'academic.DF_Holidays_UpdatedBy', N'D') IS NULL ALTER TABLE academic.Holidays ADD CONSTRAINT DF_Holidays_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'academic.DF_GradeLevels_CreatedAt', N'D') IS NULL ALTER TABLE academic.GradeLevels ADD CONSTRAINT DF_GradeLevels_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'academic.DF_GradeLevels_CreatedBy', N'D') IS NULL ALTER TABLE academic.GradeLevels ADD CONSTRAINT DF_GradeLevels_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'academic.DF_GradeLevels_UpdatedAt', N'D') IS NULL ALTER TABLE academic.GradeLevels ADD CONSTRAINT DF_GradeLevels_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'academic.DF_GradeLevels_UpdatedBy', N'D') IS NULL ALTER TABLE academic.GradeLevels ADD CONSTRAINT DF_GradeLevels_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'academic.DF_Programs_CreatedAt', N'D') IS NULL ALTER TABLE academic.Programs ADD CONSTRAINT DF_Programs_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'academic.DF_Programs_CreatedBy', N'D') IS NULL ALTER TABLE academic.Programs ADD CONSTRAINT DF_Programs_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'academic.DF_Programs_UpdatedAt', N'D') IS NULL ALTER TABLE academic.Programs ADD CONSTRAINT DF_Programs_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'academic.DF_Programs_UpdatedBy', N'D') IS NULL ALTER TABLE academic.Programs ADD CONSTRAINT DF_Programs_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'academic.DF_Subjects_CreatedAt', N'D') IS NULL ALTER TABLE academic.Subjects ADD CONSTRAINT DF_Subjects_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'academic.DF_Subjects_CreatedBy', N'D') IS NULL ALTER TABLE academic.Subjects ADD CONSTRAINT DF_Subjects_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'academic.DF_Subjects_UpdatedAt', N'D') IS NULL ALTER TABLE academic.Subjects ADD CONSTRAINT DF_Subjects_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'academic.DF_Subjects_UpdatedBy', N'D') IS NULL ALTER TABLE academic.Subjects ADD CONSTRAINT DF_Subjects_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'academic.DF_CurriculumSubjects_CreatedAt', N'D') IS NULL ALTER TABLE academic.CurriculumSubjects ADD CONSTRAINT DF_CurriculumSubjects_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'academic.DF_CurriculumSubjects_CreatedBy', N'D') IS NULL ALTER TABLE academic.CurriculumSubjects ADD CONSTRAINT DF_CurriculumSubjects_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'academic.DF_CurriculumSubjects_UpdatedAt', N'D') IS NULL ALTER TABLE academic.CurriculumSubjects ADD CONSTRAINT DF_CurriculumSubjects_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'academic.DF_CurriculumSubjects_UpdatedBy', N'D') IS NULL ALTER TABLE academic.CurriculumSubjects ADD CONSTRAINT DF_CurriculumSubjects_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'academic.DF_Sections_CreatedAt', N'D') IS NULL ALTER TABLE academic.Sections ADD CONSTRAINT DF_Sections_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'academic.DF_Sections_CreatedBy', N'D') IS NULL ALTER TABLE academic.Sections ADD CONSTRAINT DF_Sections_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'academic.DF_Sections_UpdatedAt', N'D') IS NULL ALTER TABLE academic.Sections ADD CONSTRAINT DF_Sections_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'academic.DF_Sections_UpdatedBy', N'D') IS NULL ALTER TABLE academic.Sections ADD CONSTRAINT DF_Sections_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'academic.DF_TeachingAssignments_CreatedAt', N'D') IS NULL ALTER TABLE academic.TeachingAssignments ADD CONSTRAINT DF_TeachingAssignments_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'academic.DF_TeachingAssignments_CreatedBy', N'D') IS NULL ALTER TABLE academic.TeachingAssignments ADD CONSTRAINT DF_TeachingAssignments_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'academic.DF_TeachingAssignments_UpdatedAt', N'D') IS NULL ALTER TABLE academic.TeachingAssignments ADD CONSTRAINT DF_TeachingAssignments_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'academic.DF_TeachingAssignments_UpdatedBy', N'D') IS NULL ALTER TABLE academic.TeachingAssignments ADD CONSTRAINT DF_TeachingAssignments_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'enrollment.DF_Applications_CreatedAt', N'D') IS NULL ALTER TABLE enrollment.Applications ADD CONSTRAINT DF_Applications_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'enrollment.DF_Applications_CreatedBy', N'D') IS NULL ALTER TABLE enrollment.Applications ADD CONSTRAINT DF_Applications_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'enrollment.DF_Applications_UpdatedAt', N'D') IS NULL ALTER TABLE enrollment.Applications ADD CONSTRAINT DF_Applications_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'enrollment.DF_Applications_UpdatedBy', N'D') IS NULL ALTER TABLE enrollment.Applications ADD CONSTRAINT DF_Applications_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'enrollment.DF_Enrollments_CreatedAt', N'D') IS NULL ALTER TABLE enrollment.Enrollments ADD CONSTRAINT DF_Enrollments_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'enrollment.DF_Enrollments_CreatedBy', N'D') IS NULL ALTER TABLE enrollment.Enrollments ADD CONSTRAINT DF_Enrollments_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'enrollment.DF_Enrollments_UpdatedAt', N'D') IS NULL ALTER TABLE enrollment.Enrollments ADD CONSTRAINT DF_Enrollments_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'enrollment.DF_Enrollments_UpdatedBy', N'D') IS NULL ALTER TABLE enrollment.Enrollments ADD CONSTRAINT DF_Enrollments_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'enrollment.DF_SectionAssignments_CreatedAt', N'D') IS NULL ALTER TABLE enrollment.SectionAssignments ADD CONSTRAINT DF_SectionAssignments_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'enrollment.DF_SectionAssignments_CreatedBy', N'D') IS NULL ALTER TABLE enrollment.SectionAssignments ADD CONSTRAINT DF_SectionAssignments_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'enrollment.DF_SectionAssignments_UpdatedAt', N'D') IS NULL ALTER TABLE enrollment.SectionAssignments ADD CONSTRAINT DF_SectionAssignments_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'enrollment.DF_SectionAssignments_UpdatedBy', N'D') IS NULL ALTER TABLE enrollment.SectionAssignments ADD CONSTRAINT DF_SectionAssignments_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'enrollment.DF_EnrollmentSubjects_CreatedAt', N'D') IS NULL ALTER TABLE enrollment.EnrollmentSubjects ADD CONSTRAINT DF_EnrollmentSubjects_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'enrollment.DF_EnrollmentSubjects_CreatedBy', N'D') IS NULL ALTER TABLE enrollment.EnrollmentSubjects ADD CONSTRAINT DF_EnrollmentSubjects_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'enrollment.DF_EnrollmentSubjects_UpdatedAt', N'D') IS NULL ALTER TABLE enrollment.EnrollmentSubjects ADD CONSTRAINT DF_EnrollmentSubjects_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'enrollment.DF_EnrollmentSubjects_UpdatedBy', N'D') IS NULL ALTER TABLE enrollment.EnrollmentSubjects ADD CONSTRAINT DF_EnrollmentSubjects_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'timetable.DF_BellSchedules_CreatedAt', N'D') IS NULL ALTER TABLE timetable.BellSchedules ADD CONSTRAINT DF_BellSchedules_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'timetable.DF_BellSchedules_CreatedBy', N'D') IS NULL ALTER TABLE timetable.BellSchedules ADD CONSTRAINT DF_BellSchedules_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'timetable.DF_BellSchedules_UpdatedAt', N'D') IS NULL ALTER TABLE timetable.BellSchedules ADD CONSTRAINT DF_BellSchedules_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'timetable.DF_BellSchedules_UpdatedBy', N'D') IS NULL ALTER TABLE timetable.BellSchedules ADD CONSTRAINT DF_BellSchedules_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'timetable.DF_Periods_CreatedAt', N'D') IS NULL ALTER TABLE timetable.Periods ADD CONSTRAINT DF_Periods_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'timetable.DF_Periods_CreatedBy', N'D') IS NULL ALTER TABLE timetable.Periods ADD CONSTRAINT DF_Periods_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'timetable.DF_Periods_UpdatedAt', N'D') IS NULL ALTER TABLE timetable.Periods ADD CONSTRAINT DF_Periods_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'timetable.DF_Periods_UpdatedBy', N'D') IS NULL ALTER TABLE timetable.Periods ADD CONSTRAINT DF_Periods_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'timetable.DF_Timetables_CreatedAt', N'D') IS NULL ALTER TABLE timetable.Timetables ADD CONSTRAINT DF_Timetables_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'timetable.DF_Timetables_CreatedBy', N'D') IS NULL ALTER TABLE timetable.Timetables ADD CONSTRAINT DF_Timetables_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'timetable.DF_Timetables_UpdatedAt', N'D') IS NULL ALTER TABLE timetable.Timetables ADD CONSTRAINT DF_Timetables_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'timetable.DF_Timetables_UpdatedBy', N'D') IS NULL ALTER TABLE timetable.Timetables ADD CONSTRAINT DF_Timetables_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'timetable.DF_TimetableEntries_CreatedAt', N'D') IS NULL ALTER TABLE timetable.TimetableEntries ADD CONSTRAINT DF_TimetableEntries_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'timetable.DF_TimetableEntries_CreatedBy', N'D') IS NULL ALTER TABLE timetable.TimetableEntries ADD CONSTRAINT DF_TimetableEntries_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'timetable.DF_TimetableEntries_UpdatedAt', N'D') IS NULL ALTER TABLE timetable.TimetableEntries ADD CONSTRAINT DF_TimetableEntries_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'timetable.DF_TimetableEntries_UpdatedBy', N'D') IS NULL ALTER TABLE timetable.TimetableEntries ADD CONSTRAINT DF_TimetableEntries_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'attendance.DF_AttendanceStatuses_CreatedAt', N'D') IS NULL ALTER TABLE attendance.AttendanceStatuses ADD CONSTRAINT DF_AttendanceStatuses_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'attendance.DF_AttendanceStatuses_CreatedBy', N'D') IS NULL ALTER TABLE attendance.AttendanceStatuses ADD CONSTRAINT DF_AttendanceStatuses_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'attendance.DF_AttendanceStatuses_UpdatedAt', N'D') IS NULL ALTER TABLE attendance.AttendanceStatuses ADD CONSTRAINT DF_AttendanceStatuses_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'attendance.DF_AttendanceStatuses_UpdatedBy', N'D') IS NULL ALTER TABLE attendance.AttendanceStatuses ADD CONSTRAINT DF_AttendanceStatuses_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'attendance.DF_AttendanceSessions_CreatedAt', N'D') IS NULL ALTER TABLE attendance.AttendanceSessions ADD CONSTRAINT DF_AttendanceSessions_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'attendance.DF_AttendanceSessions_CreatedBy', N'D') IS NULL ALTER TABLE attendance.AttendanceSessions ADD CONSTRAINT DF_AttendanceSessions_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'attendance.DF_AttendanceSessions_UpdatedAt', N'D') IS NULL ALTER TABLE attendance.AttendanceSessions ADD CONSTRAINT DF_AttendanceSessions_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'attendance.DF_AttendanceSessions_UpdatedBy', N'D') IS NULL ALTER TABLE attendance.AttendanceSessions ADD CONSTRAINT DF_AttendanceSessions_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'attendance.DF_AttendanceRecords_CreatedAt', N'D') IS NULL ALTER TABLE attendance.AttendanceRecords ADD CONSTRAINT DF_AttendanceRecords_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'attendance.DF_AttendanceRecords_CreatedBy', N'D') IS NULL ALTER TABLE attendance.AttendanceRecords ADD CONSTRAINT DF_AttendanceRecords_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'attendance.DF_AttendanceRecords_UpdatedAt', N'D') IS NULL ALTER TABLE attendance.AttendanceRecords ADD CONSTRAINT DF_AttendanceRecords_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'attendance.DF_AttendanceRecords_UpdatedBy', N'D') IS NULL ALTER TABLE attendance.AttendanceRecords ADD CONSTRAINT DF_AttendanceRecords_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'assessment.DF_GradingScales_CreatedAt', N'D') IS NULL ALTER TABLE assessment.GradingScales ADD CONSTRAINT DF_GradingScales_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'assessment.DF_GradingScales_CreatedBy', N'D') IS NULL ALTER TABLE assessment.GradingScales ADD CONSTRAINT DF_GradingScales_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'assessment.DF_GradingScales_UpdatedAt', N'D') IS NULL ALTER TABLE assessment.GradingScales ADD CONSTRAINT DF_GradingScales_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'assessment.DF_GradingScales_UpdatedBy', N'D') IS NULL ALTER TABLE assessment.GradingScales ADD CONSTRAINT DF_GradingScales_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'assessment.DF_GradingScaleBands_CreatedAt', N'D') IS NULL ALTER TABLE assessment.GradingScaleBands ADD CONSTRAINT DF_GradingScaleBands_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'assessment.DF_GradingScaleBands_CreatedBy', N'D') IS NULL ALTER TABLE assessment.GradingScaleBands ADD CONSTRAINT DF_GradingScaleBands_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'assessment.DF_GradingScaleBands_UpdatedAt', N'D') IS NULL ALTER TABLE assessment.GradingScaleBands ADD CONSTRAINT DF_GradingScaleBands_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'assessment.DF_GradingScaleBands_UpdatedBy', N'D') IS NULL ALTER TABLE assessment.GradingScaleBands ADD CONSTRAINT DF_GradingScaleBands_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'assessment.DF_AssessmentTypes_CreatedAt', N'D') IS NULL ALTER TABLE assessment.AssessmentTypes ADD CONSTRAINT DF_AssessmentTypes_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'assessment.DF_AssessmentTypes_CreatedBy', N'D') IS NULL ALTER TABLE assessment.AssessmentTypes ADD CONSTRAINT DF_AssessmentTypes_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'assessment.DF_AssessmentTypes_UpdatedAt', N'D') IS NULL ALTER TABLE assessment.AssessmentTypes ADD CONSTRAINT DF_AssessmentTypes_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'assessment.DF_AssessmentTypes_UpdatedBy', N'D') IS NULL ALTER TABLE assessment.AssessmentTypes ADD CONSTRAINT DF_AssessmentTypes_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'assessment.DF_AssessmentWeights_CreatedAt', N'D') IS NULL ALTER TABLE assessment.AssessmentWeights ADD CONSTRAINT DF_AssessmentWeights_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'assessment.DF_AssessmentWeights_CreatedBy', N'D') IS NULL ALTER TABLE assessment.AssessmentWeights ADD CONSTRAINT DF_AssessmentWeights_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'assessment.DF_AssessmentWeights_UpdatedAt', N'D') IS NULL ALTER TABLE assessment.AssessmentWeights ADD CONSTRAINT DF_AssessmentWeights_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'assessment.DF_AssessmentWeights_UpdatedBy', N'D') IS NULL ALTER TABLE assessment.AssessmentWeights ADD CONSTRAINT DF_AssessmentWeights_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'assessment.DF_Assessments_CreatedAt', N'D') IS NULL ALTER TABLE assessment.Assessments ADD CONSTRAINT DF_Assessments_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'assessment.DF_Assessments_CreatedBy', N'D') IS NULL ALTER TABLE assessment.Assessments ADD CONSTRAINT DF_Assessments_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'assessment.DF_Assessments_UpdatedAt', N'D') IS NULL ALTER TABLE assessment.Assessments ADD CONSTRAINT DF_Assessments_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'assessment.DF_Assessments_UpdatedBy', N'D') IS NULL ALTER TABLE assessment.Assessments ADD CONSTRAINT DF_Assessments_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'assessment.DF_AssessmentResults_CreatedAt', N'D') IS NULL ALTER TABLE assessment.AssessmentResults ADD CONSTRAINT DF_AssessmentResults_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'assessment.DF_AssessmentResults_CreatedBy', N'D') IS NULL ALTER TABLE assessment.AssessmentResults ADD CONSTRAINT DF_AssessmentResults_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'assessment.DF_AssessmentResults_UpdatedAt', N'D') IS NULL ALTER TABLE assessment.AssessmentResults ADD CONSTRAINT DF_AssessmentResults_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'assessment.DF_AssessmentResults_UpdatedBy', N'D') IS NULL ALTER TABLE assessment.AssessmentResults ADD CONSTRAINT DF_AssessmentResults_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'assessment.DF_ReportCards_CreatedAt', N'D') IS NULL ALTER TABLE assessment.ReportCards ADD CONSTRAINT DF_ReportCards_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'assessment.DF_ReportCards_CreatedBy', N'D') IS NULL ALTER TABLE assessment.ReportCards ADD CONSTRAINT DF_ReportCards_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'assessment.DF_ReportCards_UpdatedAt', N'D') IS NULL ALTER TABLE assessment.ReportCards ADD CONSTRAINT DF_ReportCards_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'assessment.DF_ReportCards_UpdatedBy', N'D') IS NULL ALTER TABLE assessment.ReportCards ADD CONSTRAINT DF_ReportCards_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'assessment.DF_ReportCardLines_CreatedAt', N'D') IS NULL ALTER TABLE assessment.ReportCardLines ADD CONSTRAINT DF_ReportCardLines_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'assessment.DF_ReportCardLines_CreatedBy', N'D') IS NULL ALTER TABLE assessment.ReportCardLines ADD CONSTRAINT DF_ReportCardLines_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'assessment.DF_ReportCardLines_UpdatedAt', N'D') IS NULL ALTER TABLE assessment.ReportCardLines ADD CONSTRAINT DF_ReportCardLines_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'assessment.DF_ReportCardLines_UpdatedBy', N'D') IS NULL ALTER TABLE assessment.ReportCardLines ADD CONSTRAINT DF_ReportCardLines_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'finance.DF_Currencies_CreatedAt', N'D') IS NULL ALTER TABLE finance.Currencies ADD CONSTRAINT DF_Currencies_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'finance.DF_Currencies_CreatedBy', N'D') IS NULL ALTER TABLE finance.Currencies ADD CONSTRAINT DF_Currencies_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'finance.DF_Currencies_UpdatedAt', N'D') IS NULL ALTER TABLE finance.Currencies ADD CONSTRAINT DF_Currencies_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'finance.DF_Currencies_UpdatedBy', N'D') IS NULL ALTER TABLE finance.Currencies ADD CONSTRAINT DF_Currencies_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'finance.DF_FeeTypes_CreatedAt', N'D') IS NULL ALTER TABLE finance.FeeTypes ADD CONSTRAINT DF_FeeTypes_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'finance.DF_FeeTypes_CreatedBy', N'D') IS NULL ALTER TABLE finance.FeeTypes ADD CONSTRAINT DF_FeeTypes_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'finance.DF_FeeTypes_UpdatedAt', N'D') IS NULL ALTER TABLE finance.FeeTypes ADD CONSTRAINT DF_FeeTypes_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'finance.DF_FeeTypes_UpdatedBy', N'D') IS NULL ALTER TABLE finance.FeeTypes ADD CONSTRAINT DF_FeeTypes_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'finance.DF_FeeStructures_CreatedAt', N'D') IS NULL ALTER TABLE finance.FeeStructures ADD CONSTRAINT DF_FeeStructures_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'finance.DF_FeeStructures_CreatedBy', N'D') IS NULL ALTER TABLE finance.FeeStructures ADD CONSTRAINT DF_FeeStructures_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'finance.DF_FeeStructures_UpdatedAt', N'D') IS NULL ALTER TABLE finance.FeeStructures ADD CONSTRAINT DF_FeeStructures_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'finance.DF_FeeStructures_UpdatedBy', N'D') IS NULL ALTER TABLE finance.FeeStructures ADD CONSTRAINT DF_FeeStructures_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'finance.DF_FeeStructureItems_CreatedAt', N'D') IS NULL ALTER TABLE finance.FeeStructureItems ADD CONSTRAINT DF_FeeStructureItems_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'finance.DF_FeeStructureItems_CreatedBy', N'D') IS NULL ALTER TABLE finance.FeeStructureItems ADD CONSTRAINT DF_FeeStructureItems_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'finance.DF_FeeStructureItems_UpdatedAt', N'D') IS NULL ALTER TABLE finance.FeeStructureItems ADD CONSTRAINT DF_FeeStructureItems_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'finance.DF_FeeStructureItems_UpdatedBy', N'D') IS NULL ALTER TABLE finance.FeeStructureItems ADD CONSTRAINT DF_FeeStructureItems_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'finance.DF_FeeInstallments_CreatedAt', N'D') IS NULL ALTER TABLE finance.FeeInstallments ADD CONSTRAINT DF_FeeInstallments_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'finance.DF_FeeInstallments_CreatedBy', N'D') IS NULL ALTER TABLE finance.FeeInstallments ADD CONSTRAINT DF_FeeInstallments_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'finance.DF_FeeInstallments_UpdatedAt', N'D') IS NULL ALTER TABLE finance.FeeInstallments ADD CONSTRAINT DF_FeeInstallments_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'finance.DF_FeeInstallments_UpdatedBy', N'D') IS NULL ALTER TABLE finance.FeeInstallments ADD CONSTRAINT DF_FeeInstallments_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'finance.DF_DiscountTypes_CreatedAt', N'D') IS NULL ALTER TABLE finance.DiscountTypes ADD CONSTRAINT DF_DiscountTypes_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'finance.DF_DiscountTypes_CreatedBy', N'D') IS NULL ALTER TABLE finance.DiscountTypes ADD CONSTRAINT DF_DiscountTypes_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'finance.DF_DiscountTypes_UpdatedAt', N'D') IS NULL ALTER TABLE finance.DiscountTypes ADD CONSTRAINT DF_DiscountTypes_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'finance.DF_DiscountTypes_UpdatedBy', N'D') IS NULL ALTER TABLE finance.DiscountTypes ADD CONSTRAINT DF_DiscountTypes_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'finance.DF_StudentDiscounts_CreatedAt', N'D') IS NULL ALTER TABLE finance.StudentDiscounts ADD CONSTRAINT DF_StudentDiscounts_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'finance.DF_StudentDiscounts_CreatedBy', N'D') IS NULL ALTER TABLE finance.StudentDiscounts ADD CONSTRAINT DF_StudentDiscounts_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'finance.DF_StudentDiscounts_UpdatedAt', N'D') IS NULL ALTER TABLE finance.StudentDiscounts ADD CONSTRAINT DF_StudentDiscounts_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'finance.DF_StudentDiscounts_UpdatedBy', N'D') IS NULL ALTER TABLE finance.StudentDiscounts ADD CONSTRAINT DF_StudentDiscounts_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'finance.DF_Sponsors_CreatedAt', N'D') IS NULL ALTER TABLE finance.Sponsors ADD CONSTRAINT DF_Sponsors_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'finance.DF_Sponsors_CreatedBy', N'D') IS NULL ALTER TABLE finance.Sponsors ADD CONSTRAINT DF_Sponsors_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'finance.DF_Sponsors_UpdatedAt', N'D') IS NULL ALTER TABLE finance.Sponsors ADD CONSTRAINT DF_Sponsors_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'finance.DF_Sponsors_UpdatedBy', N'D') IS NULL ALTER TABLE finance.Sponsors ADD CONSTRAINT DF_Sponsors_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'finance.DF_Payers_CreatedAt', N'D') IS NULL ALTER TABLE finance.Payers ADD CONSTRAINT DF_Payers_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'finance.DF_Payers_CreatedBy', N'D') IS NULL ALTER TABLE finance.Payers ADD CONSTRAINT DF_Payers_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'finance.DF_Payers_UpdatedAt', N'D') IS NULL ALTER TABLE finance.Payers ADD CONSTRAINT DF_Payers_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'finance.DF_Payers_UpdatedBy', N'D') IS NULL ALTER TABLE finance.Payers ADD CONSTRAINT DF_Payers_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'finance.DF_StudentPayers_CreatedAt', N'D') IS NULL ALTER TABLE finance.StudentPayers ADD CONSTRAINT DF_StudentPayers_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'finance.DF_StudentPayers_CreatedBy', N'D') IS NULL ALTER TABLE finance.StudentPayers ADD CONSTRAINT DF_StudentPayers_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'finance.DF_StudentPayers_UpdatedAt', N'D') IS NULL ALTER TABLE finance.StudentPayers ADD CONSTRAINT DF_StudentPayers_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'finance.DF_StudentPayers_UpdatedBy', N'D') IS NULL ALTER TABLE finance.StudentPayers ADD CONSTRAINT DF_StudentPayers_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'finance.DF_Invoices_CreatedAt', N'D') IS NULL ALTER TABLE finance.Invoices ADD CONSTRAINT DF_Invoices_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'finance.DF_Invoices_CreatedBy', N'D') IS NULL ALTER TABLE finance.Invoices ADD CONSTRAINT DF_Invoices_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'finance.DF_Invoices_UpdatedAt', N'D') IS NULL ALTER TABLE finance.Invoices ADD CONSTRAINT DF_Invoices_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'finance.DF_Invoices_UpdatedBy', N'D') IS NULL ALTER TABLE finance.Invoices ADD CONSTRAINT DF_Invoices_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'finance.DF_InvoiceLines_CreatedAt', N'D') IS NULL ALTER TABLE finance.InvoiceLines ADD CONSTRAINT DF_InvoiceLines_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'finance.DF_InvoiceLines_CreatedBy', N'D') IS NULL ALTER TABLE finance.InvoiceLines ADD CONSTRAINT DF_InvoiceLines_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'finance.DF_InvoiceLines_UpdatedAt', N'D') IS NULL ALTER TABLE finance.InvoiceLines ADD CONSTRAINT DF_InvoiceLines_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'finance.DF_InvoiceLines_UpdatedBy', N'D') IS NULL ALTER TABLE finance.InvoiceLines ADD CONSTRAINT DF_InvoiceLines_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'finance.DF_CreditNotes_CreatedAt', N'D') IS NULL ALTER TABLE finance.CreditNotes ADD CONSTRAINT DF_CreditNotes_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'finance.DF_CreditNotes_CreatedBy', N'D') IS NULL ALTER TABLE finance.CreditNotes ADD CONSTRAINT DF_CreditNotes_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'finance.DF_CreditNotes_UpdatedAt', N'D') IS NULL ALTER TABLE finance.CreditNotes ADD CONSTRAINT DF_CreditNotes_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'finance.DF_CreditNotes_UpdatedBy', N'D') IS NULL ALTER TABLE finance.CreditNotes ADD CONSTRAINT DF_CreditNotes_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'finance.DF_PaymentMethods_CreatedAt', N'D') IS NULL ALTER TABLE finance.PaymentMethods ADD CONSTRAINT DF_PaymentMethods_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'finance.DF_PaymentMethods_CreatedBy', N'D') IS NULL ALTER TABLE finance.PaymentMethods ADD CONSTRAINT DF_PaymentMethods_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'finance.DF_PaymentMethods_UpdatedAt', N'D') IS NULL ALTER TABLE finance.PaymentMethods ADD CONSTRAINT DF_PaymentMethods_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'finance.DF_PaymentMethods_UpdatedBy', N'D') IS NULL ALTER TABLE finance.PaymentMethods ADD CONSTRAINT DF_PaymentMethods_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'finance.DF_Payments_CreatedAt', N'D') IS NULL ALTER TABLE finance.Payments ADD CONSTRAINT DF_Payments_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'finance.DF_Payments_CreatedBy', N'D') IS NULL ALTER TABLE finance.Payments ADD CONSTRAINT DF_Payments_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'finance.DF_Payments_UpdatedAt', N'D') IS NULL ALTER TABLE finance.Payments ADD CONSTRAINT DF_Payments_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'finance.DF_Payments_UpdatedBy', N'D') IS NULL ALTER TABLE finance.Payments ADD CONSTRAINT DF_Payments_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
IF OBJECT_ID(N'finance.DF_PaymentAllocations_CreatedAt', N'D') IS NULL ALTER TABLE finance.PaymentAllocations ADD CONSTRAINT DF_PaymentAllocations_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;
IF OBJECT_ID(N'finance.DF_PaymentAllocations_CreatedBy', N'D') IS NULL ALTER TABLE finance.PaymentAllocations ADD CONSTRAINT DF_PaymentAllocations_CreatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR CreatedBy;
IF OBJECT_ID(N'finance.DF_PaymentAllocations_UpdatedAt', N'D') IS NULL ALTER TABLE finance.PaymentAllocations ADD CONSTRAINT DF_PaymentAllocations_UpdatedAt DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;
IF OBJECT_ID(N'finance.DF_PaymentAllocations_UpdatedBy', N'D') IS NULL ALTER TABLE finance.PaymentAllocations ADD CONSTRAINT DF_PaymentAllocations_UpdatedBy DEFAULT (TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))) FOR UpdatedBy;
GO

/* =============================================================================
   5. SYSTEM-VERSIONED TEMPORAL TABLES
      History tables live in the audit schema. SQL Server creates them on first
      run; 06_indexes.sql renames their auto-created clustered index.
   ============================================================================= */
IF OBJECTPROPERTY(OBJECT_ID(N'people.Persons'), N'TableTemporalType') = 0
    ALTER TABLE people.Persons SET (SYSTEM_VERSIONING = ON (HISTORY_TABLE = audit.PersonsHistory, DATA_CONSISTENCY_CHECK = ON));
IF OBJECTPROPERTY(OBJECT_ID(N'enrollment.Enrollments'), N'TableTemporalType') = 0
    ALTER TABLE enrollment.Enrollments SET (SYSTEM_VERSIONING = ON (HISTORY_TABLE = audit.EnrollmentsHistory, DATA_CONSISTENCY_CHECK = ON));
IF OBJECTPROPERTY(OBJECT_ID(N'assessment.AssessmentResults'), N'TableTemporalType') = 0
    ALTER TABLE assessment.AssessmentResults SET (SYSTEM_VERSIONING = ON (HISTORY_TABLE = audit.AssessmentResultsHistory, DATA_CONSISTENCY_CHECK = ON));
IF OBJECTPROPERTY(OBJECT_ID(N'finance.FeeStructureItems'), N'TableTemporalType') = 0
    ALTER TABLE finance.FeeStructureItems SET (SYSTEM_VERSIONING = ON (HISTORY_TABLE = audit.FeeStructureItemsHistory, DATA_CONSISTENCY_CHECK = ON));
GO

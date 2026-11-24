/* =============================================================================
   11_sample_data.sql
   Purpose     : Realistic bilingual (Arabic + English) sample data across two
                 academic years: 2025-2026 (closed) and 2026-2027 (current).
                 Data is loaded THROUGH the business procedures wherever one
                 exists, so running this script also exercises 09/10.
                 All names, organisations and identifiers are fictional.
   Dependencies: 10_functions.sql (and all earlier scripts)
   Run order   : 11 of 12. Omit this script for a production deployment.
   Idempotent  : Yes. If the sample school (SchoolCode 'ANIS') already exists
                 the whole script is skipped with SET NOEXEC ON.
   Note        : Uses session-scoped #temp tables to pass keys between batches;
                 run the script in a single session (SSMS window / sqlcmd).
   ============================================================================= */
USE [$(DatabaseName)];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO
IF EXISTS (SELECT 1 FROM organization.Schools WHERE SchoolCode = N'ANIS')
BEGIN
    PRINT N'Sample data already present (school ANIS) - skipping 11_sample_data.sql.';
    SET NOEXEC ON;
END;
GO

/* =============================================================================
   A. Organisation, academic calendar, curriculum, user accounts
   ============================================================================= */
DECLARE @JO INT = (SELECT CountryId FROM organization.Countries WHERE IsoAlpha2 = N'JO');
DECLARE @JOD INT = (SELECT CurrencyId FROM finance.Currencies WHERE CurrencyCode = N'JOD');

INSERT INTO organization.Schools (SchoolCode, NameEn, NameAr, LicenseNumber, CountryId, DefaultCurrencyId)
VALUES (N'ANIS', N'Al-Noor International School', N'مدرسة النور الدولية', N'MOE-PRV-2009-1187', @JO, @JOD);
DECLARE @School INT = SCOPE_IDENTITY();

INSERT INTO organization.Branches (SchoolId, BranchCode, NameEn, NameAr, City, AddressLine, Phone, Email, WorkingDaysMask)
VALUES (@School, N'AMM', N'Amman - Khalda Campus', N'عمّان - حرم خلدا', N'Amman', N'Wasfi Al-Tal St., Khalda', N'+962-6-5550100', N'amman@alnoor.example.jo', 79),
       (@School, N'IRB', N'Irbid Campus',          N'حرم إربد',         N'Irbid', N'University St.',          N'+962-2-7250100', N'irbid@alnoor.example.jo', 79);

INSERT INTO organization.Buildings (BranchId, BuildingCode, NameEn, NameAr)
SELECT BranchId, N'MAIN', N'Main Building', N'المبنى الرئيسي' FROM organization.Branches WHERE SchoolId = @School;

INSERT INTO organization.Rooms (BuildingId, RoomTypeId, RoomCode, NameEn, NameAr, FloorNumber, SeatCapacity)
SELECT bd.BuildingId, rt.RoomTypeId, v.RoomCode, v.NameEn, v.NameAr, v.FloorNumber, v.Seats
FROM (VALUES
    (N'AMM', N'CLASS', N'R101', N'Room 101', N'غرفة 101', 1, 30),
    (N'AMM', N'CLASS', N'R102', N'Room 102', N'غرفة 102', 1, 30),
    (N'AMM', N'CLASS', N'R103', N'Room 103', N'غرفة 103', 1, 32),
    (N'AMM', N'CLASS', N'R104', N'Room 104', N'غرفة 104', 1, 30),
    (N'AMM', N'CLASS', N'R105', N'Room 105', N'غرفة 105', 1, 30),
    (N'AMM', N'LAB',   N'LAB1', N'Science Lab 1', N'مختبر العلوم 1', 2, 24),
    (N'IRB', N'CLASS', N'R201', N'Room 201', N'غرفة 201', 2, 30),
    (N'IRB', N'CLASS', N'R202', N'Room 202', N'غرفة 202', 2, 30)
) AS v (BranchCode, RoomType, RoomCode, NameEn, NameAr, FloorNumber, Seats)
JOIN organization.Branches  AS b  ON b.BranchCode = v.BranchCode AND b.SchoolId = @School
JOIN organization.Buildings AS bd ON bd.BranchId = b.BranchId AND bd.BuildingCode = N'MAIN'
JOIN organization.RoomTypes AS rt ON rt.Code = v.RoomType;

INSERT INTO organization.Departments (SchoolId, DepartmentCode, NameEn, NameAr, DepartmentType)
VALUES (@School, N'LANG',  N'Languages',            N'قسم اللغات',            N'Academic'),
       (@School, N'MATH',  N'Mathematics',          N'قسم الرياضيات',         N'Academic'),
       (@School, N'SCI',   N'Sciences',             N'قسم العلوم',            N'Academic'),
       (@School, N'ADMIN', N'Administration',       N'الشؤون الإدارية',       N'Administrative'),
       (@School, N'FIN',   N'Finance',              N'الشؤون المالية',        N'Administrative');

INSERT INTO academic.AcademicYears (SchoolId, YearCode, NameEn, NameAr, StartDate, EndDate, YearStatus)
VALUES (@School, N'2025-2026', N'Academic Year 2025/2026', N'العام الدراسي 2025/2026', '20250901', '20260630', N'Active'),
       (@School, N'2026-2027', N'Academic Year 2026/2027', N'العام الدراسي 2026/2027', '20260830', '20270630', N'Planned');

INSERT INTO academic.Terms (AcademicYearId, TermNumber, NameEn, NameAr, StartDate, EndDate)
SELECT ay.AcademicYearId, v.TermNumber, v.NameEn, v.NameAr, v.StartDate, v.EndDate
FROM (VALUES
    (N'2025-2026', 1, N'First Semester',  N'الفصل الدراسي الأول',  CONVERT(DATE, '20250901'), CONVERT(DATE, '20260115')),
    (N'2025-2026', 2, N'Second Semester', N'الفصل الدراسي الثاني', CONVERT(DATE, '20260201'), CONVERT(DATE, '20260630')),
    (N'2026-2027', 1, N'First Semester',  N'الفصل الدراسي الأول',  CONVERT(DATE, '20260830'), CONVERT(DATE, '20270114')),
    (N'2026-2027', 2, N'Second Semester', N'الفصل الدراسي الثاني', CONVERT(DATE, '20270201'), CONVERT(DATE, '20270630'))
) AS v (YearCode, TermNumber, NameEn, NameAr, StartDate, EndDate)
JOIN academic.AcademicYears AS ay ON ay.YearCode = v.YearCode AND ay.SchoolId = @School;

INSERT INTO academic.Holidays (AcademicYearId, BranchId, NameEn, NameAr, StartDate, EndDate)
SELECT ay.AcademicYearId, NULL, v.NameEn, v.NameAr, v.StartDate, v.EndDate
FROM (VALUES
    (N'2025-2026', N'Mid-year Break',     N'عطلة منتصف العام',  CONVERT(DATE, '20260116'), CONVERT(DATE, '20260131')),
    (N'2025-2026', N'Eid al-Fitr',        N'عيد الفطر',          CONVERT(DATE, '20260319'), CONVERT(DATE, '20260323')),
    (N'2025-2026', N'Independence Day',   N'عيد الاستقلال',      CONVERT(DATE, '20260525'), CONVERT(DATE, '20260525')),
    (N'2025-2026', N'Eid al-Adha',        N'عيد الأضحى',         CONVERT(DATE, '20260526'), CONVERT(DATE, '20260530')),
    (N'2026-2027', N'Christmas',          N'عيد الميلاد المجيد', CONVERT(DATE, '20261225'), CONVERT(DATE, '20261225')),
    (N'2026-2027', N'Mid-year Break',     N'عطلة منتصف العام',  CONVERT(DATE, '20270115'), CONVERT(DATE, '20270131'))
) AS v (YearCode, NameEn, NameAr, StartDate, EndDate)
JOIN academic.AcademicYears AS ay ON ay.YearCode = v.YearCode AND ay.SchoolId = @School;

INSERT INTO academic.Subjects (SubjectCode, NameEn, NameAr, DepartmentId)
SELECT v.Code, v.NameEn, v.NameAr, d.DepartmentId
FROM (VALUES
    (N'ARB',  N'Arabic Language',  N'اللغة العربية',     N'LANG'),
    (N'ENG',  N'English Language', N'اللغة الإنجليزية', N'LANG'),
    (N'MATH', N'Mathematics',      N'الرياضيات',         N'MATH'),
    (N'SCI',  N'Science',          N'العلوم',            N'SCI'),
    (N'PHY',  N'Physics',          N'الفيزياء',          N'SCI')
) AS v (Code, NameEn, NameAr, Dept)
JOIN organization.Departments AS d ON d.DepartmentCode = v.Dept AND d.SchoolId = @School;

-- Curriculum per year / grade / program.
INSERT INTO academic.CurriculumSubjects (AcademicYearId, GradeLevelId, ProgramId, SubjectId, GradingScaleId, WeeklyPeriods, IsElective, ReportOrder)
SELECT ay.AcademicYearId, gl.GradeLevelId, pr.ProgramId, s.SubjectId, gs.GradingScaleId, v.Periods, 0, v.ReportOrder
FROM (VALUES
    (N'2025-2026', N'G01', N'NAT',     N'ARB', 7, 1), (N'2025-2026', N'G01', N'NAT',     N'ENG', 5, 2), (N'2025-2026', N'G01', N'NAT',     N'MATH', 5, 3),
    (N'2025-2026', N'G05', N'NAT',     N'ARB', 6, 1), (N'2025-2026', N'G05', N'NAT',     N'ENG', 5, 2), (N'2025-2026', N'G05', N'NAT',     N'MATH', 5, 3), (N'2025-2026', N'G05', N'NAT', N'SCI', 4, 4),
    (N'2025-2026', N'G09', N'NAT',     N'ARB', 5, 1), (N'2025-2026', N'G09', N'NAT',     N'ENG', 5, 2), (N'2025-2026', N'G09', N'NAT',     N'MATH', 5, 3), (N'2025-2026', N'G09', N'NAT', N'SCI', 5, 4),
    (N'2025-2026', N'G12', N'NAT-SCI', N'ARB', 4, 1), (N'2025-2026', N'G12', N'NAT-SCI', N'ENG', 4, 2), (N'2025-2026', N'G12', N'NAT-SCI', N'MATH', 6, 3), (N'2025-2026', N'G12', N'NAT-SCI', N'PHY', 5, 4),
    (N'2026-2027', N'G01', N'NAT',     N'ARB', 7, 1), (N'2026-2027', N'G01', N'NAT',     N'ENG', 5, 2), (N'2026-2027', N'G01', N'NAT',     N'MATH', 5, 3),
    (N'2026-2027', N'G02', N'NAT',     N'ARB', 7, 1), (N'2026-2027', N'G02', N'NAT',     N'ENG', 5, 2), (N'2026-2027', N'G02', N'NAT',     N'MATH', 5, 3),
    (N'2026-2027', N'G05', N'NAT',     N'ARB', 6, 1), (N'2026-2027', N'G05', N'NAT',     N'ENG', 5, 2), (N'2026-2027', N'G05', N'NAT',     N'MATH', 5, 3), (N'2026-2027', N'G05', N'NAT', N'SCI', 4, 4),
    (N'2026-2027', N'G06', N'NAT',     N'ARB', 6, 1), (N'2026-2027', N'G06', N'NAT',     N'ENG', 5, 2), (N'2026-2027', N'G06', N'NAT',     N'MATH', 5, 3), (N'2026-2027', N'G06', N'NAT', N'SCI', 4, 4),
    (N'2026-2027', N'G10', N'NAT',     N'ARB', 5, 1), (N'2026-2027', N'G10', N'NAT',     N'ENG', 5, 2), (N'2026-2027', N'G10', N'NAT',     N'MATH', 5, 3), (N'2026-2027', N'G10', N'NAT', N'SCI', 5, 4)
) AS v (YearCode, GradeCode, ProgramCode, SubjectCode, Periods, ReportOrder)
JOIN academic.AcademicYears  AS ay ON ay.YearCode = v.YearCode AND ay.SchoolId = @School
JOIN academic.GradeLevels    AS gl ON gl.Code = v.GradeCode
JOIN academic.Programs       AS pr ON pr.Code = v.ProgramCode
JOIN academic.Subjects       AS s  ON s.SubjectCode = v.SubjectCode
JOIN assessment.GradingScales AS gs ON gs.Code = N'STD100';

-- Assessment weights: Quiz 20%, Midterm 30%, Final 50% for every subject and term.
INSERT INTO assessment.AssessmentWeights (CurriculumSubjectId, TermId, AssessmentTypeId, WeightPercent)
SELECT cs.CurriculumSubjectId, t.TermId, at.AssessmentTypeId, w.Weight
FROM   academic.CurriculumSubjects AS cs
JOIN   academic.Terms AS t ON t.AcademicYearId = cs.AcademicYearId
CROSS JOIN (VALUES (N'QUIZ', 20.0), (N'MIDTERM', 30.0), (N'FINAL', 50.0)) AS w (TypeCode, Weight)
JOIN   assessment.AssessmentTypes AS at ON at.Code = w.TypeCode;
GO

/* =============================================================================
   B. People: supertype rows, overlapping subtypes, contacts, IDs, accounts
   ============================================================================= */
IF OBJECT_ID(N'tempdb..#P') IS NOT NULL DROP TABLE #P;
CREATE TABLE #P (Code NVARCHAR(10) COLLATE DATABASE_DEFAULT NOT NULL PRIMARY KEY, PersonId INT NOT NULL);

DECLARE @JO INT = (SELECT CountryId FROM organization.Countries WHERE IsoAlpha2 = N'JO');
DECLARE @PS INT = (SELECT CountryId FROM organization.Countries WHERE IsoAlpha2 = N'PS');

MERGE people.Persons AS t
USING (VALUES
    -- Code, FirstEn, FatherEn, GrandEn, FamilyEn, FirstAr, FatherAr, GrandAr, FamilyAr, Gender, DOB, Nationality
    (N'T1', N'Khaled', N'Mahmoud', N'Saleh',   N'Al-Masri',      N'خالد',  N'محمود',  N'صالح',  N'المصري',    N'M', CONVERT(DATE, '19830410'), N'JO'),
    (N'T2', N'Rania',  N'Yousef',  N'Elias',   N'Haddad',        N'رانيا', N'يوسف',   N'إلياس', N'حداد',      N'F', CONVERT(DATE, '19880821'), N'JO'),
    (N'T3', N'Omar',   N'Saleh',   N'Ahmad',   N'Al-Khatib',     N'عمر',   N'صالح',   N'أحمد',  N'الخطيب',    N'M', CONVERT(DATE, '19850130'), N'JO'),
    (N'T4', N'Lina',   N'Fawzi',   N'Hasan',   N'Al-Zoubi',      N'لينا',  N'فوزي',   N'حسن',   N'الزعبي',    N'F', CONVERT(DATE, '19901105'), N'JO'),
    (N'T5', N'Ahmad',  N'Ibrahim', N'Khalil',  N'Obeidat',       N'أحمد',  N'إبراهيم', N'خليل', N'عبيدات',    N'M', CONVERT(DATE, '19790617'), N'JO'),
    (N'T6', N'Dana',   N'Waleed',  N'Fayez',   N'Bani Hani',     N'دانا',  N'وليد',   N'فايز',  N'بني هاني',  N'F', CONVERT(DATE, '19920214'), N'JO'),
    (N'E1', N'Samer',  N'Nabil',   N'Awad',    N'Al-Tal',        N'سامر',  N'نبيل',   N'عوض',   N'التل',      N'M', CONVERT(DATE, '19870909'), N'JO'),
    (N'E2', N'Huda',   N'Kamal',   N'Ali',     N'Shamaileh',     N'هدى',   N'كمال',   N'علي',   N'الشمايلة',  N'F', CONVERT(DATE, '19841201'), N'JO'),
    (N'G1', N'Mahmoud',N'Ali',     N'Hasan',   N'Al-Ahmad',      N'محمود', N'علي',    N'حسن',   N'الأحمد',    N'M', CONVERT(DATE, '19800202'), N'JO'),
    (N'G2', N'Fatima', N'Hasan',   N'Musa',    N'Al-Omari',      N'فاطمة', N'حسن',    N'موسى',  N'العمري',    N'F', CONVERT(DATE, '19840707'), N'JO'),
    (N'G4', N'Nadia',  N'Sami',    N'Odeh',    N'Qasem',         N'نادية', N'سامي',   N'عودة',  N'قاسم',      N'F', CONVERT(DATE, '19820303'), N'PS'),
    (N'G5', N'Yazan',  N'Tariq',   N'Fahed',   N'Al-Rawashdeh',  N'يزن',   N'طارق',   N'فهد',   N'الرواشدة',  N'M', CONVERT(DATE, '19781010'), N'JO'),
    (N'G6', N'Basma',  N'Adel',    N'Nimer',   N'Al-Saleh',      N'بسمة',  N'عادل',   N'نمر',   N'الصالح',    N'F', CONVERT(DATE, '19860525'), N'JO'),
    (N'G7', N'Fadi',   N'Jamil',   N'Issa',    N'Nassar',        N'فادي',  N'جميل',   N'عيسى',  N'نصار',      N'M', CONVERT(DATE, '19810112'), N'JO'),
    (N'S1', N'Yousef', N'Mahmoud', N'Ali',     N'Al-Ahmad',      N'يوسف',  N'محمود',  N'علي',   N'الأحمد',    N'M', CONVERT(DATE, '20150312'), N'JO'),
    (N'S2', N'Sara',   N'Mahmoud', N'Ali',     N'Al-Ahmad',      N'سارة',  N'محمود',  N'علي',   N'الأحمد',    N'F', CONVERT(DATE, '20190120'), N'JO'),
    (N'S3', N'Adam',   N'Khaled',  N'Mahmoud', N'Al-Masri',      N'آدم',   N'خالد',   N'محمود', N'المصري',    N'M', CONVERT(DATE, '20150702'), N'JO'),
    (N'S4', N'Leen',   N'Ahmad',   N'Nabil',   N'Al-Bitar',      N'لين',   N'أحمد',   N'نبيل',  N'البيطار',   N'F', CONVERT(DATE, '20110518'), N'JO'),
    (N'S5', N'Zaid',   N'Yazan',   N'Tariq',   N'Al-Rawashdeh',  N'زيد',   N'يزن',    N'طارق',  N'الرواشدة',  N'M', CONVERT(DATE, '20111005'), N'JO'),
    (N'S6', N'Tala',   N'Yazan',   N'Tariq',   N'Al-Rawashdeh',  N'تالا',  N'يزن',    N'طارق',  N'الرواشدة',  N'F', CONVERT(DATE, '20190411'), N'JO'),
    (N'S7', N'Hamza',  N'Majed',   N'Fawwaz',  N'Haddadin',      N'حمزة',  N'ماجد',   N'فواز',  N'الحدادين',  N'M', CONVERT(DATE, '20150227'), N'JO'),
    (N'S8', N'Mira',   N'Bassam',  N'Ibrahim', N'Obeidat',       N'ميرا',  N'بسام',   N'إبراهيم', N'عبيدات',  N'F', CONVERT(DATE, '20070914'), N'JO'),
    (N'S10',N'Karim',  N'Fadi',    N'Jamil',   N'Nassar',        N'كريم',  N'فادي',   N'جميل',  N'نصار',      N'M', CONVERT(DATE, '20190808'), N'JO')
) AS s (Code, FirstNameEn, FatherNameEn, GrandfatherNameEn, FamilyNameEn, FirstNameAr, FatherNameAr, GrandfatherNameAr, FamilyNameAr, Gender, DateOfBirth, Nat)
ON 1 = 0
WHEN NOT MATCHED BY TARGET THEN
    INSERT (FirstNameEn, FatherNameEn, GrandfatherNameEn, FamilyNameEn, FirstNameAr, FatherNameAr, GrandfatherNameAr, FamilyNameAr,
            Gender, DateOfBirth, NationalityCountryId, PrimaryLanguage)
    VALUES (s.FirstNameEn, s.FatherNameEn, s.GrandfatherNameEn, s.FamilyNameEn, s.FirstNameAr, s.FatherNameAr, s.GrandfatherNameAr, s.FamilyNameAr,
            s.Gender, s.DateOfBirth, CASE s.Nat WHEN N'PS' THEN @PS ELSE @JO END, N'ar')
OUTPUT s.Code, inserted.PersonId INTO #P (Code, PersonId);

-- Contacts (adults only) and identity documents (fictional numbers).
INSERT INTO people.PersonContacts (PersonId, ContactType, ContactValue, IsPrimary)
SELECT p.PersonId, v.ContactType, v.ContactValue, 1
FROM (VALUES
    (N'T1', N'Mobile', N'+962791000001'), (N'T1', N'Email', N'khaled.masri@alnoor.example.jo'),
    (N'T2', N'Mobile', N'+962791000002'), (N'T2', N'Email', N'rania.haddad@alnoor.example.jo'),
    (N'T3', N'Mobile', N'+962791000003'), (N'T3', N'Email', N'omar.khatib@alnoor.example.jo'),
    (N'T4', N'Mobile', N'+962791000004'), (N'T4', N'Email', N'lina.zoubi@alnoor.example.jo'),
    (N'T5', N'Mobile', N'+962791000005'), (N'T5', N'Email', N'ahmad.obeidat@alnoor.example.jo'),
    (N'T6', N'Mobile', N'+962791000006'), (N'T6', N'Email', N'dana.banihani@alnoor.example.jo'),
    (N'E1', N'Mobile', N'+962791000007'), (N'E1', N'Email', N'samer.tal@alnoor.example.jo'),
    (N'E2', N'Mobile', N'+962791000008'), (N'E2', N'Email', N'huda.shamaileh@alnoor.example.jo'),
    (N'G1', N'Mobile', N'+962795000011'), (N'G1', N'Email', N'mahmoud.ahmad@example.jo'),
    (N'G2', N'Mobile', N'+962795000012'),
    (N'G4', N'Mobile', N'+962795000014'), (N'G4', N'Email', N'nadia.qasem@example.jo'),
    (N'G5', N'Mobile', N'+962795000015'), (N'G5', N'Email', N'yazan.rawashdeh@example.jo'),
    (N'G6', N'Mobile', N'+962795000016'),
    (N'G7', N'Mobile', N'+962795000017')
) AS v (Code, ContactType, ContactValue)
JOIN #P AS p ON p.Code = v.Code;

INSERT INTO people.PersonAddresses (PersonId, AddressType, CountryId, City, Area, Street, BuildingNumber, IsPrimary)
SELECT p.PersonId, N'Home', @JO, v.City, v.Area, v.Street, v.Bldg, 1
FROM (VALUES
    (N'G1', N'Amman', N'Khalda',     N'Abdullah Ghosheh St.', N'14'),
    (N'G4', N'Amman', N'Tla Al-Ali', N'Al-Madina Al-Munawwara St.', N'203'),
    (N'G5', N'Amman', N'Dabouq',     N'King Hussein Park Rd.', N'7'),
    (N'G6', N'Amman', N'Sweileh',    N'Al-Jaish St.', N'51'),
    (N'G7', N'Amman', N'Jubeiha',    N'Yajouz St.', N'9'),
    (N'T5', N'Irbid', N'Al-Hay Al-Janoubi', N'Palestine St.', N'22')
) AS v (Code, City, Area, Street, Bldg)
JOIN #P AS p ON p.Code = v.Code;

INSERT INTO people.PersonIdentityDocuments (PersonId, IdentityDocumentTypeId, IssuingCountryId, DocumentNumber, IssueDate, ExpiryDate)
SELECT p.PersonId, dt.IdentityDocumentTypeId, CASE WHEN v.Code = N'G4' THEN (SELECT CountryId FROM organization.Countries WHERE IsoAlpha2 = N'PS') ELSE @JO END,
       v.DocNo, v.Issued, v.Expires
FROM (VALUES
    (N'G1', N'NATIONAL_NO', N'9801000001', NULL, NULL),
    (N'G5', N'NATIONAL_NO', N'9781000002', NULL, NULL),
    (N'G4', N'PASSPORT',    N'P0001234',   CONVERT(DATE, '20220110'), CONVERT(DATE, '20320109')),
    (N'S1', N'NATIONAL_NO', N'2015000101', NULL, NULL),
    (N'S8', N'NATIONAL_NO', N'2007000108', NULL, NULL)
) AS v (Code, DocType, DocNo, Issued, Expires)
JOIN #P AS p ON p.Code = v.Code
JOIN people.IdentityDocumentTypes AS dt ON dt.Code = v.DocType;

-- Employees (subtype of Persons) and Teachers (subtype of Employees).
INSERT INTO people.Employees (PersonId, EmployeeNumber, DepartmentId, PrimaryBranchId, JobTitleEn, JobTitleAr, HireDate)
SELECT p.PersonId, v.EmpNo, d.DepartmentId, b.BranchId, v.TitleEn, v.TitleAr, v.HireDate
FROM (VALUES
    (N'T1', N'EMP-0001', N'MATH',  N'AMM', N'Mathematics Teacher', N'معلم رياضيات',          CONVERT(DATE, '20120901')),
    (N'T2', N'EMP-0002', N'LANG',  N'AMM', N'English Teacher',     N'معلمة لغة إنجليزية',    CONVERT(DATE, '20150901')),
    (N'T3', N'EMP-0003', N'LANG',  N'AMM', N'Arabic Teacher',      N'معلم لغة عربية',        CONVERT(DATE, '20100901')),
    (N'T4', N'EMP-0004', N'SCI',   N'AMM', N'Science Teacher',     N'معلمة علوم',            CONVERT(DATE, '20180901')),
    (N'T5', N'EMP-0005', N'SCI',   N'IRB', N'Physics Teacher',     N'معلم فيزياء',           CONVERT(DATE, '20080901')),
    (N'T6', N'EMP-0006', N'LANG',  N'IRB', N'Languages Teacher',   N'معلمة لغات',            CONVERT(DATE, '20190901')),
    (N'E1', N'EMP-0007', N'FIN',   N'AMM', N'Accountant',          N'محاسب',                 CONVERT(DATE, '20160201')),
    (N'E2', N'EMP-0008', N'ADMIN', N'AMM', N'Registrar',           N'مسجلة',                 CONVERT(DATE, '20140801'))
) AS v (Code, EmpNo, Dept, BranchCode, TitleEn, TitleAr, HireDate)
JOIN #P AS p ON p.Code = v.Code
JOIN organization.Departments AS d ON d.DepartmentCode = v.Dept
JOIN organization.Branches    AS b ON b.BranchCode = v.BranchCode;

INSERT INTO people.Teachers (PersonId, TeachingLicenseNumber, Specialization, MaxWeeklyPeriods)
SELECT p.PersonId, v.Licence, v.Spec, 24
FROM (VALUES (N'T1', N'TL-11-0456', N'Mathematics'), (N'T2', N'TL-14-0921', N'English'), (N'T3', N'TL-09-0133', N'Arabic'),
             (N'T4', N'TL-17-1290', N'Biology'),     (N'T5', N'TL-07-0077', N'Physics'), (N'T6', N'TL-18-1502', N'English & Arabic')
) AS v (Code, Licence, Spec)
JOIN #P AS p ON p.Code = v.Code;

-- Guardians: T1 (teacher), T5 (teacher) and T3 (later) are ALSO guardians -> overlapping roles.
INSERT INTO people.Guardians (PersonId, Occupation, EmployerName, PreferredLanguage)
SELECT p.PersonId, v.Occupation, v.Employer, v.Lang
FROM (VALUES
    (N'G1', N'Civil Engineer',   N'Al-Waha Engineering Co.', N'ar'),
    (N'G2', N'Pharmacist',       NULL,                       N'ar'),
    (N'G4', N'Architect',        NULL,                       N'en'),
    (N'G5', N'Software Manager', N'Al-Waha Engineering Co.', N'en'),
    (N'G6', N'Nurse',            NULL,                       N'ar'),
    (N'G7', N'Accountant',       NULL,                       N'ar'),
    (N'T1', N'Teacher',          N'Al-Noor International School', N'ar'),
    (N'T5', N'Teacher',          N'Al-Noor International School', N'ar')
) AS v (Code, Occupation, Employer, Lang)
JOIN #P AS p ON p.Code = v.Code;

-- User accounts. Local accounts store a random placeholder hash (no real passwords).
INSERT INTO iam.UserAccounts (PersonId, UserName, Email, AuthProvider, PasswordHash, ExternalSubjectId, PreferredLanguage)
VALUES (NULL, N'admin', N'it.admin@alnoor.example.jo', N'AzureAD', NULL, N'00000000-0000-4000-8000-000000000001', N'en');

DECLARE @Admin INT = SCOPE_IDENTITY();
EXEC sys.sp_set_session_context @key = N'UserAccountId', @value = @Admin;

INSERT INTO iam.UserAccounts (PersonId, UserName, Email, AuthProvider, PasswordHash, PreferredLanguage)
SELECT p.PersonId, v.UserName, v.Email, N'Local', CRYPT_GEN_RANDOM(64), N'ar'
FROM (VALUES (N'E2', N'huda.shamaileh', N'huda.shamaileh@alnoor.example.jo'),
             (N'E1', N'samer.tal',      N'samer.tal@alnoor.example.jo'),
             (N'T1', N'khaled.masri',   N'khaled.masri@alnoor.example.jo'),
             (N'G1', N'mahmoud.ahmad',  N'mahmoud.ahmad@example.jo')
) AS v (Code, UserName, Email)
JOIN #P AS p ON p.Code = v.Code;

INSERT INTO iam.UserRoles (UserAccountId, RoleId, BranchId, ValidFrom)
SELECT ua.UserAccountId, r.RoleId, b.BranchId, '20250801'
FROM (VALUES (N'admin', N'SYS_ADMIN', NULL), (N'huda.shamaileh', N'REGISTRAR', NULL), (N'samer.tal', N'ACCOUNTANT', NULL),
             (N'khaled.masri', N'TEACHER', N'AMM'), (N'khaled.masri', N'GUARDIAN', NULL), (N'mahmoud.ahmad', N'GUARDIAN', NULL)
) AS v (UserName, RoleCode, BranchCode)
JOIN iam.UserAccounts AS ua ON ua.UserName = v.UserName
JOIN iam.Roles AS r ON r.RoleCode = v.RoleCode
LEFT JOIN organization.Branches AS b ON b.BranchCode = v.BranchCode;

INSERT INTO audit.SecurityEvents (EventType, UserAccountId, UserNameAttempted, IpAddress, Details)
SELECT N'RoleGranted', ua.UserAccountId, ua.UserName, N'10.0.0.5', N'Initial role assignment (sample data)'
FROM iam.UserAccounts AS ua;

-- Sponsor organisation and payers (EER category: Guardian OR Sponsor).
INSERT INTO finance.Sponsors (SponsorCode, NameEn, NameAr, SponsorType, ContactName, Phone, Email, TaxNumber)
VALUES (N'WAHA', N'Al-Waha Engineering Co. - Employee Education Fund', N'شركة الواحة للهندسة - صندوق تعليم الموظفين',
        N'Employer', N'HR Department', N'+962-6-5600200', N'hr@alwaha.example.jo', N'TX-100200300');

INSERT INTO finance.Payers (PayerType, GuardianId, SponsorId)
SELECT N'Guardian', g.PersonId, NULL FROM people.Guardians AS g
UNION ALL
SELECT N'Sponsor', NULL, s.SponsorId FROM finance.Sponsors AS s WHERE s.SponsorCode = N'WAHA';
GO

-- Student-guardian links are created after the students exist (section C).

/* =============================================================================
   C. Year 1 (2025-2026): sections, teaching assignments, fee structures,
      admissions and enrollments (via procedures)
   ============================================================================= */
DECLARE @AdminUser INT = (SELECT UserAccountId FROM iam.UserAccounts WHERE UserName = N'admin');
EXEC sys.sp_set_session_context @key = N'UserAccountId', @value = @AdminUser;
DECLARE @Y1 INT = (SELECT AcademicYearId FROM academic.AcademicYears WHERE YearCode = N'2025-2026');

INSERT INTO academic.Sections (AcademicYearId, BranchId, GradeLevelId, ProgramId, SectionCode, NameEn, NameAr, Capacity, HomeroomTeacherId, HomeRoomId)
SELECT @Y1, b.BranchId, gl.GradeLevelId, pr.ProgramId, N'A', v.NameEn, v.NameAr, v.Capacity, p.PersonId, r.RoomId
FROM (VALUES
    (N'AMM', N'G01', N'NAT',     N'Grade 1 - A',  N'الصف الأول - أ',       25, N'T2', N'R101'),
    (N'AMM', N'G05', N'NAT',     N'Grade 5 - A',  N'الصف الخامس - أ',      28, N'T1', N'R102'),
    (N'AMM', N'G09', N'NAT',     N'Grade 9 - A',  N'الصف التاسع - أ',      30, N'T4', N'R103'),
    (N'IRB', N'G12', N'NAT-SCI', N'Grade 12 - A', N'الصف الثاني عشر - أ',  30, N'T5', N'R201')
) AS v (BranchCode, GradeCode, ProgramCode, NameEn, NameAr, Capacity, Homeroom, RoomCode)
JOIN organization.Branches AS b  ON b.BranchCode = v.BranchCode
JOIN academic.GradeLevels  AS gl ON gl.Code = v.GradeCode
JOIN academic.Programs     AS pr ON pr.Code = v.ProgramCode
JOIN #P AS p ON p.Code = v.Homeroom
JOIN organization.Buildings AS bd ON bd.BranchId = b.BranchId
JOIN organization.Rooms     AS r  ON r.BuildingId = bd.BuildingId AND r.RoomCode = v.RoomCode;

-- Teaching assignments (whole-year: TermId NULL).
INSERT INTO academic.TeachingAssignments (SectionId, CurriculumSubjectId, TeacherId, TermId)
SELECT sec.SectionId, cs.CurriculumSubjectId, p.PersonId, NULL
FROM   academic.Sections AS sec
JOIN   organization.Branches AS b ON b.BranchId = sec.BranchId
JOIN   academic.CurriculumSubjects AS cs ON cs.AcademicYearId = sec.AcademicYearId AND cs.GradeLevelId = sec.GradeLevelId AND cs.ProgramId = sec.ProgramId
JOIN   academic.Subjects AS s ON s.SubjectId = cs.SubjectId
JOIN   #P AS p ON p.Code = CASE WHEN b.BranchCode = N'IRB' THEN CASE WHEN s.SubjectCode IN (N'ARB', N'ENG') THEN N'T6' ELSE N'T5' END
                                ELSE CASE s.SubjectCode WHEN N'ARB' THEN N'T3' WHEN N'ENG' THEN N'T2' WHEN N'MATH' THEN N'T1' ELSE N'T4' END END
WHERE  sec.AcademicYearId = @Y1;

-- Fee structures 2025-2026 (JOD). Registration, books and uniform are charged once (first installment).
INSERT INTO finance.FeeStructures (AcademicYearId, BranchId, GradeLevelId, ProgramId, CurrencyId, NameEn, NameAr)
SELECT @Y1, sec.BranchId, sec.GradeLevelId, sec.ProgramId, (SELECT CurrencyId FROM finance.Currencies WHERE CurrencyCode = N'JOD'),
       CONCAT(N'Fees 2025/2026 - ', sec.NameEn), CONCAT(N'رسوم 2025/2026 - ', sec.NameAr)
FROM   academic.Sections AS sec WHERE sec.AcademicYearId = @Y1;

INSERT INTO finance.FeeStructureItems (FeeStructureId, FeeTypeId, Amount, IsMandatory, IsInstallable)
SELECT fs.FeeStructureId, ft.FeeTypeId,
       CASE ft.Code WHEN N'TUITION' THEN CASE gl.Code WHEN N'G01' THEN 2400 WHEN N'G05' THEN 2900 WHEN N'G09' THEN 3300 ELSE 3800 END
                    WHEN N'REGISTRATION' THEN 150 WHEN N'BOOKS' THEN 120 WHEN N'UNIFORM' THEN 80 WHEN N'ACTIVITIES' THEN 100 END,
       1, CASE WHEN ft.Code IN (N'TUITION', N'ACTIVITIES') THEN 1 ELSE 0 END
FROM   finance.FeeStructures AS fs
JOIN   academic.GradeLevels AS gl ON gl.GradeLevelId = fs.GradeLevelId
JOIN   finance.FeeTypes AS ft ON ft.Code IN (N'TUITION', N'REGISTRATION', N'BOOKS', N'UNIFORM', N'ACTIVITIES')
WHERE  fs.AcademicYearId = @Y1;

INSERT INTO finance.FeeInstallments (FeeStructureId, InstallmentNumber, DueDate, InstallmentPercent)
SELECT fs.FeeStructureId, v.No, v.DueDate, v.Pct
FROM   finance.FeeStructures AS fs
CROSS JOIN (VALUES (1, CONVERT(DATE, '20250901'), 40.0), (2, CONVERT(DATE, '20251201'), 30.0), (3, CONVERT(DATE, '20260301'), 30.0)) AS v (No, DueDate, Pct)
WHERE  fs.AcademicYearId = @Y1;

-- Admission for S10 goes through the application workflow.
DECLARE @App INT, @Amm INT = (SELECT BranchId FROM organization.Branches WHERE BranchCode = N'AMM'),
        @G01 INT = (SELECT GradeLevelId FROM academic.GradeLevels WHERE Code = N'G01'),
        @Nat INT = (SELECT ProgramId FROM academic.Programs WHERE Code = N'NAT'),
        @S10 INT = (SELECT PersonId FROM #P WHERE Code = N'S10');
EXEC enrollment.usp_SubmitApplication @ApplicantPersonId = @S10, @AcademicYearId = @Y1, @BranchId = @Amm, @GradeLevelId = @G01,
     @ProgramId = @Nat, @ApplicationDate = '20250415', @ApplicationId = @App OUTPUT;
EXEC enrollment.usp_DecideApplication @ApplicationId = @App, @NewStatus = N'UnderReview', @DecisionDate = '20250420';
EXEC enrollment.usp_DecideApplication @ApplicationId = @App, @NewStatus = N'Accepted', @DecisionDate = '20250505', @Notes = N'Readiness assessment passed.';

IF OBJECT_ID(N'tempdb..#E') IS NOT NULL DROP TABLE #E;
CREATE TABLE #E (Code NVARCHAR(10) COLLATE DATABASE_DEFAULT NOT NULL, YearCode NVARCHAR(9) COLLATE DATABASE_DEFAULT NOT NULL, EnrollmentId INT NOT NULL,
                 PRIMARY KEY (Code, YearCode));

DECLARE @Code NVARCHAR(10), @Person INT, @Branch INT, @Grade INT, @Program INT, @Section INT, @AppId INT, @Enr INT;
DECLARE enroll_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT v.Code, p.PersonId, b.BranchId, gl.GradeLevelId, pr.ProgramId, sec.SectionId,
           CASE WHEN v.Code = N'S10' THEN @App END
    FROM (VALUES (N'S1', N'AMM', N'G05', N'NAT'), (N'S2', N'AMM', N'G01', N'NAT'), (N'S3', N'AMM', N'G05', N'NAT'),
                 (N'S4', N'AMM', N'G09', N'NAT'), (N'S5', N'AMM', N'G09', N'NAT'), (N'S6', N'AMM', N'G01', N'NAT'),
                 (N'S7', N'AMM', N'G05', N'NAT'), (N'S8', N'IRB', N'G12', N'NAT-SCI'), (N'S10', N'AMM', N'G01', N'NAT')
    ) AS v (Code, BranchCode, GradeCode, ProgramCode)
    JOIN #P AS p ON p.Code = v.Code
    JOIN organization.Branches AS b ON b.BranchCode = v.BranchCode
    JOIN academic.GradeLevels AS gl ON gl.Code = v.GradeCode
    JOIN academic.Programs AS pr ON pr.Code = v.ProgramCode
    JOIN academic.Sections AS sec ON sec.AcademicYearId = @Y1 AND sec.BranchId = b.BranchId AND sec.GradeLevelId = gl.GradeLevelId AND sec.SectionCode = N'A'
    ORDER BY v.Code;
OPEN enroll_cursor;
FETCH NEXT FROM enroll_cursor INTO @Code, @Person, @Branch, @Grade, @Program, @Section, @AppId;
WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC enrollment.usp_EnrollStudent @PersonId = @Person, @AcademicYearId = @Y1, @BranchId = @Branch, @GradeLevelId = @Grade,
         @ProgramId = @Program, @EnrollmentDate = '20250825', @SectionId = @Section, @ApplicationId = @AppId, @EnrollmentId = @Enr OUTPUT;
    INSERT INTO #E (Code, YearCode, EnrollmentId) VALUES (@Code, N'2025-2026', @Enr);
    FETCH NEXT FROM enroll_cursor INTO @Code, @Person, @Branch, @Grade, @Program, @Section, @AppId;
END;
CLOSE enroll_cursor; DEALLOCATE enroll_cursor;

-- Student <-> guardian links (M:N with attributes).
INSERT INTO people.StudentGuardians (StudentId, GuardianId, RelationshipTypeId, IsPrimaryContact, HasCustody, CanPickUp, IsEmergencyContact, LivesWithStudent)
SELECT s.PersonId, g.PersonId, rt.RelationshipTypeId, v.PrimaryContact, 1, 1, v.Emergency, v.LivesWith
FROM (VALUES
    (N'S1', N'G1', N'FATHER', 1, 1, 1), (N'S1', N'G2', N'MOTHER', 0, 1, 1),
    (N'S2', N'G1', N'FATHER', 1, 1, 1), (N'S2', N'G2', N'MOTHER', 0, 1, 1),
    (N'S3', N'T1', N'FATHER', 1, 1, 1),
    (N'S4', N'G4', N'MOTHER', 1, 1, 1),
    (N'S5', N'G5', N'FATHER', 1, 1, 1), (N'S6', N'G5', N'FATHER', 1, 1, 1),
    (N'S7', N'G6', N'MOTHER', 1, 1, 1),
    (N'S8', N'T5', N'UNCLE',  1, 1, 0),
    (N'S10', N'G7', N'FATHER', 1, 1, 1)
) AS v (StudentCode, GuardianCode, Rel, PrimaryContact, Emergency, LivesWith)
JOIN #P AS s ON s.Code = v.StudentCode
JOIN #P AS g ON g.Code = v.GuardianCode
JOIN people.RelationshipTypes AS rt ON rt.Code = v.Rel;

-- Who pays: S5's fees are split 50/50 between his father and the father's employer fund.
INSERT INTO finance.StudentPayers (EnrollmentId, PayerId, ResponsibilityPercent)
SELECT e.EnrollmentId, py.PayerId, v.Pct
FROM (VALUES (N'S1', N'G1', 100.0), (N'S2', N'G1', 100.0), (N'S3', N'T1', 100.0), (N'S4', N'G4', 100.0),
             (N'S5', N'G5', 50.0), (N'S6', N'G5', 100.0), (N'S7', N'G6', 100.0), (N'S8', N'T5', 100.0), (N'S10', N'G7', 100.0)
) AS v (StudentCode, GuardianCode, Pct)
JOIN #E AS e ON e.Code = v.StudentCode AND e.YearCode = N'2025-2026'
JOIN #P AS g ON g.Code = v.GuardianCode
JOIN finance.Payers AS py ON py.GuardianId = g.PersonId;

INSERT INTO finance.StudentPayers (EnrollmentId, PayerId, ResponsibilityPercent)
SELECT e.EnrollmentId, py.PayerId, 50.0
FROM #E AS e
JOIN finance.Sponsors AS sp ON sp.SponsorCode = N'WAHA'
JOIN finance.Payers AS py ON py.SponsorId = sp.SponsorId
WHERE e.Code = N'S5' AND e.YearCode = N'2025-2026';

-- Discounts: sibling (S2), staff child (S3), merit (S5), financial aid as a fixed amount (S7).
INSERT INTO finance.StudentDiscounts (EnrollmentId, DiscountTypeId, FeeTypeId, DiscountPercent, DiscountAmount, Reason, ApprovedByUserId, ApprovedAt)
SELECT e.EnrollmentId, dt.DiscountTypeId, ft.FeeTypeId, v.Pct, v.Amt, v.Reason, TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId')), '20250820'
FROM (VALUES
    (N'S2', N'SIBLING', 10.0, NULL,  N'Second child enrolled (sibling of S1)'),
    (N'S3', N'STAFF',   50.0, NULL,  N'Child of staff member (Mathematics teacher)'),
    (N'S5', N'MERIT',   25.0, NULL,  N'Top of Grade 8 in 2024/2025'),
    (N'S7', N'FINAID',  NULL, 300.0, N'Financial aid committee decision 2025/14')
) AS v (StudentCode, DiscountCode, Pct, Amt, Reason)
JOIN #E AS e ON e.Code = v.StudentCode AND e.YearCode = N'2025-2026'
JOIN finance.DiscountTypes AS dt ON dt.Code = v.DiscountCode
JOIN finance.FeeTypes AS ft ON ft.Code = N'TUITION';
GO

/* =============================================================================
   E1. Year 1 billing (installments 1-2), then S10's mid-year transfer with a
       pro-rata credit note
   ============================================================================= */
DECLARE @Y1 INT = (SELECT AcademicYearId FROM academic.AcademicYears WHERE YearCode = N'2025-2026');
DECLARE @EnrollmentId INT, @InstallmentId INT, @InvoiceDate DATE;
DECLARE @Issued TABLE (InvoiceId BIGINT, InvoiceNumber NVARCHAR(30), PayerId INT, TotalAmount DECIMAL(19,4));

DECLARE inv_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT e.EnrollmentId, fi.FeeInstallmentId, CASE fi.InstallmentNumber WHEN 1 THEN CONVERT(DATE, '20250825') ELSE CONVERT(DATE, '20251120') END
    FROM   enrollment.Enrollments AS e
    JOIN   finance.FeeStructures AS fs ON fs.AcademicYearId = e.AcademicYearId AND fs.BranchId = e.BranchId AND fs.GradeLevelId = e.GradeLevelId AND fs.ProgramId = e.ProgramId
    JOIN   finance.FeeInstallments AS fi ON fi.FeeStructureId = fs.FeeStructureId
    WHERE  e.AcademicYearId = @Y1 AND fi.InstallmentNumber IN (1, 2) AND e.EnrollmentStatus = N'Enrolled'
    ORDER BY fi.InstallmentNumber, e.EnrollmentId;
OPEN inv_cursor;
FETCH NEXT FROM inv_cursor INTO @EnrollmentId, @InstallmentId, @InvoiceDate;
WHILE @@FETCH_STATUS = 0
BEGIN
    INSERT INTO @Issued EXEC finance.usp_IssueInvoice @EnrollmentId = @EnrollmentId, @FeeInstallmentId = @InstallmentId, @InvoiceDate = @InvoiceDate;
    FETCH NEXT FROM inv_cursor INTO @EnrollmentId, @InstallmentId, @InvoiceDate;
END;
CLOSE inv_cursor; DEALLOCATE inv_cursor;

-- S10 transfers to another school on 2026-02-15 (history is kept, nothing deleted).
DECLARE @S10Enr INT = (SELECT EnrollmentId FROM #E WHERE Code = N'S10' AND YearCode = N'2025-2026');
EXEC enrollment.usp_WithdrawStudent @EnrollmentId = @S10Enr, @WithdrawalDate = '20260215', @NewStatus = N'Transferred',
     @Reason = N'Family relocated to Aqaba / انتقال العائلة إلى العقبة';

-- Credit 40% of S10's installment-2 invoice before the family settles it.
DECLARE @S10Inv BIGINT, @S10Credit DECIMAL(19,4), @Cn BIGINT;
SELECT TOP (1) @S10Inv = i.InvoiceId, @S10Credit = ROUND(i.TotalAmount * 0.40, 3)
FROM   finance.Invoices AS i
JOIN   finance.FeeInstallments AS fi ON fi.FeeInstallmentId = i.FeeInstallmentId
WHERE  i.EnrollmentId = @S10Enr AND fi.InstallmentNumber = 2;
EXEC finance.usp_IssueCreditNote @InvoiceId = @S10Inv, @Amount = @S10Credit, @CreditDate = '20260216',
     @Reason = N'Pro-rata adjustment on transfer / تسوية نسبية بسبب الانتقال', @CreditNoteId = @Cn OUTPUT;
GO

/* =============================================================================
   D. Year 1 teaching cycle: attendance (TVP), assessments, results,
      a grade correction, and report cards
   ============================================================================= */
DECLARE @Y1 INT = (SELECT AcademicYearId FROM academic.AcademicYears WHERE YearCode = N'2025-2026');
DECLARE @SectionId INT, @Day DATE, @Session BIGINT, @Taker INT;
DECLARE @Entries attendance.AttendanceEntryList;

DECLARE att_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT sec.SectionId, d.Day, sec.HomeroomTeacherId
    FROM   academic.Sections AS sec
    CROSS JOIN (VALUES (CONVERT(DATE, '20250907')), ('20250908'), ('20250909'), ('20260215'), ('20260216'), ('20260217')) AS d (Day)
    WHERE  sec.AcademicYearId = @Y1
    ORDER BY sec.SectionId, d.Day;
OPEN att_cursor;
FETCH NEXT FROM att_cursor INTO @SectionId, @Day, @Taker;
WHILE @@FETCH_STATUS = 0
BEGIN
    DELETE FROM @Entries;
    INSERT INTO @Entries (EnrollmentId, StatusCode, MinutesLate, Remarks)
    SELECT sa.EnrollmentId,
           CASE (sa.EnrollmentId * 3 + DAY(@Day)) % 11 WHEN 0 THEN N'ABSENT' WHEN 1 THEN N'LATE' WHEN 2 THEN N'EXCUSED' ELSE N'PRESENT' END,
           CASE (sa.EnrollmentId * 3 + DAY(@Day)) % 11 WHEN 1 THEN 10 END,
           CASE (sa.EnrollmentId * 3 + DAY(@Day)) % 11 WHEN 2 THEN N'Medical appointment / موعد طبي' END
    FROM   enrollment.SectionAssignments AS sa
    WHERE  sa.SectionId = @SectionId AND sa.StartDate <= @Day AND (sa.EndDate IS NULL OR sa.EndDate >= @Day);

    IF EXISTS (SELECT 1 FROM @Entries)
        EXEC attendance.usp_RecordSectionAttendance @SectionId = @SectionId, @SessionDate = @Day, @Entries = @Entries,
             @TakenByEmployeeId = @Taker, @AttendanceSessionId = @Session OUTPUT;
    FETCH NEXT FROM att_cursor INTO @SectionId, @Day, @Taker;
END;
CLOSE att_cursor; DEALLOCATE att_cursor;

-- Assessments: Quiz, Midterm, Final in each term for every teaching assignment.
INSERT INTO assessment.Assessments (TeachingAssignmentId, TermId, AssessmentTypeId, TitleEn, TitleAr, AssessmentDate, MaxScore, IsPublished)
SELECT ta.TeachingAssignmentId, t.TermId, at.AssessmentTypeId,
       CONCAT(s.NameEn, N' - ', at.NameEn, N' (', t.NameEn, N')'),
       CONCAT(s.NameAr, N' - ', at.NameAr, N' (', t.NameAr, N')'),
       DATEADD(DAY, v.Offset, t.StartDate), v.MaxScore, 1
FROM   academic.TeachingAssignments AS ta
JOIN   academic.Sections AS sec ON sec.SectionId = ta.SectionId
JOIN   academic.CurriculumSubjects AS cs ON cs.CurriculumSubjectId = ta.CurriculumSubjectId
JOIN   academic.Subjects AS s ON s.SubjectId = cs.SubjectId
JOIN   academic.Terms AS t ON t.AcademicYearId = sec.AcademicYearId
CROSS JOIN (VALUES (N'QUIZ', 27, 20.0), (N'MIDTERM', 62, 50.0), (N'FINAL', 120, 100.0)) AS v (TypeCode, Offset, MaxScore)
JOIN   assessment.AssessmentTypes AS at ON at.Code = v.TypeCode
WHERE  sec.AcademicYearId = @Y1;

DECLARE @AssessmentId INT, @AssessDate DATE, @AssessSection INT, @Max DECIMAL(9,3);
DECLARE @Results assessment.ResultEntryList;
DECLARE res_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT a.AssessmentId, a.AssessmentDate, ta.SectionId, a.MaxScore
    FROM   assessment.Assessments AS a
    JOIN   academic.TeachingAssignments AS ta ON ta.TeachingAssignmentId = a.TeachingAssignmentId
    JOIN   academic.Sections AS sec ON sec.SectionId = ta.SectionId
    WHERE  sec.AcademicYearId = @Y1
    ORDER BY a.AssessmentId;
OPEN res_cursor;
FETCH NEXT FROM res_cursor INTO @AssessmentId, @AssessDate, @AssessSection, @Max;
WHILE @@FETCH_STATUS = 0
BEGIN
    DELETE FROM @Results;
    INSERT INTO @Results (EnrollmentId, Score, IsAbsent, IsExempt, Comment)
    SELECT sa.EnrollmentId,
           CASE WHEN (sa.EnrollmentId + @AssessmentId) % 23 = 0 THEN NULL
                ELSE CAST(ROUND(@Max * (55 + ABS(CHECKSUM(sa.EnrollmentId * 7919 + @AssessmentId)) % 45) / 100.0, 1) AS DECIMAL(9,3)) END,
           CASE WHEN (sa.EnrollmentId + @AssessmentId) % 23 = 0 THEN 1 ELSE 0 END,
           0, NULL
    FROM   enrollment.SectionAssignments AS sa
    WHERE  sa.SectionId = @AssessSection AND sa.StartDate <= @AssessDate AND (sa.EndDate IS NULL OR sa.EndDate >= @AssessDate);

    IF EXISTS (SELECT 1 FROM @Results)
        EXEC assessment.usp_RecordResults @AssessmentId = @AssessmentId, @Results = @Results;
    FETCH NEXT FROM res_cursor INTO @AssessmentId, @AssessDate, @AssessSection, @Max;
END;
CLOSE res_cursor; DEALLOCATE res_cursor;
GO

-- Report cards: generate + publish both terms for every Year 1 section.
DECLARE @Y1 INT = (SELECT AcademicYearId FROM academic.AcademicYears WHERE YearCode = N'2025-2026');
DECLARE @SectionId INT, @TermId INT;
DECLARE rc_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT sec.SectionId, t.TermId FROM academic.Sections AS sec JOIN academic.Terms AS t ON t.AcademicYearId = sec.AcademicYearId
    WHERE sec.AcademicYearId = @Y1 ORDER BY t.TermNumber, sec.SectionId;
OPEN rc_cursor;
FETCH NEXT FROM rc_cursor INTO @SectionId, @TermId;
WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC assessment.usp_GenerateReportCards @SectionId = @SectionId, @TermId = @TermId;
    EXEC assessment.usp_PublishReportCards  @SectionId = @SectionId, @TermId = @TermId;
    FETCH NEXT FROM rc_cursor INTO @SectionId, @TermId;
END;
CLOSE rc_cursor; DEALLOCATE rc_cursor;

-- A grade correction after publication: S1's Term 2 Mathematics final is re-marked.
-- The temporal history keeps the old score; the report card is re-issued as version 2.
DECLARE @S1Enr INT = (SELECT EnrollmentId FROM #E WHERE Code = N'S1' AND YearCode = N'2025-2026');
DECLARE @FinalId INT, @Sec INT, @T2 INT;
SELECT @FinalId = a.AssessmentId, @Sec = ta.SectionId, @T2 = a.TermId
FROM   assessment.Assessments AS a
JOIN   academic.TeachingAssignments AS ta ON ta.TeachingAssignmentId = a.TeachingAssignmentId
JOIN   academic.CurriculumSubjects AS cs ON cs.CurriculumSubjectId = ta.CurriculumSubjectId
JOIN   academic.Subjects AS s ON s.SubjectId = cs.SubjectId
JOIN   academic.Terms AS t ON t.TermId = a.TermId
JOIN   assessment.AssessmentTypes AS at ON at.AssessmentTypeId = a.AssessmentTypeId
JOIN   enrollment.SectionAssignments AS sa ON sa.SectionId = ta.SectionId AND sa.EnrollmentId = @S1Enr
WHERE  s.SubjectCode = N'MATH' AND at.Code = N'FINAL' AND t.TermNumber = 2 AND t.AcademicYearId = (SELECT AcademicYearId FROM academic.AcademicYears WHERE YearCode = N'2025-2026');

DECLARE @Fix assessment.ResultEntryList;
INSERT INTO @Fix (EnrollmentId, Score, IsAbsent, IsExempt, Comment)
VALUES (@S1Enr, 96.5, 0, 0, N'Re-marked after review: question 7 / أعيد التصحيح بعد المراجعة');
EXEC assessment.usp_RecordResults @AssessmentId = @FinalId, @Results = @Fix;
EXEC assessment.usp_GenerateReportCards @SectionId = @Sec, @TermId = @T2;
EXEC assessment.usp_PublishReportCards  @SectionId = @Sec, @TermId = @T2;

UPDATE assessment.ReportCards
SET    HomeroomCommentEn = N'Excellent effort throughout the year.', HomeroomCommentAr = N'جهد ممتاز طوال العام.'
WHERE  EnrollmentId = @S1Enr AND TermId = @T2 AND ReportCardStatus = N'Published';
GO

/* =============================================================================
   E2. Year 1 finance: installment 3 and payments
   ============================================================================= */
DECLARE @Y1 INT = (SELECT AcademicYearId FROM academic.AcademicYears WHERE YearCode = N'2025-2026');
DECLARE @Amm INT = (SELECT BranchId FROM organization.Branches WHERE BranchCode = N'AMM');
DECLARE @EnrollmentId INT, @InstallmentId INT;
DECLARE @Issued TABLE (InvoiceId BIGINT, InvoiceNumber NVARCHAR(30), PayerId INT, TotalAmount DECIMAL(19,4));

-- Installment 3 (only students still enrolled in March 2026).
DECLARE inv3_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT e.EnrollmentId, fi.FeeInstallmentId
    FROM   enrollment.Enrollments AS e
    JOIN   finance.FeeStructures AS fs ON fs.AcademicYearId = e.AcademicYearId AND fs.BranchId = e.BranchId AND fs.GradeLevelId = e.GradeLevelId AND fs.ProgramId = e.ProgramId
    JOIN   finance.FeeInstallments AS fi ON fi.FeeStructureId = fs.FeeStructureId
    WHERE  e.AcademicYearId = @Y1 AND fi.InstallmentNumber = 3 AND e.EnrollmentStatus = N'Enrolled'
    ORDER BY e.EnrollmentId;
OPEN inv3_cursor;
FETCH NEXT FROM inv3_cursor INTO @EnrollmentId, @InstallmentId;
WHILE @@FETCH_STATUS = 0
BEGIN
    INSERT INTO @Issued EXEC finance.usp_IssueInvoice @EnrollmentId = @EnrollmentId, @FeeInstallmentId = @InstallmentId, @InvoiceDate = '20260220';
    FETCH NEXT FROM inv3_cursor INTO @EnrollmentId, @InstallmentId;
END;
CLOSE inv3_cursor; DEALLOCATE inv3_cursor;

-- Payments: everyone settles Year 1 in full (FIFO), except S7's guardian who pays 60%.
DECLARE @PayerId INT, @Due DECIMAL(19,4), @Method NVARCHAR(20), @Ref NVARCHAR(100), @PaymentId BIGINT, @n INT = 0;
DECLARE @NoAlloc finance.AllocationList;
DECLARE pay_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT ib.PayerId, SUM(ib.BalanceAmount)
    FROM   finance.vw_InvoiceBalances AS ib
    JOIN   enrollment.Enrollments AS e ON e.EnrollmentId = ib.EnrollmentId
    WHERE  e.AcademicYearId = @Y1 AND ib.InvoiceStatus IN (N'Issued', N'PartiallyPaid')
    GROUP BY ib.PayerId
    ORDER BY ib.PayerId;
OPEN pay_cursor;
FETCH NEXT FROM pay_cursor INTO @PayerId, @Due;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @n += 1;
    SELECT @Method = CASE WHEN py.PayerType = N'Sponsor' THEN N'TRANSFER' WHEN @n % 3 = 0 THEN N'EFAWATEER' WHEN @n % 3 = 1 THEN N'CASH' ELSE N'CARD' END
    FROM finance.Payers AS py WHERE py.PayerId = @PayerId;
    SET @Ref = CASE WHEN @Method = N'CASH' THEN NULL ELSE CONCAT(@Method, N'-2526-', RIGHT(N'00000' + CAST(@PayerId AS NVARCHAR(10)), 5)) END;
    IF EXISTS (SELECT 1 FROM finance.Payers AS py JOIN #P AS p ON p.PersonId = py.GuardianId WHERE py.PayerId = @PayerId AND p.Code = N'G6')
        SET @Due = ROUND(@Due * 0.60, 3);
    EXEC finance.usp_RecordPayment @PayerId = @PayerId, @BranchId = @Amm, @PaymentMethodCode = @Method, @PaymentDate = '20260310',
         @Amount = @Due, @Allocations = @NoAlloc, @ReferenceNumber = @Ref, @PaymentId = @PaymentId OUTPUT;
    FETCH NEXT FROM pay_cursor INTO @PayerId, @Due;
END;
CLOSE pay_cursor; DEALLOCATE pay_cursor;
GO

/* =============================================================================
   F. Year-end: promotion outcomes, rollover, close 2025-2026, open 2026-2027
   ============================================================================= */
DECLARE @Y1 INT = (SELECT AcademicYearId FROM academic.AcademicYears WHERE YearCode = N'2025-2026');
DECLARE @Y2 INT = (SELECT AcademicYearId FROM academic.AcademicYears WHERE YearCode = N'2026-2027');

UPDATE e
SET    PromotionOutcome = CASE WHEN x.Code = N'S7' THEN N'Retained' WHEN gl.Code = N'G12' THEN N'Graduated' ELSE N'Promoted' END,
       UpdatedAt = SYSUTCDATETIME(), UpdatedBy = TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))
FROM   enrollment.Enrollments AS e
JOIN   academic.GradeLevels AS gl ON gl.GradeLevelId = e.GradeLevelId
JOIN   #E AS x ON x.EnrollmentId = e.EnrollmentId
WHERE  e.AcademicYearId = @Y1 AND e.EnrollmentStatus = N'Enrolled';

EXEC enrollment.usp_PromoteStudents @FromAcademicYearId = @Y1, @ToAcademicYearId = @Y2;

UPDATE academic.AcademicYears SET YearStatus = N'Closed', UpdatedAt = SYSUTCDATETIME() WHERE AcademicYearId = @Y1;
UPDATE academic.AcademicYears SET YearStatus = N'Active', UpdatedAt = SYSUTCDATETIME() WHERE AcademicYearId = @Y2;

INSERT INTO #E (Code, YearCode, EnrollmentId)
SELECT x.Code, N'2026-2027', e2.EnrollmentId
FROM   #E AS x
JOIN   enrollment.Enrollments AS e1 ON e1.EnrollmentId = x.EnrollmentId
JOIN   enrollment.Enrollments AS e2 ON e2.StudentId = e1.StudentId AND e2.AcademicYearId = @Y2
WHERE  x.YearCode = N'2025-2026';
GO

/* =============================================================================
   G. Year 2 (2026-2027, current): admissions, sections, timetable, attendance,
      assessments, invoices and payments
   ============================================================================= */
DECLARE @Y2 INT = (SELECT AcademicYearId FROM academic.AcademicYears WHERE YearCode = N'2026-2027');
DECLARE @Amm INT = (SELECT BranchId FROM organization.Branches WHERE BranchCode = N'AMM');

INSERT INTO academic.Sections (AcademicYearId, BranchId, GradeLevelId, ProgramId, SectionCode, NameEn, NameAr, Capacity, HomeroomTeacherId, HomeRoomId)
SELECT @Y2, @Amm, gl.GradeLevelId, pr.ProgramId, N'A', v.NameEn, v.NameAr, v.Capacity, p.PersonId, r.RoomId
FROM (VALUES
    (N'G01', N'Grade 1 - A',  N'الصف الأول - أ',  25, N'T3', N'R101'),
    (N'G02', N'Grade 2 - A',  N'الصف الثاني - أ', 25, N'T2', N'R104'),
    (N'G05', N'Grade 5 - A',  N'الصف الخامس - أ', 28, N'T4', N'R105'),
    (N'G06', N'Grade 6 - A',  N'الصف السادس - أ', 28, N'T1', N'R102'),
    (N'G10', N'Grade 10 - A', N'الصف العاشر - أ', 30, N'T4', N'R103')
) AS v (GradeCode, NameEn, NameAr, Capacity, Homeroom, RoomCode)
JOIN academic.GradeLevels AS gl ON gl.Code = v.GradeCode
JOIN academic.Programs    AS pr ON pr.Code = N'NAT'
JOIN #P AS p ON p.Code = v.Homeroom
JOIN organization.Buildings AS bd ON bd.BranchId = @Amm
JOIN organization.Rooms AS r ON r.BuildingId = bd.BuildingId AND r.RoomCode = v.RoomCode;

INSERT INTO academic.TeachingAssignments (SectionId, CurriculumSubjectId, TeacherId, TermId)
SELECT sec.SectionId, cs.CurriculumSubjectId, p.PersonId, NULL
FROM   academic.Sections AS sec
JOIN   academic.CurriculumSubjects AS cs ON cs.AcademicYearId = sec.AcademicYearId AND cs.GradeLevelId = sec.GradeLevelId AND cs.ProgramId = sec.ProgramId
JOIN   academic.Subjects AS s ON s.SubjectId = cs.SubjectId
JOIN   #P AS p ON p.Code = CASE s.SubjectCode WHEN N'ARB' THEN N'T3' WHEN N'ENG' THEN N'T2' WHEN N'MATH' THEN N'T1' ELSE N'T4' END
WHERE  sec.AcademicYearId = @Y2;

-- Place promoted / retained students into their new sections.
DECLARE @EnrollmentId INT, @SectionId INT;
DECLARE place_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT e.EnrollmentId, sec.SectionId
    FROM   enrollment.Enrollments AS e
    JOIN   academic.Sections AS sec ON sec.AcademicYearId = e.AcademicYearId AND sec.BranchId = e.BranchId
                                   AND sec.GradeLevelId = e.GradeLevelId AND sec.SectionCode = N'A'
    WHERE  e.AcademicYearId = @Y2
      AND  NOT EXISTS (SELECT 1 FROM enrollment.SectionAssignments AS sa WHERE sa.EnrollmentId = e.EnrollmentId);
OPEN place_cursor;
FETCH NEXT FROM place_cursor INTO @EnrollmentId, @SectionId;
WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC enrollment.usp_AssignSection @EnrollmentId = @EnrollmentId, @SectionId = @SectionId, @StartDate = '20260830', @Reason = N'Annual placement';
    FETCH NEXT FROM place_cursor INTO @EnrollmentId, @SectionId;
END;
CLOSE place_cursor; DEALLOCATE place_cursor;

-- New admissions: Noor (accepted, enrolled) and Jad (waitlisted - a Person with no subtype yet).
DECLARE @Noor INT, @Jad INT, @AppNoor INT, @AppJad INT, @NoorEnr INT;
DECLARE @G01 INT = (SELECT GradeLevelId FROM academic.GradeLevels WHERE Code = N'G01'),
        @Nat INT = (SELECT ProgramId FROM academic.Programs WHERE Code = N'NAT'),
        @G01Sec INT = (SELECT SectionId FROM academic.Sections WHERE AcademicYearId = @Y2 AND GradeLevelId = (SELECT GradeLevelId FROM academic.GradeLevels WHERE Code = N'G01'));

EXEC people.usp_CreatePerson @FirstNameEn = N'Noor', @FatherNameEn = N'Omar', @GrandfatherNameEn = N'Saleh', @FamilyNameEn = N'Al-Khatib',
     @FirstNameAr = N'نور', @FatherNameAr = N'عمر', @GrandfatherNameAr = N'صالح', @FamilyNameAr = N'الخطيب',
     @Gender = N'F', @DateOfBirth = '20200603', @NationalityIso2 = N'JO', @PrimaryLanguage = N'ar', @PersonId = @Noor OUTPUT;
EXEC people.usp_CreatePerson @FirstNameEn = N'Jad', @FatherNameEn = N'Rami', @GrandfatherNameEn = N'Saleh', @FamilyNameEn = N'Al-Hourani',
     @FirstNameAr = N'جاد', @FatherNameAr = N'رامي', @GrandfatherNameAr = N'صالح', @FamilyNameAr = N'الحوراني',
     @Gender = N'M', @DateOfBirth = '20200219', @NationalityIso2 = N'JO', @PrimaryLanguage = N'ar',
     @MobilePhone = N'+962795000019', @PersonId = @Jad OUTPUT;
INSERT INTO #P (Code, PersonId) VALUES (N'S9', @Noor), (N'A2', @Jad);

EXEC enrollment.usp_SubmitApplication @ApplicantPersonId = @Noor, @AcademicYearId = @Y2, @BranchId = @Amm, @GradeLevelId = @G01,
     @ProgramId = @Nat, @ApplicationDate = '20260410', @ApplicationId = @AppNoor OUTPUT;
EXEC enrollment.usp_DecideApplication @ApplicationId = @AppNoor, @NewStatus = N'Accepted', @DecisionDate = '20260502';
EXEC enrollment.usp_SubmitApplication @ApplicantPersonId = @Jad, @AcademicYearId = @Y2, @BranchId = @Amm, @GradeLevelId = @G01,
     @ProgramId = @Nat, @ApplicationDate = '20260601', @ApplicationId = @AppJad OUTPUT;
EXEC enrollment.usp_DecideApplication @ApplicationId = @AppJad, @NewStatus = N'Waitlisted', @DecisionDate = '20260615', @Notes = N'Grade 1 places fully allocated; waitlist position 1.';

EXEC enrollment.usp_EnrollStudent @PersonId = @Noor, @AcademicYearId = @Y2, @BranchId = @Amm, @GradeLevelId = @G01, @ProgramId = @Nat,
     @EnrollmentDate = '20260820', @SectionId = @G01Sec, @ApplicationId = @AppNoor, @EnrollmentId = @NoorEnr OUTPUT;
INSERT INTO #E (Code, YearCode, EnrollmentId) VALUES (N'S9', N'2026-2027', @NoorEnr);

-- Omar (Arabic teacher) now also becomes a guardian: a third overlapping role holder.
INSERT INTO people.Guardians (PersonId, Occupation, EmployerName, PreferredLanguage)
SELECT PersonId, N'Teacher', N'Al-Noor International School', N'ar' FROM #P WHERE Code = N'T3';
INSERT INTO people.StudentGuardians (StudentId, GuardianId, RelationshipTypeId, IsPrimaryContact, IsEmergencyContact)
SELECT @Noor, p.PersonId, rt.RelationshipTypeId, 1, 1 FROM #P AS p JOIN people.RelationshipTypes AS rt ON rt.Code = N'FATHER' WHERE p.Code = N'T3';
INSERT INTO finance.Payers (PayerType, GuardianId) SELECT N'Guardian', PersonId FROM #P WHERE Code = N'T3';

-- Fee structures 2026-2027 (+5% tuition).
INSERT INTO finance.FeeStructures (AcademicYearId, BranchId, GradeLevelId, ProgramId, CurrencyId, NameEn, NameAr)
SELECT @Y2, sec.BranchId, sec.GradeLevelId, sec.ProgramId, (SELECT CurrencyId FROM finance.Currencies WHERE CurrencyCode = N'JOD'),
       CONCAT(N'Fees 2026/2027 - ', sec.NameEn), CONCAT(N'رسوم 2026/2027 - ', sec.NameAr)
FROM   academic.Sections AS sec WHERE sec.AcademicYearId = @Y2;

INSERT INTO finance.FeeStructureItems (FeeStructureId, FeeTypeId, Amount, IsMandatory, IsInstallable)
SELECT fs.FeeStructureId, ft.FeeTypeId,
       CASE ft.Code WHEN N'TUITION' THEN CASE gl.Code WHEN N'G01' THEN 2520 WHEN N'G02' THEN 2600 WHEN N'G05' THEN 3045 WHEN N'G06' THEN 3100 ELSE 3465 END
                    WHEN N'REGISTRATION' THEN 150 WHEN N'BOOKS' THEN 125 WHEN N'UNIFORM' THEN 85 WHEN N'ACTIVITIES' THEN 110 END,
       1, CASE WHEN ft.Code IN (N'TUITION', N'ACTIVITIES') THEN 1 ELSE 0 END
FROM   finance.FeeStructures AS fs
JOIN   academic.GradeLevels AS gl ON gl.GradeLevelId = fs.GradeLevelId
JOIN   finance.FeeTypes AS ft ON ft.Code IN (N'TUITION', N'REGISTRATION', N'BOOKS', N'UNIFORM', N'ACTIVITIES')
WHERE  fs.AcademicYearId = @Y2;

INSERT INTO finance.FeeInstallments (FeeStructureId, InstallmentNumber, DueDate, InstallmentPercent)
SELECT fs.FeeStructureId, v.No, v.DueDate, v.Pct
FROM   finance.FeeStructures AS fs
CROSS JOIN (VALUES (1, CONVERT(DATE, '20260901'), 40.0), (2, CONVERT(DATE, '20261201'), 30.0), (3, CONVERT(DATE, '20270301'), 30.0)) AS v (No, DueDate, Pct)
WHERE  fs.AcademicYearId = @Y2;

-- A fee correction (temporal history on FeeStructureItems): G10 activities fee revised.
UPDATE fsi SET Amount = 120, UpdatedAt = SYSUTCDATETIME(), UpdatedBy = TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))
FROM   finance.FeeStructureItems AS fsi
JOIN   finance.FeeStructures AS fs ON fs.FeeStructureId = fsi.FeeStructureId
JOIN   academic.GradeLevels AS gl ON gl.GradeLevelId = fs.GradeLevelId
JOIN   finance.FeeTypes AS ft ON ft.FeeTypeId = fsi.FeeTypeId
WHERE  fs.AcademicYearId = @Y2 AND gl.Code = N'G10' AND ft.Code = N'ACTIVITIES';

-- Roll payer responsibilities and still-valid discounts into the new year.
INSERT INTO finance.StudentPayers (EnrollmentId, PayerId, ResponsibilityPercent)
SELECT e2.EnrollmentId, sp.PayerId, sp.ResponsibilityPercent
FROM   #E AS x2
JOIN   #E AS x1 ON x1.Code = x2.Code AND x1.YearCode = N'2025-2026'
JOIN   finance.StudentPayers AS sp ON sp.EnrollmentId = x1.EnrollmentId
JOIN   enrollment.Enrollments AS e2 ON e2.EnrollmentId = x2.EnrollmentId
WHERE  x2.YearCode = N'2026-2027';
INSERT INTO finance.StudentPayers (EnrollmentId, PayerId, ResponsibilityPercent)
SELECT @NoorEnr, py.PayerId, 100 FROM finance.Payers AS py JOIN #P AS p ON p.PersonId = py.GuardianId WHERE p.Code = N'T3';

INSERT INTO finance.StudentDiscounts (EnrollmentId, DiscountTypeId, FeeTypeId, DiscountPercent, DiscountAmount, Reason, ApprovedByUserId, ApprovedAt)
SELECT x2.EnrollmentId, sd.DiscountTypeId, sd.FeeTypeId, sd.DiscountPercent, sd.DiscountAmount, CONCAT(sd.Reason, N' (renewed 2026/2027)'), TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId')), '20260815'
FROM   #E AS x2
JOIN   #E AS x1 ON x1.Code = x2.Code AND x1.YearCode = N'2025-2026'
JOIN   finance.StudentDiscounts AS sd ON sd.EnrollmentId = x1.EnrollmentId AND sd.IsActive = 1
WHERE  x2.YearCode = N'2026-2027';
INSERT INTO finance.StudentDiscounts (EnrollmentId, DiscountTypeId, FeeTypeId, DiscountPercent, Reason, ApprovedByUserId, ApprovedAt)
SELECT @NoorEnr, dt.DiscountTypeId, ft.FeeTypeId, 50, N'Child of staff member (Arabic teacher)', TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId')), '20260815'
FROM finance.DiscountTypes AS dt JOIN finance.FeeTypes AS ft ON ft.Code = N'TUITION' WHERE dt.Code = N'STAFF';
GO

-- Bell schedule, timetables for Grade 6-A and Grade 10-A, clash-checked publish.
DECLARE @Y2 INT = (SELECT AcademicYearId FROM academic.AcademicYears WHERE YearCode = N'2026-2027');
DECLARE @Amm INT = (SELECT BranchId FROM organization.Branches WHERE BranchCode = N'AMM');
DECLARE @T1 INT = (SELECT TermId FROM academic.Terms WHERE AcademicYearId = @Y2 AND TermNumber = 1);

INSERT INTO timetable.BellSchedules (BranchId, AcademicYearId, NameEn, NameAr, IsDefault)
VALUES (@Amm, @Y2, N'Standard 7-period day', N'الدوام القياسي - 7 حصص', 1);
DECLARE @Bell INT = SCOPE_IDENTITY();

INSERT INTO timetable.Periods (BellScheduleId, PeriodNumber, NameEn, NameAr, StartTime, EndTime, IsBreak)
VALUES (@Bell, 1, N'Period 1', N'الحصة الأولى',  '08:00', '08:45', 0),
       (@Bell, 2, N'Period 2', N'الحصة الثانية', '08:50', '09:35', 0),
       (@Bell, 3, N'Period 3', N'الحصة الثالثة', '09:40', '10:25', 0),
       (@Bell, 4, N'Break',    N'الاستراحة',     '10:25', '10:50', 1),
       (@Bell, 5, N'Period 4', N'الحصة الرابعة', '10:50', '11:35', 0),
       (@Bell, 6, N'Period 5', N'الحصة الخامسة', '11:40', '12:25', 0),
       (@Bell, 7, N'Period 6', N'الحصة السادسة', '12:30', '13:15', 0);

INSERT INTO timetable.Timetables (SectionId, TermId, BellScheduleId, VersionNumber, TimetableStatus, EffectiveFrom)
SELECT sec.SectionId, @T1, @Bell, 1, N'Draft', '20260830'
FROM   academic.Sections AS sec JOIN academic.GradeLevels AS gl ON gl.GradeLevelId = sec.GradeLevelId
WHERE  sec.AcademicYearId = @Y2 AND gl.Code IN (N'G02', N'G06', N'G10');

-- Weekly grid (Sun..Thu = ISO 7,1,2,3,4). Grade 6 and Grade 10 share teachers in mirrored slots.
INSERT INTO timetable.TimetableEntries (TimetableId, DayOfWeek, PeriodId, TeachingAssignmentId, RoomId)
SELECT tt.TimetableId, d.IsoDay, p.PeriodId, ta.TeachingAssignmentId, sec.HomeRoomId
FROM   timetable.Timetables AS tt
JOIN   academic.Sections AS sec ON sec.SectionId = tt.SectionId
JOIN   academic.GradeLevels AS gl ON gl.GradeLevelId = sec.GradeLevelId
CROSS JOIN (VALUES (7), (1), (2), (3), (4)) AS d (IsoDay)
JOIN   (VALUES (N'G06', 1, N'MATH'), (N'G06', 2, N'ENG'), (N'G06', 3, N'ARB'), (N'G06', 5, N'SCI'),
               (N'G10', 1, N'ENG'),  (N'G10', 2, N'MATH'), (N'G10', 3, N'SCI'), (N'G10', 5, N'ARB')) AS g (GradeCode, PeriodNumber, SubjectCode)
       ON g.GradeCode = gl.Code
JOIN   timetable.Periods AS p ON p.BellScheduleId = tt.BellScheduleId AND p.PeriodNumber = g.PeriodNumber
JOIN   academic.TeachingAssignments AS ta ON ta.SectionId = sec.SectionId
JOIN   academic.CurriculumSubjects AS cs ON cs.CurriculumSubjectId = ta.CurriculumSubjectId
JOIN   academic.Subjects AS s ON s.SubjectId = cs.SubjectId AND s.SubjectCode = g.SubjectCode
WHERE  tt.TermId = @T1;

-- Grade 2 draft deliberately puts the Mathematics teacher in period 1 (clash with Grade 6).
INSERT INTO timetable.TimetableEntries (TimetableId, DayOfWeek, PeriodId, TeachingAssignmentId, RoomId)
SELECT tt.TimetableId, 7, p.PeriodId, ta.TeachingAssignmentId, sec.HomeRoomId
FROM   timetable.Timetables AS tt
JOIN   academic.Sections AS sec ON sec.SectionId = tt.SectionId
JOIN   academic.GradeLevels AS gl ON gl.GradeLevelId = sec.GradeLevelId AND gl.Code = N'G02'
JOIN   timetable.Periods AS p ON p.BellScheduleId = tt.BellScheduleId AND p.PeriodNumber = 1
JOIN   academic.TeachingAssignments AS ta ON ta.SectionId = sec.SectionId
JOIN   academic.CurriculumSubjects AS cs ON cs.CurriculumSubjectId = ta.CurriculumSubjectId
JOIN   academic.Subjects AS s ON s.SubjectId = cs.SubjectId AND s.SubjectCode = N'MATH'
WHERE  tt.TermId = @T1;

DECLARE @TtG06 INT, @TtG10 INT, @TtG02 INT;
SELECT @TtG06 = tt.TimetableId FROM timetable.Timetables AS tt JOIN academic.Sections AS sec ON sec.SectionId = tt.SectionId
JOIN academic.GradeLevels AS gl ON gl.GradeLevelId = sec.GradeLevelId WHERE tt.TermId = @T1 AND gl.Code = N'G06';
SELECT @TtG10 = tt.TimetableId FROM timetable.Timetables AS tt JOIN academic.Sections AS sec ON sec.SectionId = tt.SectionId
JOIN academic.GradeLevels AS gl ON gl.GradeLevelId = sec.GradeLevelId WHERE tt.TermId = @T1 AND gl.Code = N'G10';
SELECT @TtG02 = tt.TimetableId FROM timetable.Timetables AS tt JOIN academic.Sections AS sec ON sec.SectionId = tt.SectionId
JOIN academic.GradeLevels AS gl ON gl.GradeLevelId = sec.GradeLevelId WHERE tt.TermId = @T1 AND gl.Code = N'G02';

EXEC timetable.usp_PublishTimetable @TimetableId = @TtG06;
EXEC timetable.usp_PublishTimetable @TimetableId = @TtG10;

-- Negative test: the clashing Grade 2 draft must be rejected (error 52004) and stay Draft.
BEGIN TRY
    EXEC timetable.usp_PublishTimetable @TimetableId = @TtG02;
    THROW 59999, N'Expected a timetable clash error but the publish succeeded.', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() <> 52004 THROW;
    PRINT CONCAT(N'Expected rejection (clash detection works): ', ERROR_MESSAGE());
END CATCH;
GO

-- Daily attendance for the current week (15-17 Nov 2026) for every Year 2 section.
DECLARE @Y2 INT = (SELECT AcademicYearId FROM academic.AcademicYears WHERE YearCode = N'2026-2027');
DECLARE @SectionId INT, @Day DATE, @Session BIGINT, @Taker INT;
DECLARE @Entries attendance.AttendanceEntryList;
DECLARE att2_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT sec.SectionId, d.Day, sec.HomeroomTeacherId
    FROM   academic.Sections AS sec
    CROSS JOIN (VALUES (CONVERT(DATE, '20261115')), ('20261116'), ('20261117')) AS d (Day)
    WHERE  sec.AcademicYearId = @Y2
    ORDER BY sec.SectionId, d.Day;
OPEN att2_cursor;
FETCH NEXT FROM att2_cursor INTO @SectionId, @Day, @Taker;
WHILE @@FETCH_STATUS = 0
BEGIN
    DELETE FROM @Entries;
    INSERT INTO @Entries (EnrollmentId, StatusCode, MinutesLate, Remarks)
    SELECT sa.EnrollmentId,
           CASE (sa.EnrollmentId * 5 + DAY(@Day)) % 9 WHEN 0 THEN N'ABSENT' WHEN 1 THEN N'LATE' WHEN 2 THEN N'SICK' ELSE N'PRESENT' END,
           CASE (sa.EnrollmentId * 5 + DAY(@Day)) % 9 WHEN 1 THEN 15 END,
           NULL
    FROM   enrollment.SectionAssignments AS sa
    WHERE  sa.SectionId = @SectionId AND sa.StartDate <= @Day AND (sa.EndDate IS NULL OR sa.EndDate >= @Day);
    IF EXISTS (SELECT 1 FROM @Entries)
        EXEC attendance.usp_RecordSectionAttendance @SectionId = @SectionId, @SessionDate = @Day, @Entries = @Entries,
             @TakenByEmployeeId = @Taker, @AttendanceSessionId = @Session OUTPUT;
    FETCH NEXT FROM att2_cursor INTO @SectionId, @Day, @Taker;
END;
CLOSE att2_cursor; DEALLOCATE att2_cursor;

-- Term 1 quiz and midterm so far.
INSERT INTO assessment.Assessments (TeachingAssignmentId, TermId, AssessmentTypeId, TitleEn, TitleAr, AssessmentDate, MaxScore, IsPublished)
SELECT ta.TeachingAssignmentId, t.TermId, at.AssessmentTypeId,
       CONCAT(s.NameEn, N' - ', at.NameEn, N' (', t.NameEn, N')'), CONCAT(s.NameAr, N' - ', at.NameAr, N' (', t.NameAr, N')'),
       v.AssessDate, v.MaxScore, 1
FROM   academic.TeachingAssignments AS ta
JOIN   academic.Sections AS sec ON sec.SectionId = ta.SectionId
JOIN   academic.CurriculumSubjects AS cs ON cs.CurriculumSubjectId = ta.CurriculumSubjectId
JOIN   academic.Subjects AS s ON s.SubjectId = cs.SubjectId
JOIN   academic.Terms AS t ON t.AcademicYearId = sec.AcademicYearId AND t.TermNumber = 1
CROSS JOIN (VALUES (N'QUIZ', CONVERT(DATE, '20260927'), 20.0), (N'MIDTERM', CONVERT(DATE, '20261101'), 50.0)) AS v (TypeCode, AssessDate, MaxScore)
JOIN   assessment.AssessmentTypes AS at ON at.Code = v.TypeCode
WHERE  sec.AcademicYearId = @Y2;

DECLARE @AssessmentId INT, @AssessDate DATE, @AssessSection INT, @Max DECIMAL(9,3);
DECLARE @Results assessment.ResultEntryList;
DECLARE res2_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT a.AssessmentId, a.AssessmentDate, ta.SectionId, a.MaxScore
    FROM   assessment.Assessments AS a
    JOIN   academic.TeachingAssignments AS ta ON ta.TeachingAssignmentId = a.TeachingAssignmentId
    JOIN   academic.Sections AS sec ON sec.SectionId = ta.SectionId
    WHERE  sec.AcademicYearId = @Y2
    ORDER BY a.AssessmentId;
OPEN res2_cursor;
FETCH NEXT FROM res2_cursor INTO @AssessmentId, @AssessDate, @AssessSection, @Max;
WHILE @@FETCH_STATUS = 0
BEGIN
    DELETE FROM @Results;
    INSERT INTO @Results (EnrollmentId, Score, IsAbsent, IsExempt, Comment)
    SELECT sa.EnrollmentId, CAST(ROUND(@Max * (58 + ABS(CHECKSUM(sa.EnrollmentId * 104729 + @AssessmentId)) % 42) / 100.0, 1) AS DECIMAL(9,3)), 0, 0, NULL
    FROM   enrollment.SectionAssignments AS sa
    WHERE  sa.SectionId = @AssessSection AND sa.StartDate <= @AssessDate AND (sa.EndDate IS NULL OR sa.EndDate >= @AssessDate);
    IF EXISTS (SELECT 1 FROM @Results)
        EXEC assessment.usp_RecordResults @AssessmentId = @AssessmentId, @Results = @Results;
    FETCH NEXT FROM res2_cursor INTO @AssessmentId, @AssessDate, @AssessSection, @Max;
END;
CLOSE res2_cursor; DEALLOCATE res2_cursor;
GO

-- Year 2 invoices (installments 1 and 2), payments, and a cancel-and-reissue.
DECLARE @Y2 INT = (SELECT AcademicYearId FROM academic.AcademicYears WHERE YearCode = N'2026-2027');
DECLARE @EnrollmentId INT, @InstallmentId INT, @InvoiceDate DATE;
DECLARE @Issued TABLE (InvoiceId BIGINT, InvoiceNumber NVARCHAR(30), PayerId INT, TotalAmount DECIMAL(19,4));
DECLARE inv_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT e.EnrollmentId, fi.FeeInstallmentId, CASE fi.InstallmentNumber WHEN 1 THEN CONVERT(DATE, '20260820') ELSE CONVERT(DATE, '20261115') END
    FROM   enrollment.Enrollments AS e
    JOIN   finance.FeeStructures AS fs ON fs.AcademicYearId = e.AcademicYearId AND fs.BranchId = e.BranchId AND fs.GradeLevelId = e.GradeLevelId AND fs.ProgramId = e.ProgramId
    JOIN   finance.FeeInstallments AS fi ON fi.FeeStructureId = fs.FeeStructureId
    WHERE  e.AcademicYearId = @Y2 AND fi.InstallmentNumber IN (1, 2) AND e.EnrollmentStatus = N'Enrolled'
    ORDER BY fi.InstallmentNumber, e.EnrollmentId;
OPEN inv_cursor;
FETCH NEXT FROM inv_cursor INTO @EnrollmentId, @InstallmentId, @InvoiceDate;
WHILE @@FETCH_STATUS = 0
BEGIN
    INSERT INTO @Issued EXEC finance.usp_IssueInvoice @EnrollmentId = @EnrollmentId, @FeeInstallmentId = @InstallmentId, @InvoiceDate = @InvoiceDate;
    FETCH NEXT FROM inv_cursor INTO @EnrollmentId, @InstallmentId, @InvoiceDate;
END;
CLOSE inv_cursor; DEALLOCATE inv_cursor;

-- Noor's installment-2 invoice was issued with the wrong date: cancel (unpaid) and reissue.
DECLARE @NoorEnr INT = (SELECT EnrollmentId FROM #E WHERE Code = N'S9' AND YearCode = N'2026-2027');
DECLARE @BadInv BIGINT, @BadInst INT;
SELECT @BadInv = i.InvoiceId, @BadInst = i.FeeInstallmentId
FROM   finance.Invoices AS i JOIN finance.FeeInstallments AS fi ON fi.FeeInstallmentId = i.FeeInstallmentId
WHERE  i.EnrollmentId = @NoorEnr AND fi.InstallmentNumber = 2;
EXEC finance.usp_CancelInvoice @InvoiceId = @BadInv, @Reason = N'Issued with wrong invoice date / صدرت بتاريخ خاطئ';
INSERT INTO @Issued EXEC finance.usp_IssueInvoice @EnrollmentId = @NoorEnr, @FeeInstallmentId = @BadInst, @InvoiceDate = '20261116';

-- Installment 1 payments: most payers pay in full; the sponsor pays by bank transfer with an
-- explicit allocation; S7's guardian has paid nothing yet (overdue).
DECLARE @PayerId INT, @Due DECIMAL(19,4), @Ref NVARCHAR(100), @PaymentId BIGINT, @n INT = 0;
DECLARE @AmmBranch INT = (SELECT BranchId FROM organization.Branches WHERE BranchCode = N'AMM');
DECLARE @NoAlloc finance.AllocationList, @Explicit finance.AllocationList;
DECLARE pay2_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT ib.PayerId, SUM(ib.BalanceAmount)
    FROM   finance.vw_InvoiceBalances AS ib
    JOIN   enrollment.Enrollments AS e ON e.EnrollmentId = ib.EnrollmentId
    JOIN   finance.Invoices AS inv ON inv.InvoiceId = ib.InvoiceId
    JOIN   finance.FeeInstallments AS fi ON fi.FeeInstallmentId = inv.FeeInstallmentId
    JOIN   finance.Payers AS py ON py.PayerId = ib.PayerId
    LEFT JOIN #P AS p ON p.PersonId = py.GuardianId
    WHERE  e.AcademicYearId = @Y2 AND fi.InstallmentNumber = 1 AND ib.InvoiceStatus = N'Issued'
      AND  py.PayerType = N'Guardian' AND ISNULL(p.Code, N'') <> N'G6'
    GROUP BY ib.PayerId ORDER BY ib.PayerId;
OPEN pay2_cursor;
FETCH NEXT FROM pay2_cursor INTO @PayerId, @Due;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @n += 1;
    SET @Ref = CONCAT(N'EFW-2627-', RIGHT(N'00000' + CAST(@PayerId AS NVARCHAR(10)), 5));
    EXEC finance.usp_RecordPayment @PayerId = @PayerId, @BranchId = @AmmBranch, @PaymentMethodCode = N'EFAWATEER', @PaymentDate = '20260831',
         @Amount = @Due, @Allocations = @NoAlloc, @ReferenceNumber = @Ref, @PaymentId = @PaymentId OUTPUT;
    FETCH NEXT FROM pay2_cursor INTO @PayerId, @Due;
END;
CLOSE pay2_cursor; DEALLOCATE pay2_cursor;

DECLARE @Sponsor INT = (SELECT py.PayerId FROM finance.Payers AS py JOIN finance.Sponsors AS s ON s.SponsorId = py.SponsorId WHERE s.SponsorCode = N'WAHA');
INSERT INTO @Explicit (InvoiceId, Amount)
SELECT i.InvoiceId, i.TotalAmount FROM finance.Invoices AS i
JOIN finance.FeeInstallments AS fi ON fi.FeeInstallmentId = i.FeeInstallmentId
JOIN enrollment.Enrollments AS e ON e.EnrollmentId = i.EnrollmentId
WHERE i.PayerId = @Sponsor AND e.AcademicYearId = @Y2 AND fi.InstallmentNumber = 1;
DECLARE @SponsorAmount DECIMAL(19,4) = (SELECT SUM(Amount) FROM @Explicit) + 250;   -- 250 JOD paid in advance (unallocated)
EXEC finance.usp_RecordPayment @PayerId = @Sponsor, @BranchId = @AmmBranch, @PaymentMethodCode = N'TRANSFER', @PaymentDate = '20260905',
     @Amount = @SponsorAmount, @Allocations = @Explicit, @ReferenceNumber = N'TRF-ARAB-BANK-778812', @Notes = N'Employee education fund - semester 1',
     @PaymentId = @PaymentId OUTPUT;
GO

SET NOEXEC OFF;
GO

/* --------------------------------------------------------------- Summary */
SELECT N'Persons' AS Entity, COUNT(*) AS Rows FROM people.Persons
UNION ALL SELECT N'Students', COUNT(*) FROM people.Students
UNION ALL SELECT N'Guardians', COUNT(*) FROM people.Guardians
UNION ALL SELECT N'Employees', COUNT(*) FROM people.Employees
UNION ALL SELECT N'Teachers', COUNT(*) FROM people.Teachers
UNION ALL SELECT N'Enrollments', COUNT(*) FROM enrollment.Enrollments
UNION ALL SELECT N'SectionAssignments', COUNT(*) FROM enrollment.SectionAssignments
UNION ALL SELECT N'AttendanceRecords', COUNT(*) FROM attendance.AttendanceRecords
UNION ALL SELECT N'AssessmentResults', COUNT(*) FROM assessment.AssessmentResults
UNION ALL SELECT N'ReportCards', COUNT(*) FROM assessment.ReportCards
UNION ALL SELECT N'Invoices', COUNT(*) FROM finance.Invoices
UNION ALL SELECT N'Payments', COUNT(*) FROM finance.Payments
UNION ALL SELECT N'AuditEvents', COUNT(*) FROM audit.AuditEvents;
GO

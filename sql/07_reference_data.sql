/* =============================================================================
   07_reference_data.sql
   Purpose     : Lookup / reference values (bilingual Arabic + English).
   Dependencies: 06_indexes.sql
   Run order   : 7 of 12
   Idempotent  : Yes. Each lookup is loaded with MERGE keyed on its business
                 code; rows are inserted when missing and updated only when a
                 value actually changed (EXCEPT comparison). Nothing is deleted.
   Encoding    : UTF-8. Arabic literals are N'' strings.
   ============================================================================= */
USE [$(DatabaseName)];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/* ---------------------------------------------------------------- Currencies */
MERGE finance.Currencies AS t
USING (VALUES
    (N'JOD', N'Jordanian Dinar',   N'دينار أردني',     3),
    (N'USD', N'US Dollar',         N'دولار أمريكي',    2),
    (N'EUR', N'Euro',              N'يورو',            2),
    (N'SAR', N'Saudi Riyal',       N'ريال سعودي',      2),
    (N'AED', N'UAE Dirham',        N'درهم إماراتي',    2)
) AS s (CurrencyCode, NameEn, NameAr, MinorUnits)
ON t.CurrencyCode = s.CurrencyCode
WHEN MATCHED AND EXISTS (SELECT s.NameEn, s.NameAr, s.MinorUnits EXCEPT SELECT t.NameEn, t.NameAr, t.MinorUnits)
    THEN UPDATE SET NameEn = s.NameEn, NameAr = s.NameAr, MinorUnits = s.MinorUnits, UpdatedAt = SYSUTCDATETIME()
WHEN NOT MATCHED BY TARGET
    THEN INSERT (CurrencyCode, NameEn, NameAr, MinorUnits, IsActive) VALUES (s.CurrencyCode, s.NameEn, s.NameAr, s.MinorUnits, 1);
GO

/* ----------------------------------------------------------------- Countries */
MERGE organization.Countries AS t
USING (VALUES
    (N'JO', N'JOR', N'Jordan',               N'الأردن',               N'Jordanian',   N'أردني'),
    (N'PS', N'PSE', N'Palestine',            N'فلسطين',               N'Palestinian', N'فلسطيني'),
    (N'SA', N'SAU', N'Saudi Arabia',         N'المملكة العربية السعودية', N'Saudi',   N'سعودي'),
    (N'AE', N'ARE', N'United Arab Emirates', N'الإمارات العربية المتحدة', N'Emirati', N'إماراتي'),
    (N'IQ', N'IRQ', N'Iraq',                 N'العراق',               N'Iraqi',       N'عراقي'),
    (N'SY', N'SYR', N'Syria',                N'سوريا',                N'Syrian',      N'سوري'),
    (N'LB', N'LBN', N'Lebanon',              N'لبنان',                N'Lebanese',    N'لبناني'),
    (N'EG', N'EGY', N'Egypt',                N'مصر',                  N'Egyptian',    N'مصري'),
    (N'KW', N'KWT', N'Kuwait',               N'الكويت',               N'Kuwaiti',     N'كويتي'),
    (N'QA', N'QAT', N'Qatar',                N'قطر',                  N'Qatari',      N'قطري'),
    (N'BH', N'BHR', N'Bahrain',              N'البحرين',              N'Bahraini',    N'بحريني'),
    (N'OM', N'OMN', N'Oman',                 N'عُمان',                N'Omani',       N'عُماني'),
    (N'US', N'USA', N'United States',        N'الولايات المتحدة',     N'American',    N'أمريكي'),
    (N'GB', N'GBR', N'United Kingdom',       N'المملكة المتحدة',      N'British',     N'بريطاني')
) AS s (IsoAlpha2, IsoAlpha3, NameEn, NameAr, NationalityEn, NationalityAr)
ON t.IsoAlpha2 = s.IsoAlpha2
WHEN MATCHED AND EXISTS (SELECT s.IsoAlpha3, s.NameEn, s.NameAr, s.NationalityEn, s.NationalityAr EXCEPT SELECT t.IsoAlpha3, t.NameEn, t.NameAr, t.NationalityEn, t.NationalityAr)
    THEN UPDATE SET IsoAlpha3 = s.IsoAlpha3, NameEn = s.NameEn, NameAr = s.NameAr, NationalityEn = s.NationalityEn, NationalityAr = s.NationalityAr, UpdatedAt = SYSUTCDATETIME()
WHEN NOT MATCHED BY TARGET
    THEN INSERT (IsoAlpha2, IsoAlpha3, NameEn, NameAr, NationalityEn, NationalityAr, IsActive) VALUES (s.IsoAlpha2, s.IsoAlpha3, s.NameEn, s.NameAr, s.NationalityEn, s.NationalityAr, 1);
GO

/* ----------------------------------------------------------------- RoomTypes */
MERGE organization.RoomTypes AS t
USING (VALUES
    (N'CLASS',   N'Classroom',        N'غرفة صفية'),
    (N'LAB',     N'Science Lab',      N'مختبر علوم'),
    (N'COMPLAB', N'Computer Lab',     N'مختبر حاسوب'),
    (N'GYM',     N'Gymnasium',        N'صالة رياضية'),
    (N'HALL',    N'Multipurpose Hall',N'قاعة متعددة الأغراض'),
    (N'LIBRARY', N'Library',          N'مكتبة'),
    (N'ART',     N'Art Room',         N'غرفة فنون'),
    (N'OFFICE',  N'Office',           N'مكتب')
) AS s (Code, NameEn, NameAr)
ON t.Code = s.Code
WHEN MATCHED AND EXISTS (SELECT s.NameEn, s.NameAr EXCEPT SELECT t.NameEn, t.NameAr)
    THEN UPDATE SET NameEn = s.NameEn, NameAr = s.NameAr, UpdatedAt = SYSUTCDATETIME()
WHEN NOT MATCHED BY TARGET
    THEN INSERT (Code, NameEn, NameAr, IsActive) VALUES (s.Code, s.NameEn, s.NameAr, 1);
GO

/* ----------------------------------------------------- IdentityDocumentTypes */
MERGE people.IdentityDocumentTypes AS t
USING (VALUES
    (N'NATIONAL_NO', N'National Number',   N'الرقم الوطني'),
    (N'PASSPORT',    N'Passport',          N'جواز سفر'),
    (N'RESIDENCY',   N'Residency Permit',  N'إقامة'),
    (N'BIRTH_CERT',  N'Birth Certificate', N'شهادة ميلاد')
) AS s (Code, NameEn, NameAr)
ON t.Code = s.Code
WHEN MATCHED AND EXISTS (SELECT s.NameEn, s.NameAr EXCEPT SELECT t.NameEn, t.NameAr)
    THEN UPDATE SET NameEn = s.NameEn, NameAr = s.NameAr, UpdatedAt = SYSUTCDATETIME()
WHEN NOT MATCHED BY TARGET
    THEN INSERT (Code, NameEn, NameAr, IsActive) VALUES (s.Code, s.NameEn, s.NameAr, 1);
GO

/* --------------------------------------------------------- RelationshipTypes */
MERGE people.RelationshipTypes AS t
USING (VALUES
    (N'FATHER',      N'Father',         N'الأب'),
    (N'MOTHER',      N'Mother',         N'الأم'),
    (N'BROTHER',     N'Brother',        N'الأخ'),
    (N'SISTER',      N'Sister',         N'الأخت'),
    (N'GRANDFATHER', N'Grandfather',    N'الجد'),
    (N'GRANDMOTHER', N'Grandmother',    N'الجدة'),
    (N'UNCLE',       N'Uncle',          N'العم / الخال'),
    (N'AUNT',        N'Aunt',           N'العمة / الخالة'),
    (N'LEGAL',       N'Legal Guardian', N'ولي أمر قانوني')
) AS s (Code, NameEn, NameAr)
ON t.Code = s.Code
WHEN MATCHED AND EXISTS (SELECT s.NameEn, s.NameAr EXCEPT SELECT t.NameEn, t.NameAr)
    THEN UPDATE SET NameEn = s.NameEn, NameAr = s.NameAr, UpdatedAt = SYSUTCDATETIME()
WHEN NOT MATCHED BY TARGET
    THEN INSERT (Code, NameEn, NameAr, IsActive) VALUES (s.Code, s.NameEn, s.NameAr, 1);
GO

/* --------------------------------------------------------------- GradeLevels */
MERGE academic.GradeLevels AS t
USING (VALUES
    (N'KG1', N'Kindergarten 1', N'الروضة الأولى',  N'KG',        1),
    (N'KG2', N'Kindergarten 2', N'الروضة الثانية', N'KG',        2),
    (N'G01', N'Grade 1',        N'الصف الأول',     N'Primary',   3),
    (N'G02', N'Grade 2',        N'الصف الثاني',    N'Primary',   4),
    (N'G03', N'Grade 3',        N'الصف الثالث',    N'Primary',   5),
    (N'G04', N'Grade 4',        N'الصف الرابع',    N'Primary',   6),
    (N'G05', N'Grade 5',        N'الصف الخامس',    N'Primary',   7),
    (N'G06', N'Grade 6',        N'الصف السادس',    N'Primary',   8),
    (N'G07', N'Grade 7',        N'الصف السابع',    N'Middle',    9),
    (N'G08', N'Grade 8',        N'الصف الثامن',    N'Middle',   10),
    (N'G09', N'Grade 9',        N'الصف التاسع',    N'Middle',   11),
    (N'G10', N'Grade 10',       N'الصف العاشر',    N'Middle',   12),
    (N'G11', N'Grade 11',       N'الصف الحادي عشر', N'Secondary', 13),
    (N'G12', N'Grade 12',       N'الصف الثاني عشر', N'Secondary', 14)
) AS s (Code, NameEn, NameAr, Stage, SortOrder)
ON t.Code = s.Code
WHEN MATCHED AND EXISTS (SELECT s.NameEn, s.NameAr, s.Stage, s.SortOrder EXCEPT SELECT t.NameEn, t.NameAr, t.Stage, t.SortOrder)
    THEN UPDATE SET NameEn = s.NameEn, NameAr = s.NameAr, Stage = s.Stage, SortOrder = s.SortOrder, UpdatedAt = SYSUTCDATETIME()
WHEN NOT MATCHED BY TARGET
    THEN INSERT (Code, NameEn, NameAr, Stage, SortOrder, IsActive) VALUES (s.Code, s.NameEn, s.NameAr, s.Stage, s.SortOrder, 1);
GO
-- Promotion path: each grade points to the next one by SortOrder (G12 has none).
UPDATE g
SET    NextGradeLevelId = n.GradeLevelId,
       UpdatedAt        = SYSUTCDATETIME()
FROM   academic.GradeLevels AS g
JOIN   academic.GradeLevels AS n ON n.SortOrder = g.SortOrder + 1
WHERE  g.NextGradeLevelId IS NULL OR g.NextGradeLevelId <> n.GradeLevelId;
GO

/* ------------------------------------------------------------------ Programs */
MERGE academic.Programs AS t
USING (VALUES
    (N'NAT',     N'Jordanian National Curriculum',      N'المنهاج الوطني الأردني',           N'Ministry of Education curriculum, KG-Grade 10'),
    (N'NAT-SCI', N'National - Scientific Stream',       N'المنهاج الوطني - الفرع العلمي',     N'Grades 11-12 (Tawjihi), scientific stream'),
    (N'NAT-LIT', N'National - Literary Stream',         N'المنهاج الوطني - الفرع الأدبي',     N'Grades 11-12 (Tawjihi), literary stream'),
    (N'INTL',    N'International Program (IGCSE)',      N'البرنامج الدولي',                   N'Cambridge IGCSE / A-Level track')
) AS s (Code, NameEn, NameAr, Description)
ON t.Code = s.Code
WHEN MATCHED AND EXISTS (SELECT s.NameEn, s.NameAr, s.Description EXCEPT SELECT t.NameEn, t.NameAr, t.Description)
    THEN UPDATE SET NameEn = s.NameEn, NameAr = s.NameAr, Description = s.Description, UpdatedAt = SYSUTCDATETIME()
WHEN NOT MATCHED BY TARGET
    THEN INSERT (Code, NameEn, NameAr, Description, IsActive) VALUES (s.Code, s.NameEn, s.NameAr, s.Description, 1);
GO

/* -------------------------------------------------------- AttendanceStatuses */
MERGE attendance.AttendanceStatuses AS t
USING (VALUES
    (N'PRESENT',     N'Present',     N'حاضر',          1, 0, 1),
    (N'LATE',        N'Late',        N'متأخر',         1, 0, 2),
    (N'EARLY_LEAVE', N'Early Leave', N'مغادرة مبكرة',  1, 0, 3),
    (N'ABSENT',      N'Absent',      N'غائب',          0, 0, 4),
    (N'EXCUSED',     N'Excused',     N'غياب بعذر',     0, 1, 5),
    (N'SICK',        N'Sick Leave',  N'إجازة مرضية',   0, 1, 6)
) AS s (Code, NameEn, NameAr, CountsAsPresent, IsExcused, SortOrder)
ON t.Code = s.Code
WHEN MATCHED AND EXISTS (SELECT s.NameEn, s.NameAr, s.CountsAsPresent, s.IsExcused, s.SortOrder EXCEPT SELECT t.NameEn, t.NameAr, t.CountsAsPresent, t.IsExcused, t.SortOrder)
    THEN UPDATE SET NameEn = s.NameEn, NameAr = s.NameAr, CountsAsPresent = s.CountsAsPresent, IsExcused = s.IsExcused, SortOrder = s.SortOrder, UpdatedAt = SYSUTCDATETIME()
WHEN NOT MATCHED BY TARGET
    THEN INSERT (Code, NameEn, NameAr, CountsAsPresent, IsExcused, SortOrder, IsActive) VALUES (s.Code, s.NameEn, s.NameAr, s.CountsAsPresent, s.IsExcused, s.SortOrder, 1);
GO

/* ----------------------------------------------------------- AssessmentTypes */
MERGE assessment.AssessmentTypes AS t
USING (VALUES
    (N'QUIZ',          N'Quiz',          N'اختبار قصير'),
    (N'HOMEWORK',      N'Homework',      N'واجب منزلي'),
    (N'PROJECT',       N'Project',       N'مشروع'),
    (N'PARTICIPATION', N'Participation', N'مشاركة'),
    (N'MIDTERM',       N'Midterm Exam',  N'امتحان منتصف الفصل'),
    (N'FINAL',         N'Final Exam',    N'الامتحان النهائي')
) AS s (Code, NameEn, NameAr)
ON t.Code = s.Code
WHEN MATCHED AND EXISTS (SELECT s.NameEn, s.NameAr EXCEPT SELECT t.NameEn, t.NameAr)
    THEN UPDATE SET NameEn = s.NameEn, NameAr = s.NameAr, UpdatedAt = SYSUTCDATETIME()
WHEN NOT MATCHED BY TARGET
    THEN INSERT (Code, NameEn, NameAr, IsActive) VALUES (s.Code, s.NameEn, s.NameAr, 1);
GO

/* ------------------------------------------------ GradingScales and bands */
MERGE assessment.GradingScales AS t
USING (VALUES
    (N'STD100', N'Standard Percentage Scale', N'سلم العلامات المئوي', 50.0000),
    (N'KG',     N'Kindergarten Descriptive',  N'سلم الروضة الوصفي',   50.0000)
) AS s (Code, NameEn, NameAr, PassPercent)
ON t.Code = s.Code
WHEN MATCHED AND EXISTS (SELECT s.NameEn, s.NameAr, s.PassPercent EXCEPT SELECT t.NameEn, t.NameAr, t.PassPercent)
    THEN UPDATE SET NameEn = s.NameEn, NameAr = s.NameAr, PassPercent = s.PassPercent, UpdatedAt = SYSUTCDATETIME()
WHEN NOT MATCHED BY TARGET
    THEN INSERT (Code, NameEn, NameAr, PassPercent, IsActive) VALUES (s.Code, s.NameEn, s.NameAr, s.PassPercent, 1);
GO
MERGE assessment.GradingScaleBands AS t
USING (
    SELECT gs.GradingScaleId, v.MinPercent, v.MaxPercent, v.LetterGrade, v.DescriptorEn, v.DescriptorAr, v.GradePoint
    FROM (VALUES
        (N'STD100', 90.0000, 100.0000, N'A', N'Excellent',      N'ممتاز',       4.00),
        (N'STD100', 80.0000,  89.9999, N'B', N'Very Good',      N'جيد جداً',    3.00),
        (N'STD100', 70.0000,  79.9999, N'C', N'Good',           N'جيد',         2.00),
        (N'STD100', 60.0000,  69.9999, N'D', N'Satisfactory',   N'مقبول',       1.00),
        (N'STD100', 50.0000,  59.9999, N'E', N'Pass',           N'ناجح',        0.50),
        (N'STD100',  0.0000,  49.9999, N'F', N'Fail',           N'راسب',        0.00),
        (N'KG',     85.0000, 100.0000, N'EX', N'Exceeds Expectations', N'يفوق التوقعات', NULL),
        (N'KG',     65.0000,  84.9999, N'ME', N'Meets Expectations',   N'يحقق التوقعات', NULL),
        (N'KG',     50.0000,  64.9999, N'AP', N'Approaching',          N'يقترب من التوقعات', NULL),
        (N'KG',      0.0000,  49.9999, N'NS', N'Needs Support',        N'بحاجة إلى دعم', NULL)
    ) AS v (ScaleCode, MinPercent, MaxPercent, LetterGrade, DescriptorEn, DescriptorAr, GradePoint)
    JOIN assessment.GradingScales AS gs ON gs.Code = v.ScaleCode
) AS s
ON t.GradingScaleId = s.GradingScaleId AND t.LetterGrade = s.LetterGrade
WHEN MATCHED AND EXISTS (SELECT s.MinPercent, s.MaxPercent, s.DescriptorEn, s.DescriptorAr, s.GradePoint EXCEPT SELECT t.MinPercent, t.MaxPercent, t.DescriptorEn, t.DescriptorAr, t.GradePoint)
    THEN UPDATE SET MinPercent = s.MinPercent, MaxPercent = s.MaxPercent, DescriptorEn = s.DescriptorEn, DescriptorAr = s.DescriptorAr, GradePoint = s.GradePoint, UpdatedAt = SYSUTCDATETIME()
WHEN NOT MATCHED BY TARGET
    THEN INSERT (GradingScaleId, MinPercent, MaxPercent, LetterGrade, DescriptorEn, DescriptorAr, GradePoint) VALUES (s.GradingScaleId, s.MinPercent, s.MaxPercent, s.LetterGrade, s.DescriptorEn, s.DescriptorAr, s.GradePoint);
GO

/* ------------------------------------------------------------------ FeeTypes */
-- Tax rates are an ASSUMPTION (PROJECT_PLAN.md A15): tuition exempt; uniforms taxable at 16%.
MERGE finance.FeeTypes AS t
USING (VALUES
    (N'TUITION',      N'Tuition Fee',       N'الرسوم الدراسية',  0,  0.0000),
    (N'REGISTRATION', N'Registration Fee',  N'رسوم التسجيل',     0,  0.0000),
    (N'BOOKS',        N'Books',             N'الكتب',            0,  0.0000),
    (N'UNIFORM',      N'Uniform',           N'الزي المدرسي',     1, 16.0000),
    (N'ACTIVITIES',   N'Activities Fee',    N'رسوم الأنشطة',     0,  0.0000),
    (N'TRANSPORT',    N'Transport Fee',     N'رسوم المواصلات',   0,  0.0000),
    (N'EXAM',         N'Exam Fee',          N'رسوم الامتحانات',  0,  0.0000)
) AS s (Code, NameEn, NameAr, IsTaxable, TaxPercent)
ON t.Code = s.Code
WHEN MATCHED AND EXISTS (SELECT s.NameEn, s.NameAr, s.IsTaxable, s.TaxPercent EXCEPT SELECT t.NameEn, t.NameAr, t.IsTaxable, t.TaxPercent)
    THEN UPDATE SET NameEn = s.NameEn, NameAr = s.NameAr, IsTaxable = s.IsTaxable, TaxPercent = s.TaxPercent, UpdatedAt = SYSUTCDATETIME()
WHEN NOT MATCHED BY TARGET
    THEN INSERT (Code, NameEn, NameAr, IsTaxable, TaxPercent, IsActive) VALUES (s.Code, s.NameEn, s.NameAr, s.IsTaxable, s.TaxPercent, 1);
GO

/* ------------------------------------------------------------- DiscountTypes */
MERGE finance.DiscountTypes AS t
USING (VALUES
    (N'SIBLING',  N'Sibling Discount',       N'خصم الإخوة',        10.0000),
    (N'STAFF',    N'Staff Child Discount',   N'خصم أبناء الموظفين', 50.0000),
    (N'MERIT',    N'Merit Scholarship',      N'منحة تفوق',          25.0000),
    (N'EARLYPAY', N'Early Payment Discount', N'خصم الدفع المبكر',    5.0000),
    (N'FINAID',   N'Financial Aid',          N'مساعدة مالية',        NULL)
) AS s (Code, NameEn, NameAr, DefaultPercent)
ON t.Code = s.Code
WHEN MATCHED AND EXISTS (SELECT s.NameEn, s.NameAr, s.DefaultPercent EXCEPT SELECT t.NameEn, t.NameAr, t.DefaultPercent)
    THEN UPDATE SET NameEn = s.NameEn, NameAr = s.NameAr, DefaultPercent = s.DefaultPercent, UpdatedAt = SYSUTCDATETIME()
WHEN NOT MATCHED BY TARGET
    THEN INSERT (Code, NameEn, NameAr, DefaultPercent, IsActive) VALUES (s.Code, s.NameEn, s.NameAr, s.DefaultPercent, 1);
GO

/* ------------------------------------------------------------ PaymentMethods */
MERGE finance.PaymentMethods AS t
USING (VALUES
    (N'CASH',       N'Cash',            N'نقداً',          0),
    (N'CHEQUE',     N'Cheque',          N'شيك',            1),
    (N'TRANSFER',   N'Bank Transfer',   N'حوالة بنكية',    1),
    (N'CARD',       N'Card',            N'بطاقة',          1),
    (N'EFAWATEER',  N'eFAWATEERcom',    N'إي فواتيركم',    1)
) AS s (Code, NameEn, NameAr, RequiresReference)
ON t.Code = s.Code
WHEN MATCHED AND EXISTS (SELECT s.NameEn, s.NameAr, s.RequiresReference EXCEPT SELECT t.NameEn, t.NameAr, t.RequiresReference)
    THEN UPDATE SET NameEn = s.NameEn, NameAr = s.NameAr, RequiresReference = s.RequiresReference, UpdatedAt = SYSUTCDATETIME()
WHEN NOT MATCHED BY TARGET
    THEN INSERT (Code, NameEn, NameAr, RequiresReference, IsActive) VALUES (s.Code, s.NameEn, s.NameAr, s.RequiresReference, 1);
GO

/* ---------------------------------------------------- iam: Roles, Permissions */
MERGE iam.Roles AS t
USING (VALUES
    (N'SYS_ADMIN',  N'System Administrator', N'مدير النظام',   N'Full access to all modules'),
    (N'PRINCIPAL',  N'Principal',            N'مدير المدرسة',  N'Read access everywhere; publishes report cards and timetables'),
    (N'REGISTRAR',  N'Registrar',            N'المسجل',        N'Admissions, enrollment and student records'),
    (N'TEACHER',    N'Teacher',              N'معلم',          N'Attendance and assessment for assigned sections'),
    (N'ACCOUNTANT', N'Accountant',           N'محاسب',         N'Fees, invoices, payments'),
    (N'GUARDIAN',   N'Guardian',             N'ولي أمر',       N'Portal access to own children'),
    (N'STUDENT',    N'Student',              N'طالب',          N'Portal access to own records')
) AS s (RoleCode, NameEn, NameAr, Description)
ON t.RoleCode = s.RoleCode
WHEN MATCHED AND EXISTS (SELECT s.NameEn, s.NameAr, s.Description EXCEPT SELECT t.NameEn, t.NameAr, t.Description)
    THEN UPDATE SET NameEn = s.NameEn, NameAr = s.NameAr, Description = s.Description, UpdatedAt = SYSUTCDATETIME()
WHEN NOT MATCHED BY TARGET
    THEN INSERT (RoleCode, NameEn, NameAr, Description, IsSystem) VALUES (s.RoleCode, s.NameEn, s.NameAr, s.Description, 1);
GO
MERGE iam.Permissions AS t
USING (VALUES
    (N'organization.manage',            N'organization', N'Manage schools, branches, rooms, departments'),
    (N'iam.manage',                     N'iam',          N'Manage users, roles and permissions'),
    (N'people.read',                    N'people',       N'View person records'),
    (N'people.manage',                  N'people',       N'Create and edit person records'),
    (N'enrollment.application.manage',  N'enrollment',   N'Manage admission applications'),
    (N'enrollment.enroll',              N'enrollment',   N'Enroll, withdraw and promote students'),
    (N'enrollment.section.assign',      N'enrollment',   N'Assign or transfer students between sections'),
    (N'timetable.manage',               N'timetable',    N'Edit draft timetables'),
    (N'timetable.publish',              N'timetable',    N'Publish timetables'),
    (N'attendance.record',              N'attendance',   N'Record attendance'),
    (N'attendance.read',                N'attendance',   N'View attendance'),
    (N'assessment.results.record',      N'assessment',   N'Record assessment results'),
    (N'assessment.reportcard.generate', N'assessment',   N'Generate draft report cards'),
    (N'assessment.reportcard.publish',  N'assessment',   N'Publish report cards'),
    (N'finance.feestructure.manage',    N'finance',      N'Manage fee structures and discounts'),
    (N'finance.invoice.issue',          N'finance',      N'Issue invoices'),
    (N'finance.invoice.cancel',         N'finance',      N'Cancel unpaid invoices'),
    (N'finance.creditnote.issue',       N'finance',      N'Issue credit notes'),
    (N'finance.payment.record',         N'finance',      N'Record payments'),
    (N'finance.read',                   N'finance',      N'View financial records'),
    (N'audit.read',                     N'audit',        N'View audit trail')
) AS s (PermissionCode, ModuleName, Description)
ON t.PermissionCode = s.PermissionCode
WHEN MATCHED AND EXISTS (SELECT s.ModuleName, s.Description EXCEPT SELECT t.ModuleName, t.Description)
    THEN UPDATE SET ModuleName = s.ModuleName, Description = s.Description, UpdatedAt = SYSUTCDATETIME()
WHEN NOT MATCHED BY TARGET
    THEN INSERT (PermissionCode, ModuleName, Description) VALUES (s.PermissionCode, s.ModuleName, s.Description);
GO
-- Role -> permission matrix (insert-only; never removes grants made later by admins).
INSERT INTO iam.RolePermissions (RoleId, PermissionId)
SELECT r.RoleId, p.PermissionId
FROM (VALUES
    (N'SYS_ADMIN', N'%'),
    (N'PRINCIPAL', N'%.read'), (N'PRINCIPAL', N'assessment.reportcard.publish'), (N'PRINCIPAL', N'timetable.publish'),
    (N'REGISTRAR', N'people.%'), (N'REGISTRAR', N'enrollment.%'), (N'REGISTRAR', N'attendance.read'),
    (N'TEACHER', N'people.read'), (N'TEACHER', N'attendance.%'), (N'TEACHER', N'assessment.results.record'), (N'TEACHER', N'assessment.reportcard.generate'),
    (N'ACCOUNTANT', N'people.read'), (N'ACCOUNTANT', N'finance.%')
) AS m (RoleCode, PermissionPattern)
JOIN iam.Roles       AS r ON r.RoleCode = m.RoleCode
JOIN iam.Permissions AS p ON p.PermissionCode LIKE m.PermissionPattern
WHERE NOT EXISTS (SELECT 1 FROM iam.RolePermissions AS rp WHERE rp.RoleId = r.RoleId AND rp.PermissionId = p.PermissionId)
GROUP BY r.RoleId, p.PermissionId;
GO

SELECT N'Currencies' AS LookupTable, COUNT(*) AS RowsLoaded FROM finance.Currencies
UNION ALL SELECT N'Countries', COUNT(*) FROM organization.Countries
UNION ALL SELECT N'RoomTypes', COUNT(*) FROM organization.RoomTypes
UNION ALL SELECT N'IdentityDocumentTypes', COUNT(*) FROM people.IdentityDocumentTypes
UNION ALL SELECT N'RelationshipTypes', COUNT(*) FROM people.RelationshipTypes
UNION ALL SELECT N'GradeLevels', COUNT(*) FROM academic.GradeLevels
UNION ALL SELECT N'Programs', COUNT(*) FROM academic.Programs
UNION ALL SELECT N'AttendanceStatuses', COUNT(*) FROM attendance.AttendanceStatuses
UNION ALL SELECT N'AssessmentTypes', COUNT(*) FROM assessment.AssessmentTypes
UNION ALL SELECT N'GradingScaleBands', COUNT(*) FROM assessment.GradingScaleBands
UNION ALL SELECT N'FeeTypes', COUNT(*) FROM finance.FeeTypes
UNION ALL SELECT N'DiscountTypes', COUNT(*) FROM finance.DiscountTypes
UNION ALL SELECT N'PaymentMethods', COUNT(*) FROM finance.PaymentMethods
UNION ALL SELECT N'Roles', COUNT(*) FROM iam.Roles
UNION ALL SELECT N'Permissions', COUNT(*) FROM iam.Permissions
UNION ALL SELECT N'RolePermissions', COUNT(*) FROM iam.RolePermissions;
GO

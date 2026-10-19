/*
  SENADA - Live Attendance dan radius kantor per perusahaan

  Jalankan setelah 013_scope_calendar_by_company.sql.

  Hasil:
  - lokasi PT A tidak dapat dipakai user PT B;
  - daftar lokasi hanya mengembalikan kantor perusahaan user login;
  - verifikasi wajah memilih kantor terdekat hanya dari perusahaan user;
  - kebijakan LIBUR/KERJA pada kalender juga dibaca per perusahaan.
*/

USE [ABSENSI];
GO
SET XACT_ABORT ON;
GO

/* 1. Tambahkan tenant pada lokasi kantor. */
IF COL_LENGTH('dbo.udt_office_locations', 'company_id') IS NULL
    ALTER TABLE dbo.udt_office_locations ADD company_id INT NULL;
GO

DECLARE @LegacyCompanyId INT;
SELECT TOP (1) @LegacyCompanyId = ci.company_id
FROM dbo.udt_company_info_user ci
INNER JOIN dbo.udt_users u ON u.userid = ci.userid
WHERE ci.company_id IS NOT NULL
  AND u.active = 1
  AND ISNULL(u.deleted, 0) = 0
GROUP BY ci.company_id
ORDER BY COUNT(*) DESC, ci.company_id;

IF @LegacyCompanyId IS NULL
    THROW 51400, 'Perusahaan utama untuk migrasi lokasi tidak ditemukan.', 1;

/* Lokasi lama dianggap milik perusahaan utama; tidak disalin ke PT baru. */
UPDATE dbo.udt_office_locations
SET company_id = @LegacyCompanyId
WHERE company_id IS NULL;
GO

IF EXISTS (SELECT 1 FROM dbo.udt_office_locations WHERE company_id IS NULL)
    THROW 51401, 'Masih ada lokasi kantor tanpa company_id.', 1;
GO

IF NOT EXISTS
(
    SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_office_locations_company'
)
    ALTER TABLE dbo.udt_office_locations WITH CHECK
    ADD CONSTRAINT FK_office_locations_company
        FOREIGN KEY (company_id) REFERENCES dbo.udt_companies(id);
GO

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.udt_office_locations')
      AND name = 'IX_office_locations_company_active'
)
    CREATE INDEX IX_office_locations_company_active
        ON dbo.udt_office_locations(company_id, is_active)
        INCLUDE(office_name, latitude, longitude, radius_meters);
GO

/* 2. Endpoint daftar lokasi untuk Live Attendance/Absensi Wajah. */
CREATE OR ALTER PROCEDURE dbo.udp_get_office_locations
    @user_id VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @company_id INT;
    SELECT TOP (1) @company_id = ci.company_id
    FROM dbo.udt_users u
    INNER JOIN dbo.udt_company_info_user ci ON ci.userid = u.userid
    INNER JOIN dbo.udt_companies c
        ON c.id = ci.company_id AND c.is_active = 1
    WHERE u.userid = @user_id
      AND u.active = 1
      AND ISNULL(u.deleted, 0) = 0;

    IF @company_id IS NULL
        THROW 51402, 'User tidak aktif atau belum terhubung ke perusahaan.', 1;

    SELECT
        id,
        office_name,
        latitude,
        longitude,
        radius_meters,
        is_active
    FROM dbo.udt_office_locations
    WHERE company_id = @company_id
      AND is_active = 1
    ORDER BY office_name;
END;
GO

/*
  3. Patch SP absensi wajah yang sudah ada tanpa menyalin ulang seluruh
     business logic absensi. Script berhenti jika bentuk SP tidak sesuai,
     supaya tidak menghasilkan perubahan sebagian yang berbahaya.
*/
DECLARE @Definition NVARCHAR(MAX) =
    OBJECT_DEFINITION(OBJECT_ID('dbo.udp_verify_face_attendance_python'));

IF @Definition IS NULL
    THROW 51403, 'SP udp_verify_face_attendance_python tidak ditemukan.', 1;

IF @Definition NOT LIKE '%DECLARE @company_id INT;%'
BEGIN
    IF CHARINDEX('DECLARE @is_calendar_holiday BIT = CASE', @Definition) = 0
        THROW 51404, 'Blok kalender pada SP absensi wajah tidak dikenali.', 1;

    SET @Definition = REPLACE(
        @Definition,
        'DECLARE @is_calendar_holiday BIT = CASE',
        'DECLARE @company_id INT;
        SELECT TOP (1) @company_id = ci.company_id
        FROM dbo.udt_users user_account
        INNER JOIN dbo.udt_company_info_user ci
            ON ci.userid = user_account.userid
        INNER JOIN dbo.udt_companies company
            ON company.id = ci.company_id AND company.is_active = 1
        WHERE user_account.userid = @user_id
          AND user_account.active = 1
          AND ISNULL(user_account.deleted, 0) = 0;

        IF @company_id IS NULL
        BEGIN
            ROLLBACK TRANSACTION;
            SET @result_code = -1;
            SET @result_message = N''User tidak aktif atau belum terhubung ke perusahaan'';
            RETURN;
        END;

        DECLARE @is_company_workday BIT = CASE
            WHEN EXISTS
            (
                SELECT 1
                FROM dbo.udt_company_calendar work_calendar
                WHERE work_calendar.company_id = @company_id
                  AND work_calendar.tanggal = @today
                  AND UPPER(LTRIM(RTRIM(ISNULL(work_calendar.tipe, '''')))) = ''KERJA''
            ) THEN 1 ELSE 0 END;

        DECLARE @is_calendar_holiday BIT = CASE'
    );
END;

IF @Definition NOT LIKE '%c.company_id = @company_id%'
BEGIN
    IF CHARINDEX('WHERE c.tanggal = @today', @Definition) = 0
        THROW 51405, 'Filter kalender pada SP absensi wajah tidak dikenali.', 1;

    SET @Definition = REPLACE(
        @Definition,
        'WHERE c.tanggal = @today',
        'WHERE c.company_id = @company_id
                  AND c.tanggal = @today'
    );
END;

IF @Definition NOT LIKE '%@is_company_workday = 0 AND (@is_saturday%'
BEGIN
    IF CHARINDEX(
        'WHEN @is_saturday = 1 OR @is_sunday = 1 OR @is_calendar_holiday = 1 THEN 1',
        @Definition
    ) = 0
        THROW 51406, 'Perhitungan hari libur pada SP absensi wajah tidak dikenali.', 1;

    SET @Definition = REPLACE(
        @Definition,
        'WHEN @is_saturday = 1 OR @is_sunday = 1 OR @is_calendar_holiday = 1 THEN 1',
        'WHEN @is_company_workday = 0 AND (@is_saturday = 1 OR @is_sunday = 1 OR @is_calendar_holiday = 1) THEN 1'
    );
END;

IF @Definition NOT LIKE '%o.company_id = @company_id%'
BEGIN
    IF CHARINDEX('WHERE o.is_active = 1', @Definition) = 0
        THROW 51407, 'Filter lokasi kantor pada SP absensi wajah tidak dikenali.', 1;

    SET @Definition = REPLACE(
        @Definition,
        'WHERE o.is_active = 1',
        'WHERE o.is_active = 1
          AND o.company_id = @company_id'
    );
END;

/* OBJECT_DEFINITION dapat menyimpan CREATE PROCEDURE pada instalasi lama. */
IF UPPER(LTRIM(@Definition)) LIKE 'CREATE%PROCEDURE%'
   AND UPPER(LTRIM(@Definition)) NOT LIKE 'CREATE OR ALTER%'
BEGIN
    DECLARE @CreatePosition INT = CHARINDEX('CREATE', UPPER(@Definition));
    SET @Definition = STUFF(@Definition, @CreatePosition, 6, 'ALTER');
END;

EXEC sys.sp_executesql @Definition;
GO

/* 4. Guard: office pada baris absensi wajib satu PT dengan pemilik absensi. */
CREATE OR ALTER TRIGGER dbo.trg_attendance_office_company_guard
ON dbo.udt_attendance
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted i
        INNER JOIN dbo.udt_company_info_user ci ON ci.userid = i.user_id
        LEFT JOIN dbo.udt_office_locations checkin_office
            ON checkin_office.id = i.check_in_office_id
        WHERE i.check_in_office_id IS NOT NULL
          AND (checkin_office.company_id IS NULL
               OR checkin_office.company_id <> ci.company_id)
    )
        THROW 51408, 'Lokasi check-in berasal dari perusahaan lain.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM inserted i
        INNER JOIN dbo.udt_company_info_user ci ON ci.userid = i.user_id
        LEFT JOIN dbo.udt_office_locations checkout_office
            ON checkout_office.id = i.check_out_office_id
        WHERE i.check_out_office_id IS NOT NULL
          AND (checkout_office.company_id IS NULL
               OR checkout_office.company_id <> ci.company_id)
    )
        THROW 51409, 'Lokasi check-out berasal dari perusahaan lain.', 1;
END;
GO

/* Verifikasi deploy. */
SELECT company_id, COUNT(*) AS total_locations
FROM dbo.udt_office_locations
GROUP BY company_id
ORDER BY company_id;

SELECT
    CASE
        WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.udp_verify_face_attendance_python'))
             LIKE '%o.company_id = @company_id%'
        THEN 'OK - radius sudah per perusahaan'
        ELSE 'GAGAL - filter perusahaan belum masuk'
    END AS attendance_scope_status;
GO

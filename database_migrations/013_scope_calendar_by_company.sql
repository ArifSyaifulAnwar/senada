/*
  SENADA - Isolasi kalender dan periode kerja per perusahaan

  Cakupan:
  - Event LIBUR, KERJA, WFH, dan INFO hanya terlihat oleh perusahaan pemilik.
  - KERJA meng-override Sabtu/Minggu atau hari libur pada perusahaan tersebut.
  - Tambah, edit, dan hapus hanya boleh dilakukan HRD/Admin/Direktur satu PT.
  - Lampiran, ulang tahun, periode kerja, dan penerima notifikasi ikut tenant-safe.

  Jalankan pada ABSENSI sesudah 010 dan 012.
*/
USE [ABSENSI];
GO
SET XACT_ABORT ON;
GO

/* 1. Pastikan kedua tabel konfigurasi menyimpan tenant. */
IF COL_LENGTH('dbo.udt_company_calendar', 'company_id') IS NULL
    ALTER TABLE dbo.udt_company_calendar ADD company_id INT NULL;
GO

IF COL_LENGTH('dbo.udt_work_period', 'company_id') IS NULL
    ALTER TABLE dbo.udt_work_period ADD company_id INT NULL;
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
    THROW 51300, 'Perusahaan utama untuk migrasi kalender tidak ditemukan.', 1;

/* Data legacy dianggap milik PT lama/utama, bukan disalin ke semua PT. */
UPDATE dbo.udt_company_calendar
SET company_id = @LegacyCompanyId
WHERE company_id IS NULL;

UPDATE dbo.udt_work_period
SET company_id = @LegacyCompanyId
WHERE company_id IS NULL;
GO

IF EXISTS (SELECT 1 FROM dbo.udt_company_calendar WHERE company_id IS NULL)
    THROW 51301, 'Masih ada event kalender tanpa company_id.', 1;

IF EXISTS (SELECT 1 FROM dbo.udt_work_period WHERE company_id IS NULL)
    THROW 51302, 'Masih ada periode kerja tanpa company_id.', 1;
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_company_calendar_company')
    ALTER TABLE dbo.udt_company_calendar WITH CHECK
    ADD CONSTRAINT FK_company_calendar_company
        FOREIGN KEY (company_id) REFERENCES dbo.udt_companies(id);

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_work_period_company')
    ALTER TABLE dbo.udt_work_period WITH CHECK
    ADD CONSTRAINT FK_work_period_company
        FOREIGN KEY (company_id) REFERENCES dbo.udt_companies(id);
GO

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.udt_company_calendar')
      AND name = 'IX_company_calendar_company_date'
)
    CREATE INDEX IX_company_calendar_company_date
        ON dbo.udt_company_calendar(company_id, tanggal, tipe);

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.udt_work_period')
      AND name = 'IX_work_period_company_period'
)
    CREATE INDEX IX_work_period_company_period
        ON dbo.udt_work_period(company_id, tahun, bulan);
GO

/* 2. Guard untuk jalur SQL legacy/direct. */
CREATE OR ALTER TRIGGER dbo.trg_company_calendar_company_guard
ON dbo.udt_company_calendar
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted i
        LEFT JOIN dbo.udt_company_info_user ci ON ci.userid = i.created_by
        WHERE ci.company_id IS NULL OR i.company_id <> ci.company_id
    )
        THROW 51303, 'Event kalender harus mengikuti perusahaan pembuat.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_work_period_company_guard
ON dbo.udt_work_period
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted i
        LEFT JOIN dbo.udt_company_info_user ci ON ci.userid = i.created_by
        WHERE ci.company_id IS NULL OR i.company_id <> ci.company_id
    )
        THROW 51304, 'Periode kerja harus mengikuti perusahaan pembuat.', 1;
END;
GO

/* 3. List event hanya untuk tenant user peminta. */
CREATE OR ALTER PROCEDURE dbo.udp_calendar_get_by_year
    @tahun  INT,
    @tipe   VARCHAR(10) = NULL,
    @userId NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @companyId INT;
    SELECT TOP (1) @companyId = ci.company_id
    FROM dbo.udt_users u
    INNER JOIN dbo.udt_company_info_user ci ON ci.userid = u.userid
    INNER JOIN dbo.udt_companies c ON c.id = ci.company_id AND c.is_active = 1
    WHERE u.userid = @userId
      AND u.active = 1
      AND ISNULL(u.deleted, 0) = 0;

    IF @companyId IS NULL
        THROW 51305, 'User tidak aktif atau belum terhubung ke perusahaan.', 1;

    SELECT
        cal.id,
        cal.tanggal,
        cal.tipe,
        cal.keterangan,
        cal.created_by,
        cal.created_at,
        cal.updated_at,
        CONVERT(BIT, CASE WHEN cal.attachment_image IS NULL THEN 0 ELSE 1 END)
            AS has_attachment,
        cal.attachment_filename,
        cal.attachment_content_type
    FROM dbo.udt_company_calendar cal
    WHERE cal.company_id = @companyId
      AND YEAR(cal.tanggal) = @tahun
      AND (@tipe IS NULL OR cal.tipe = UPPER(LTRIM(RTRIM(@tipe))))
    ORDER BY cal.tanggal, cal.id;
END;
GO

/* 4. Simpan event: company_id selalu berasal dari actor. */
CREATE OR ALTER PROCEDURE dbo.udp_calendar_save
    @id                      INT = NULL,
    @tanggal                 DATE,
    @tipe                    VARCHAR(10),
    @keterangan              NVARCHAR(200),
    @created_by              VARCHAR(50),
    @attachment_image        VARBINARY(MAX) = NULL,
    @attachment_filename     NVARCHAR(255) = NULL,
    @attachment_content_type VARCHAR(100) = NULL,
    @remove_attachment       BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @companyId INT;
    DECLARE @hasAccess BIT = 0;
    SET @tipe = UPPER(LTRIM(RTRIM(@tipe)));

    SELECT TOP (1)
        @companyId = ci.company_id,
        @hasAccess = CASE
            WHEN UPPER(LTRIM(RTRIM(ISNULL(u.role, '')))) IN ('HRD','ADMIN') THEN 1
            WHEN UPPER(ISNULL(ci.organization, '')) LIKE '%HRD%' THEN 1
            WHEN UPPER(ISNULL(ci.job_position, '')) LIKE '%HRD%' THEN 1
            WHEN UPPER(ISNULL(ci.organization, '')) LIKE '%DIREKTUR%' THEN 1
            WHEN UPPER(ISNULL(ci.job_position, '')) LIKE '%DIREKTUR%' THEN 1
            ELSE 0
        END
    FROM dbo.udt_users u
    INNER JOIN dbo.udt_company_info_user ci ON ci.userid = u.userid
    INNER JOIN dbo.udt_companies c ON c.id = ci.company_id AND c.is_active = 1
    WHERE u.userid = @created_by
      AND u.active = 1
      AND ISNULL(u.deleted, 0) = 0;

    IF @companyId IS NULL OR @hasAccess = 0
    BEGIN
        SELECT 0 AS success, N'Akun tidak berwenang mengelola kalender perusahaan.' AS message,
               CAST(NULL AS INT) AS id;
        RETURN;
    END;

    IF @tipe NOT IN ('LIBUR','KERJA','WFH','INFO')
    BEGIN
        SELECT 0 AS success, N'Tipe kalender tidak valid.' AS message,
               CAST(NULL AS INT) AS id;
        RETURN;
    END;

    IF NULLIF(LTRIM(RTRIM(@keterangan)), '') IS NULL
    BEGIN
        SELECT 0 AS success, N'Keterangan wajib diisi.' AS message,
               CAST(NULL AS INT) AS id;
        RETURN;
    END;

    IF @id IS NOT NULL AND NOT EXISTS
    (
        SELECT 1 FROM dbo.udt_company_calendar
        WHERE id = @id AND company_id = @companyId
    )
    BEGIN
        SELECT 0 AS success, N'Event tidak ditemukan pada perusahaan Anda.' AS message,
               CAST(NULL AS INT) AS id;
        RETURN;
    END;

    /* Dalam satu tanggal hanya boleh ada satu kebijakan kehadiran utama.
       INFO tetap boleh berdampingan dengan kebijakan tersebut. */
    IF @tipe IN ('LIBUR','KERJA','WFH') AND EXISTS
    (
        SELECT 1
        FROM dbo.udt_company_calendar
        WHERE company_id = @companyId
          AND tanggal = @tanggal
          AND tipe IN ('LIBUR','KERJA','WFH')
          AND (@id IS NULL OR id <> @id)
    )
    BEGIN
        SELECT 0 AS success,
               N'Tanggal tersebut sudah memiliki kebijakan LIBUR/KERJA/WFH.' AS message,
               CAST(NULL AS INT) AS id;
        RETURN;
    END;

    IF @id IS NULL
    BEGIN
        INSERT INTO dbo.udt_company_calendar
        (
            company_id, tanggal, tipe, keterangan, created_by,
            created_at, updated_at, attachment_image,
            attachment_filename, attachment_content_type
        )
        VALUES
        (
            @companyId, @tanggal, @tipe, LTRIM(RTRIM(@keterangan)), @created_by,
            GETDATE(), GETDATE(), @attachment_image,
            @attachment_filename, @attachment_content_type
        );

        SET @id = CONVERT(INT, SCOPE_IDENTITY());
    END
    ELSE
    BEGIN
        UPDATE dbo.udt_company_calendar
        SET tanggal = @tanggal,
            tipe = @tipe,
            keterangan = LTRIM(RTRIM(@keterangan)),
            created_by = @created_by,
            updated_at = GETDATE(),
            attachment_image = CASE
                WHEN @remove_attachment = 1 THEN NULL
                WHEN @attachment_image IS NOT NULL THEN @attachment_image
                ELSE attachment_image END,
            attachment_filename = CASE
                WHEN @remove_attachment = 1 THEN NULL
                WHEN @attachment_image IS NOT NULL THEN @attachment_filename
                ELSE attachment_filename END,
            attachment_content_type = CASE
                WHEN @remove_attachment = 1 THEN NULL
                WHEN @attachment_image IS NOT NULL THEN @attachment_content_type
                ELSE attachment_content_type END
        WHERE id = @id AND company_id = @companyId;
    END;

    SELECT 1 AS success, N'Event kalender berhasil disimpan.' AS message, @id AS id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_calendar_delete
    @id         INT,
    @deleted_by VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @companyId INT, @hasAccess BIT = 0;
    SELECT TOP (1)
        @companyId = ci.company_id,
        @hasAccess = CASE
            WHEN UPPER(LTRIM(RTRIM(ISNULL(u.role, '')))) IN ('HRD','ADMIN') THEN 1
            WHEN UPPER(ISNULL(ci.organization, '')) LIKE '%HRD%' THEN 1
            WHEN UPPER(ISNULL(ci.job_position, '')) LIKE '%HRD%' THEN 1
            WHEN UPPER(ISNULL(ci.organization, '')) LIKE '%DIREKTUR%' THEN 1
            WHEN UPPER(ISNULL(ci.job_position, '')) LIKE '%DIREKTUR%' THEN 1
            ELSE 0 END
    FROM dbo.udt_users u
    INNER JOIN dbo.udt_company_info_user ci ON ci.userid = u.userid
    WHERE u.userid = @deleted_by AND u.active = 1 AND ISNULL(u.deleted,0) = 0;

    IF @companyId IS NULL OR @hasAccess = 0
    BEGIN
        SELECT 0 AS success, N'Akun tidak berwenang menghapus kalender.' AS message;
        RETURN;
    END;

    DELETE FROM dbo.udt_company_calendar WHERE id = @id AND company_id = @companyId;
    DECLARE @deleted INT = @@ROWCOUNT;
    SELECT CASE WHEN @deleted = 1 THEN 1 ELSE 0 END AS success,
           CASE WHEN @deleted = 1 THEN N'Event berhasil dihapus.'
                ELSE N'Event tidak ditemukan pada perusahaan Anda.' END AS message;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_calendar_get_attachment
    @id      INT,
    @user_id VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT cal.attachment_image, cal.attachment_filename,
           cal.attachment_content_type
    FROM dbo.udt_company_calendar cal
    INNER JOIN dbo.udt_company_info_user ci
        ON ci.company_id = cal.company_id AND ci.userid = @user_id
    INNER JOIN dbo.udt_users u
        ON u.userid = ci.userid AND u.active = 1 AND ISNULL(u.deleted,0) = 0
    WHERE cal.id = @id;
END;
GO

/* 5. Pemeriksaan hari: KERJA meng-override weekend/LIBUR untuk PT tersebut. */
CREATE OR ALTER PROCEDURE dbo.udp_calendar_check_tanggal
    @tanggal DATE,
    @user_id VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @companyId INT;
    SELECT TOP (1) @companyId = ci.company_id
    FROM dbo.udt_users u
    INNER JOIN dbo.udt_company_info_user ci ON ci.userid = u.userid
    INNER JOIN dbo.udt_companies c ON c.id = ci.company_id AND c.is_active = 1
    WHERE u.userid = @user_id AND u.active = 1 AND ISNULL(u.deleted,0) = 0;

    IF @companyId IS NULL
        THROW 51306, 'User tidak aktif atau belum terhubung ke perusahaan.', 1;

    DECLARE @isWeekend BIT = CASE
        WHEN (DATEDIFF(DAY, CONVERT(DATE,'19000101'), @tanggal) % 7) IN (5,6)
        THEN 1 ELSE 0 END;
    DECLARE @tipe VARCHAR(10), @keterangan NVARCHAR(500);

    SELECT TOP (1) @tipe = UPPER(LTRIM(RTRIM(tipe))), @keterangan = keterangan
    FROM dbo.udt_company_calendar
    WHERE company_id = @companyId
      AND tanggal = @tanggal
      AND UPPER(LTRIM(RTRIM(tipe))) IN ('KERJA','LIBUR','WFH')
    ORDER BY CASE UPPER(LTRIM(RTRIM(tipe)))
                 WHEN 'KERJA' THEN 1 WHEN 'LIBUR' THEN 2 ELSE 3 END, id DESC;

    SELECT
        @tanggal AS tanggal,
        @isWeekend AS is_weekend,
        CONVERT(BIT, CASE WHEN @tipe = 'LIBUR' THEN 1 ELSE 0 END) AS is_libur,
        CONVERT(BIT, CASE WHEN @tipe = 'WFH' THEN 1 ELSE 0 END) AS is_wfh,
        CONVERT(BIT, CASE WHEN @tipe = 'KERJA' THEN 1 ELSE 0 END) AS is_kerja,
        CONVERT(BIT, CASE
            WHEN @tipe = 'KERJA' THEN 0
            WHEN @tipe = 'LIBUR' OR @isWeekend = 1 THEN 1
            ELSE 0 END) AS is_hari_libur,
        COALESCE(NULLIF(LTRIM(RTRIM(@keterangan)), ''),
                 CASE WHEN @isWeekend = 1 THEN
                    CASE WHEN (DATEDIFF(DAY, CONVERT(DATE,'19000101'), @tanggal) % 7) = 5
                         THEN N'Hari Sabtu' ELSE N'Hari Minggu' END
                 ELSE N'' END) AS keterangan;
END;
GO

/* 6. Periode kerja per tenant. */
CREATE OR ALTER PROCEDURE dbo.udp_work_period_get_by_year
    @tahun   INT,
    @user_id VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @companyId INT;
    SELECT @companyId = company_id FROM dbo.udt_company_info_user WHERE userid = @user_id;

    SELECT id, tahun, bulan, tanggal_mulai, tanggal_selesai, keterangan,
           created_by, updated_by, created_at, updated_at
    FROM dbo.udt_work_period
    WHERE company_id = @companyId AND tahun = @tahun
    ORDER BY bulan, tanggal_mulai;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_work_period_save
    @id              INT = NULL,
    @tahun           INT,
    @bulan           INT,
    @tanggal_mulai   DATE,
    @tanggal_selesai DATE,
    @keterangan      NVARCHAR(200) = NULL,
    @created_by      VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @companyId INT, @hasAccess BIT = 0;
    SELECT TOP (1)
        @companyId = ci.company_id,
        @hasAccess = CASE
            WHEN UPPER(LTRIM(RTRIM(ISNULL(u.role,'')))) IN ('HRD','ADMIN') THEN 1
            WHEN UPPER(ISNULL(ci.organization,'')) LIKE '%HRD%' THEN 1
            WHEN UPPER(ISNULL(ci.job_position,'')) LIKE '%HRD%' THEN 1
            WHEN UPPER(ISNULL(ci.organization,'')) LIKE '%DIREKTUR%' THEN 1
            WHEN UPPER(ISNULL(ci.job_position,'')) LIKE '%DIREKTUR%' THEN 1
            ELSE 0 END
    FROM dbo.udt_users u
    INNER JOIN dbo.udt_company_info_user ci ON ci.userid = u.userid
    WHERE u.userid = @created_by AND u.active = 1 AND ISNULL(u.deleted,0) = 0;

    IF @companyId IS NULL OR @hasAccess = 0
    BEGIN
        SELECT 0 AS success, N'Akun tidak berwenang mengelola periode kerja.' AS message,
               CAST(NULL AS INT) AS id;
        RETURN;
    END;

    IF @tanggal_selesai < @tanggal_mulai OR @bulan NOT BETWEEN 1 AND 12
    BEGIN
        SELECT 0 AS success, N'Rentang periode kerja tidak valid.' AS message,
               CAST(NULL AS INT) AS id;
        RETURN;
    END;

    IF EXISTS
    (
        SELECT 1 FROM dbo.udt_work_period
        WHERE company_id = @companyId AND tahun = @tahun AND bulan = @bulan
          AND (@id IS NULL OR id <> @id)
    )
    BEGIN
        SELECT 0 AS success, N'Periode untuk bulan dan tahun tersebut sudah ada.' AS message,
               CAST(NULL AS INT) AS id;
        RETURN;
    END;

    IF @id IS NULL
    BEGIN
        INSERT INTO dbo.udt_work_period
        (company_id, tahun, bulan, tanggal_mulai, tanggal_selesai, keterangan,
         created_by, created_at, updated_at)
        VALUES
        (@companyId, @tahun, @bulan, @tanggal_mulai, @tanggal_selesai,
         @keterangan, @created_by, GETDATE(), GETDATE());
        SET @id = CONVERT(INT, SCOPE_IDENTITY());
    END
    ELSE
    BEGIN
        UPDATE dbo.udt_work_period
        SET tahun = @tahun, bulan = @bulan, tanggal_mulai = @tanggal_mulai,
            tanggal_selesai = @tanggal_selesai, keterangan = @keterangan,
            created_by = @created_by, updated_by = @created_by,
            updated_at = GETDATE()
        WHERE id = @id AND company_id = @companyId;

        IF @@ROWCOUNT <> 1
        BEGIN
            SELECT 0 AS success, N'Periode tidak ditemukan pada perusahaan Anda.' AS message,
                   CAST(NULL AS INT) AS id;
            RETURN;
        END;
    END;

    SELECT 1 AS success, N'Periode kerja berhasil disimpan.' AS message, @id AS id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_work_period_delete
    @id         INT,
    @deleted_by VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @companyId INT, @hasAccess BIT = 0;
    SELECT TOP (1)
        @companyId = ci.company_id,
        @hasAccess = CASE
            WHEN UPPER(LTRIM(RTRIM(ISNULL(u.role,'')))) IN ('HRD','ADMIN') THEN 1
            WHEN UPPER(ISNULL(ci.organization,'')) LIKE '%HRD%' THEN 1
            WHEN UPPER(ISNULL(ci.job_position,'')) LIKE '%HRD%' THEN 1
            WHEN UPPER(ISNULL(ci.organization,'')) LIKE '%DIREKTUR%' THEN 1
            WHEN UPPER(ISNULL(ci.job_position,'')) LIKE '%DIREKTUR%' THEN 1
            ELSE 0 END
    FROM dbo.udt_users u
    INNER JOIN dbo.udt_company_info_user ci ON ci.userid = u.userid
    WHERE u.userid = @deleted_by AND u.active = 1 AND ISNULL(u.deleted,0) = 0;

    IF @companyId IS NULL OR @hasAccess = 0
    BEGIN
        SELECT 0 AS success, N'Akun tidak berwenang menghapus periode kerja.' AS message;
        RETURN;
    END;

    DELETE FROM dbo.udt_work_period WHERE id = @id AND company_id = @companyId;
    DECLARE @deleted INT = @@ROWCOUNT;
    SELECT CASE WHEN @deleted = 1 THEN 1 ELSE 0 END AS success,
           CASE WHEN @deleted = 1 THEN N'Periode kerja berhasil dihapus.'
                ELSE N'Periode tidak ditemukan pada perusahaan Anda.' END AS message;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_work_period_check_by_date
    @tanggal DATE,
    @user_id VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @companyId INT;
    SELECT @companyId = company_id FROM dbo.udt_company_info_user WHERE userid = @user_id;

    SELECT TOP (1) id, tahun, bulan, tanggal_mulai, tanggal_selesai,
           keterangan, created_by, updated_by, created_at, updated_at
    FROM dbo.udt_work_period
    WHERE company_id = @companyId
      AND @tanggal BETWEEN tanggal_mulai AND tanggal_selesai
    ORDER BY tanggal_mulai DESC, id DESC;
END;
GO

/* 7. Ulang tahun dan penerima notifikasi hanya satu perusahaan. */
CREATE OR ALTER PROCEDURE dbo.udp_get_active_employee_birthdays
    @userId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @companyId INT;
    SELECT @companyId = company_id FROM dbo.udt_company_info_user WHERE userid = @userId;

    SELECT u.userid, u.name, u.birth_date
    FROM dbo.udt_users u
    INNER JOIN dbo.udt_company_info_user ci
        ON ci.userid = u.userid AND ci.company_id = @companyId
    WHERE u.active = 1 AND ISNULL(u.deleted,0) = 0 AND u.birth_date IS NOT NULL
    ORDER BY MONTH(u.birth_date), DAY(u.birth_date), u.name;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_calendar_get_karyawan_for_notify
    @hrd_user_id VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @companyId INT;
    SELECT @companyId = company_id FROM dbo.udt_company_info_user WHERE userid = @hrd_user_id;

    SELECT u.userid, u.name, u.phone
    FROM dbo.udt_users u
    INNER JOIN dbo.udt_company_info_user ci
        ON ci.userid = u.userid AND ci.company_id = @companyId
    WHERE u.active = 1 AND ISNULL(u.deleted,0) = 0
    ORDER BY u.name;
END;
GO

/* Verifikasi deploy dan data tenant. */
SELECT name, modify_date
FROM sys.procedures
WHERE name IN
(
    'udp_calendar_get_by_year','udp_calendar_save','udp_calendar_delete',
    'udp_calendar_get_attachment','udp_calendar_check_tanggal',
    'udp_work_period_get_by_year','udp_work_period_save',
    'udp_work_period_delete','udp_work_period_check_by_date',
    'udp_get_active_employee_birthdays','udp_calendar_get_karyawan_for_notify'
)
ORDER BY name;

SELECT company_id, COUNT(*) AS total_events
FROM dbo.udt_company_calendar GROUP BY company_id ORDER BY company_id;

SELECT company_id, COUNT(*) AS total_periods
FROM dbo.udt_work_period GROUP BY company_id ORDER BY company_id;
GO

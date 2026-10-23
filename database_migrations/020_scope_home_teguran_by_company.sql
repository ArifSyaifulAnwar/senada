/*
  SENADA - Isolasi layanan Teguran per perusahaan

  Melengkapi pemisahan multi-PT pada layanan Home.
  File Saya/Berkas Kantor dan Aktivitas Harian telah ditangani migration 018;
  Asset telah ditangani migration 019. Migration ini menutup jalur Teguran
  (buat, daftar, edit, detail, dan unduh PDF) agar seluruhnya memakai
  company_id pemilik data, bukan hanya userid atau id dokumen.
*/
USE [ABSENSI];
GO
SET XACT_ABORT ON;
GO

IF COL_LENGTH('dbo.udt_teguran', 'company_id') IS NULL
    ALTER TABLE dbo.udt_teguran ADD company_id INT NULL;
GO

UPDATE t
SET company_id = ci.company_id
FROM dbo.udt_teguran t
INNER JOIN dbo.udt_company_info_user ci ON ci.userid = t.userid
WHERE t.company_id IS NULL;
GO

IF EXISTS (SELECT 1 FROM dbo.udt_teguran WHERE company_id IS NULL)
    THROW 52000, 'Masih ada teguran tanpa company_id. Perbaiki mapping user terlebih dahulu.', 1;
GO

ALTER TABLE dbo.udt_teguran ALTER COLUMN company_id INT NOT NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_teguran_company')
    ALTER TABLE dbo.udt_teguran WITH CHECK
    ADD CONSTRAINT FK_teguran_company FOREIGN KEY(company_id) REFERENCES dbo.udt_companies(id);
GO

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.udt_teguran')
      AND name = 'IX_teguran_company_user_date'
)
    CREATE INDEX IX_teguran_company_user_date
        ON dbo.udt_teguran(company_id, userid, tanggal DESC, id DESC)
        INCLUDE(level, judul, issued_by, no_surat, created_at);
GO

CREATE OR ALTER TRIGGER dbo.trg_teguran_company_guard
ON dbo.udt_teguran
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted i
        LEFT JOIN dbo.udt_company_info_user target_ci ON target_ci.userid = i.userid
        WHERE target_ci.company_id IS NULL OR target_ci.company_id <> i.company_id
    )
        THROW 52001, 'Perusahaan teguran tidak sesuai dengan karyawan yang ditegur.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM inserted i
        LEFT JOIN dbo.udt_company_info_user issuer_ci ON issuer_ci.userid = i.issued_by
        WHERE i.issued_by IS NOT NULL
          AND (issuer_ci.company_id IS NULL OR issuer_ci.company_id <> i.company_id)
    )
        THROW 52002, 'Penerbit teguran harus berasal dari perusahaan yang sama.', 1;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_teguran_check_head
    @userid NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT ci.userid, ci.name, ci.job_position, ci.organization,
           CASE WHEN UPPER(ISNULL(ci.organization, '')) LIKE '%HRD%'
                  AND UPPER(ISNULL(ci.job_position, '')) LIKE 'HEAD OF%'
                THEN 1 ELSE 0 END AS is_hrd_head
    FROM dbo.udt_company_info_user ci
    INNER JOIN dbo.udt_users u ON u.userid = ci.userid
    INNER JOIN dbo.udt_companies co ON co.id = ci.company_id AND co.is_active = 1
    WHERE ci.userid = @userid
      AND u.active = 1
      AND ISNULL(u.deleted, 0) = 0
      AND UPPER(ISNULL(ci.job_position, '')) LIKE 'HEAD OF%';
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_teguran_create
    @userid          NVARCHAR(100),
    @level           NVARCHAR(20),
    @judul           NVARCHAR(255),
    @deskripsi       NVARCHAR(MAX) = NULL,
    @tanggal         DATETIME,
    @issued_by       NVARCHAR(100) = NULL,
    @issued_by_name  NVARCHAR(200) = NULL,
    @id              INT OUTPUT,
    @no_surat        NVARCHAR(50) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @id = NULL;
    SET @no_surat = NULL;

    DECLARE @company_id INT, @issuer_company_id INT;
    SELECT @company_id = ci.company_id
    FROM dbo.udt_users u
    INNER JOIN dbo.udt_company_info_user ci ON ci.userid = u.userid
    INNER JOIN dbo.udt_companies co ON co.id = ci.company_id AND co.is_active = 1
    WHERE u.userid = @userid AND u.active = 1 AND ISNULL(u.deleted, 0) = 0;

    SELECT @issuer_company_id = ci.company_id
    FROM dbo.udt_users u
    INNER JOIN dbo.udt_company_info_user ci ON ci.userid = u.userid
    WHERE u.userid = @issued_by AND u.active = 1 AND ISNULL(u.deleted, 0) = 0
      AND UPPER(ISNULL(ci.job_position, '')) LIKE 'HEAD OF%';

    IF @company_id IS NULL OR @issuer_company_id IS NULL OR @company_id <> @issuer_company_id
        THROW 52003, 'Karyawan dan penerbit teguran harus aktif serta berasal dari perusahaan yang sama.', 1;

    DECLARE @tahun INT = YEAR(@tanggal);
    DECLARE @urut INT, @lockResult INT;
    DECLARE @lockResource NVARCHAR(255) = CONCAT(N'teguran:', @company_id, N':', @tahun);
    DECLARE @bulanRomawi NVARCHAR(10) = CASE MONTH(@tanggal)
        WHEN 1 THEN 'I' WHEN 2 THEN 'II' WHEN 3 THEN 'III' WHEN 4 THEN 'IV'
        WHEN 5 THEN 'V' WHEN 6 THEN 'VI' WHEN 7 THEN 'VII' WHEN 8 THEN 'VIII'
        WHEN 9 THEN 'IX' WHEN 10 THEN 'X' WHEN 11 THEN 'XI' WHEN 12 THEN 'XII' END;

    BEGIN TRANSACTION;
    EXEC @lockResult = sys.sp_getapplock
        @Resource = @lockResource,
        @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 10000;
    IF @lockResult < 0
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 52004, 'Gagal mengunci nomor surat, coba lagi.', 1;
    END;

    SELECT @urut = ISNULL(MAX(TRY_CAST(SUBSTRING(no_surat, 1, CHARINDEX('/', no_surat) - 1) AS INT)), 0) + 1
    FROM dbo.udt_teguran
    WHERE company_id = @company_id
      AND no_surat LIKE '%/' + CONVERT(NVARCHAR(4), @tahun);

    SET @no_surat = RIGHT('000' + CONVERT(NVARCHAR(10), @urut), 3) + '/' + @level
                  + '/HRD/' + @bulanRomawi + '/' + CONVERT(NVARCHAR(4), @tahun);

    INSERT dbo.udt_teguran
        (userid, company_id, level, judul, deskripsi, tanggal, no_surat, issued_by, issued_by_name, created_at)
    VALUES
        (@userid, @company_id, @level, @judul, @deskripsi, @tanggal, @no_surat, @issued_by, @issued_by_name, GETDATE());

    SET @id = CONVERT(INT, SCOPE_IDENTITY());
    COMMIT TRANSACTION;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_teguran_get_hrd_head
    @RefUserId NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @company_id INT;
    SELECT @company_id = company_id FROM dbo.udt_company_info_user WHERE userid = @RefUserId;

    SELECT TOP (1) ci.userid, ci.name, ci.job_position
    FROM dbo.udt_company_info_user ci
    INNER JOIN dbo.udt_users u ON u.userid = ci.userid
    WHERE ci.company_id = @company_id
      AND u.active = 1 AND ISNULL(u.deleted, 0) = 0
      AND UPPER(ISNULL(ci.organization, '')) LIKE '%HRD%'
      AND UPPER(ISNULL(ci.job_position, '')) LIKE 'HEAD OF%'
    ORDER BY ci.id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_teguran_get_all
    @HrdUserId NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @company_id INT, @has_access BIT = 0;
    SELECT TOP (1)
        @company_id = ci.company_id,
        @has_access = CASE WHEN UPPER(ISNULL(u.role, '')) IN ('HRD', 'ADMIN')
                                OR UPPER(ISNULL(ci.organization, '')) LIKE '%HRD%'
                                OR UPPER(ISNULL(ci.organization, '')) LIKE '%DIREKTUR%'
                                OR UPPER(ISNULL(ci.job_position, '')) LIKE '%DIREKTUR%'
                           THEN 1 ELSE 0 END
    FROM dbo.udt_users u
    INNER JOIN dbo.udt_company_info_user ci ON ci.userid = u.userid
    WHERE u.userid = @HrdUserId AND u.active = 1 AND ISNULL(u.deleted, 0) = 0;

    SELECT t.id,t.userid,u.name AS user_name,u.nip,ci.job_position,ci.organization AS department,
           t.level,t.judul,t.deskripsi,t.tanggal,t.no_surat,t.issued_by,t.issued_by_name,t.created_at
    FROM dbo.udt_teguran t
    INNER JOIN dbo.udt_company_info_user ci ON ci.userid=t.userid AND ci.company_id=t.company_id
    LEFT JOIN dbo.udt_users u ON u.userid=t.userid
    WHERE @has_access = 1 AND t.company_id = @company_id
    ORDER BY t.created_at DESC,t.id DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_teguran_get_by_user
    @userid NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @company_id INT;
    SELECT @company_id = company_id FROM dbo.udt_company_info_user WHERE userid = @userid;
    SELECT t.id,t.userid,u.name AS user_name,u.nip,ci.job_position,ci.organization AS department,
           t.level,t.judul,t.deskripsi,t.tanggal,t.no_surat,t.issued_by,t.issued_by_name,t.created_at
    FROM dbo.udt_teguran t
    INNER JOIN dbo.udt_company_info_user ci ON ci.userid=t.userid AND ci.company_id=t.company_id
    LEFT JOIN dbo.udt_users u ON u.userid=t.userid
    WHERE t.userid = @userid AND t.company_id = @company_id
    ORDER BY t.tanggal DESC,t.id DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_teguran_get_by_id
    @id INT,
    @viewer_userid NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @viewer_company_id INT, @can_manage BIT = 0;
    SELECT TOP (1)
        @viewer_company_id = ci.company_id,
        @can_manage = CASE WHEN UPPER(ISNULL(u.role, '')) IN ('HRD', 'ADMIN')
                                  OR UPPER(ISNULL(ci.organization, '')) LIKE '%HRD%'
                                  OR UPPER(ISNULL(ci.organization, '')) LIKE '%DIREKTUR%'
                                  OR UPPER(ISNULL(ci.job_position, '')) LIKE '%DIREKTUR%'
                             THEN 1 ELSE 0 END
    FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
    WHERE u.userid=@viewer_userid AND u.active=1 AND ISNULL(u.deleted,0)=0;

    SELECT t.id,t.userid,u.name AS user_name,u.nip,ci.job_position,ci.organization AS department,
           t.level,t.judul,t.deskripsi,t.tanggal,t.no_surat,t.issued_by,t.issued_by_name,t.created_at
    FROM dbo.udt_teguran t
    INNER JOIN dbo.udt_company_info_user ci ON ci.userid=t.userid AND ci.company_id=t.company_id
    LEFT JOIN dbo.udt_users u ON u.userid=t.userid
    WHERE t.id=@id AND t.company_id=@viewer_company_id
      AND (t.userid=@viewer_userid OR t.issued_by=@viewer_userid OR @can_manage=1);
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_teguran_update
    @id INT,
    @level NVARCHAR(20),
    @judul NVARCHAR(255),
    @deskripsi NVARCHAR(MAX) = NULL,
    @tanggal DATETIME,
    @updated_by NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @company_id INT, @is_hrd_head BIT = 0;
    SELECT TOP (1)
        @company_id=ci.company_id,
        @is_hrd_head=CASE WHEN UPPER(ISNULL(ci.organization,'')) LIKE '%HRD%'
                                AND UPPER(ISNULL(ci.job_position,'')) LIKE 'HEAD OF%'
                           THEN 1 ELSE 0 END
    FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
    WHERE u.userid=@updated_by AND u.active=1 AND ISNULL(u.deleted,0)=0;

    UPDATE dbo.udt_teguran
    SET level=@level, judul=@judul, deskripsi=@deskripsi, tanggal=@tanggal
    WHERE id=@id AND company_id=@company_id
      AND (issued_by=@updated_by OR @is_hrd_head=1);
    SELECT @@ROWCOUNT AS rows_affected;
END;
GO

/* Verifikasi deployment dan data hasil backfill. */
SELECT company_id, COUNT(*) AS total_teguran
FROM dbo.udt_teguran GROUP BY company_id ORDER BY company_id;

SELECT p.name,p.modify_date
FROM sys.procedures p
WHERE p.name IN ('udp_teguran_check_head','udp_teguran_create','udp_teguran_get_hrd_head',
                 'udp_teguran_get_all','udp_teguran_get_by_user','udp_teguran_get_by_id','udp_teguran_update')
ORDER BY p.name;
GO

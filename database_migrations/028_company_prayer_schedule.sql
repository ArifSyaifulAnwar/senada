/* Jadwal azan dan imam per perusahaan. Jalankan di ABSENSI sebelum deploy API. */
USE [ABSENSI];
GO
SET XACT_ABORT ON;
GO

IF OBJECT_ID('dbo.udt_company_prayer_schedule', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.udt_company_prayer_schedule
    (
        id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        company_id INT NOT NULL,
        schedule_date DATE NOT NULL,
        prayer_code VARCHAR(10) NOT NULL,
        azan_time TIME(0) NULL,
        muadzin_user_id VARCHAR(50) NOT NULL,
        imam_user_id VARCHAR(50) NOT NULL,
        created_by VARCHAR(50) NOT NULL,
        updated_at DATETIME2(0) NOT NULL CONSTRAINT DF_company_prayer_updated DEFAULT SYSUTCDATETIME(),
        CONSTRAINT UQ_company_prayer_day UNIQUE (company_id, schedule_date, prayer_code),
        CONSTRAINT FK_company_prayer_company FOREIGN KEY (company_id) REFERENCES dbo.udt_companies(id),
        CONSTRAINT CK_company_prayer_code CHECK (prayer_code IN ('SUBUH','ZUHUR','ASAR','MAGRIB','ISYA'))
    );
END;
GO

-- Instalasi lama masih memiliki kolom wajib; jadikan opsional tanpa menghapus data.
IF EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('dbo.udt_company_prayer_schedule')
      AND name = 'azan_time' AND is_nullable = 0
)
    ALTER TABLE dbo.udt_company_prayer_schedule ALTER COLUMN azan_time TIME(0) NULL;
GO

CREATE OR ALTER PROCEDURE dbo.udp_company_prayer_schedule_list
    @user_id VARCHAR(50),
    @schedule_date DATE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @company_id INT;
    SELECT TOP (1) @company_id = ci.company_id
    FROM dbo.udt_company_info_user ci
    JOIN dbo.udt_users u ON u.userid = ci.userid
    JOIN dbo.udt_companies c ON c.id = ci.company_id
    WHERE ci.userid = @user_id AND u.active = 1 AND ISNULL(u.deleted, 0) = 0
      AND c.is_active = 1;

    IF @company_id IS NULL THROW 52800, 'Pengguna tidak terhubung ke perusahaan aktif.', 1;

    SELECT p.id, p.schedule_date, p.prayer_code,
           p.muadzin_user_id, mu.name AS muadzin_name,
           p.imam_user_id, im.name AS imam_name
    FROM dbo.udt_company_prayer_schedule p
    JOIN dbo.udt_users mu ON mu.userid = p.muadzin_user_id
    JOIN dbo.udt_users im ON im.userid = p.imam_user_id
    WHERE p.company_id = @company_id AND p.schedule_date = @schedule_date
    ORDER BY CASE p.prayer_code
        WHEN 'SUBUH' THEN 1 WHEN 'ZUHUR' THEN 2 WHEN 'ASAR' THEN 3
        WHEN 'MAGRIB' THEN 4 WHEN 'ISYA' THEN 5 END;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_company_prayer_schedule_save
    @user_id VARCHAR(50),
    @schedule_date DATE,
    @prayer_code VARCHAR(10),
    @muadzin_user_id VARCHAR(50),
    @imam_user_id VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @company_id INT;
    SELECT TOP (1) @company_id = ci.company_id
    FROM dbo.udt_company_info_user ci
    JOIN dbo.udt_users u ON u.userid = ci.userid
    JOIN dbo.udt_companies c ON c.id = ci.company_id
    WHERE ci.userid = @user_id AND u.active = 1 AND ISNULL(u.deleted, 0) = 0
      AND c.is_active = 1
      AND UPPER(LTRIM(RTRIM(ISNULL(u.role, '')))) = 'HRD';

    IF @company_id IS NULL THROW 52801, 'Hanya HRD perusahaan aktif yang dapat mengubah jadwal.', 1;
    IF @prayer_code NOT IN ('SUBUH','ZUHUR','ASAR','MAGRIB','ISYA')
        THROW 52802, 'Waktu salat tidak valid.', 1;
    IF NOT EXISTS (
        SELECT 1 FROM dbo.udt_company_info_user ci
        JOIN dbo.udt_users u ON u.userid = ci.userid
        WHERE ci.company_id = @company_id AND ci.userid = @muadzin_user_id
          AND u.active = 1 AND ISNULL(u.deleted, 0) = 0
    ) THROW 52803, 'Petugas azan bukan karyawan aktif PT ini.', 1;
    IF NOT EXISTS (
        SELECT 1 FROM dbo.udt_company_info_user ci
        JOIN dbo.udt_users u ON u.userid = ci.userid
        WHERE ci.company_id = @company_id AND ci.userid = @imam_user_id
          AND u.active = 1 AND ISNULL(u.deleted, 0) = 0
    ) THROW 52804, 'Imam bukan karyawan aktif PT ini.', 1;

    BEGIN TRANSACTION;
    UPDATE dbo.udt_company_prayer_schedule WITH (UPDLOCK, SERIALIZABLE)
    SET muadzin_user_id = @muadzin_user_id,
        imam_user_id = @imam_user_id,
        updated_at = SYSUTCDATETIME()
    WHERE company_id = @company_id AND schedule_date = @schedule_date
      AND prayer_code = @prayer_code;
    IF @@ROWCOUNT = 0
        INSERT dbo.udt_company_prayer_schedule
            (company_id, schedule_date, prayer_code,
             muadzin_user_id, imam_user_id, created_by)
        VALUES (@company_id, @schedule_date, @prayer_code,
                @muadzin_user_id, @imam_user_id, @user_id);
    COMMIT TRANSACTION;
END;
GO

/* Jadwal tetap per PT; baris lama pada tabel bertanggal tetap menjadi pengecualian. */
USE [ABSENSI];
GO
SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'dbo.udt_company_prayer_schedule_default', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.udt_company_prayer_schedule_default
    (
        company_id INT NOT NULL,
        prayer_code VARCHAR(10) NOT NULL,
        muadzin_user_id VARCHAR(50) NOT NULL,
        imam_user_id VARCHAR(50) NOT NULL,
        created_by VARCHAR(50) NOT NULL,
        updated_at DATETIME2(0) NOT NULL
            CONSTRAINT DF_company_prayer_default_updated DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_company_prayer_default PRIMARY KEY (company_id, prayer_code),
        CONSTRAINT FK_company_prayer_default_company FOREIGN KEY (company_id)
            REFERENCES dbo.udt_companies(id),
        CONSTRAINT CK_company_prayer_default_code CHECK
            (prayer_code IN ('SUBUH','ZUHUR','ASAR','MAGRIB','ISYA'))
    );
END;
GO

/* Isi awal dari entri bertanggal terakhir tiap PT/waktu salat, bila ada.
   Data harian lama tidak dihapus dan tetap dapat dibaca sebagai pengecualian. */
;WITH latest AS
(
    SELECT p.company_id, p.prayer_code, p.muadzin_user_id,
           p.imam_user_id, p.created_by,
           ROW_NUMBER() OVER (
               PARTITION BY p.company_id, p.prayer_code
               ORDER BY p.schedule_date DESC, p.updated_at DESC, p.id DESC
           ) AS rn
    FROM dbo.udt_company_prayer_schedule p
)
INSERT dbo.udt_company_prayer_schedule_default
    (company_id, prayer_code, muadzin_user_id, imam_user_id, created_by)
SELECT l.company_id, l.prayer_code, l.muadzin_user_id,
       l.imam_user_id, l.created_by
FROM latest l
WHERE l.rn = 1
  AND NOT EXISTS (
      SELECT 1 FROM dbo.udt_company_prayer_schedule_default d
      WHERE d.company_id = l.company_id AND d.prayer_code = l.prayer_code
  );
GO

CREATE OR ALTER PROCEDURE dbo.udp_company_prayer_schedule_default_list
    @user_id VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @company_id INT;
    SELECT TOP (1) @company_id = ci.company_id
    FROM dbo.udt_company_info_user ci
    JOIN dbo.udt_users u ON u.userid = ci.userid
    JOIN dbo.udt_companies c ON c.id = ci.company_id
    WHERE ci.userid = @user_id AND u.active = 1
      AND ISNULL(u.deleted, 0) = 0 AND c.is_active = 1
    ORDER BY ci.company_id;

    IF @company_id IS NULL
        THROW 52800, 'Pengguna tidak terhubung ke perusahaan aktif.', 1;

    SELECT p.prayer_code, p.muadzin_user_id, mu.name AS muadzin_name,
           p.imam_user_id, im.name AS imam_name,
           CAST(0 AS BIT) AS is_override
    FROM dbo.udt_company_prayer_schedule_default p
    JOIN dbo.udt_users mu ON mu.userid = p.muadzin_user_id
    JOIN dbo.udt_users im ON im.userid = p.imam_user_id
    WHERE p.company_id = @company_id
    ORDER BY CASE p.prayer_code
        WHEN 'SUBUH' THEN 1 WHEN 'ZUHUR' THEN 2 WHEN 'ASAR' THEN 3
        WHEN 'MAGRIB' THEN 4 WHEN 'ISYA' THEN 5 END;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_company_prayer_schedule_default_save
    @user_id VARCHAR(50),
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
    WHERE ci.userid = @user_id AND u.active = 1
      AND ISNULL(u.deleted, 0) = 0 AND c.is_active = 1
      AND UPPER(LTRIM(RTRIM(ISNULL(u.role, '')))) = 'HRD'
    ORDER BY ci.company_id;

    IF @company_id IS NULL
        THROW 52801, 'Hanya HRD perusahaan aktif yang dapat mengubah jadwal.', 1;
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
    UPDATE dbo.udt_company_prayer_schedule_default WITH (UPDLOCK, SERIALIZABLE)
    SET muadzin_user_id = @muadzin_user_id,
        imam_user_id = @imam_user_id,
        updated_at = SYSUTCDATETIME()
    WHERE company_id = @company_id AND prayer_code = @prayer_code;
    IF @@ROWCOUNT = 0
        INSERT dbo.udt_company_prayer_schedule_default
            (company_id, prayer_code, muadzin_user_id, imam_user_id, created_by)
        VALUES (@company_id, @prayer_code, @muadzin_user_id,
                @imam_user_id, @user_id);
    COMMIT TRANSACTION;
END;
GO

/* Endpoint lama tetap sama: untuk tanggal tertentu, prioritaskan pengecualian. */
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
    WHERE ci.userid = @user_id AND u.active = 1
      AND ISNULL(u.deleted, 0) = 0 AND c.is_active = 1
    ORDER BY ci.company_id;

    IF @company_id IS NULL
        THROW 52800, 'Pengguna tidak terhubung ke perusahaan aktif.', 1;

    SELECT v.prayer_code,
           COALESCE(o.muadzin_user_id, p.muadzin_user_id) AS muadzin_user_id,
           mu.name AS muadzin_name,
           COALESCE(o.imam_user_id, p.imam_user_id) AS imam_user_id,
           im.name AS imam_name,
           CAST(CASE WHEN o.id IS NULL THEN 0 ELSE 1 END AS BIT) AS is_override
    FROM (VALUES ('SUBUH', 1), ('ZUHUR', 2), ('ASAR', 3),
                 ('MAGRIB', 4), ('ISYA', 5)) v(prayer_code, sort_order)
    LEFT JOIN dbo.udt_company_prayer_schedule_default p
      ON p.company_id = @company_id AND p.prayer_code = v.prayer_code
    LEFT JOIN dbo.udt_company_prayer_schedule o
      ON o.company_id = @company_id AND o.prayer_code = v.prayer_code
     AND o.schedule_date = @schedule_date
    JOIN dbo.udt_users mu
      ON mu.userid = COALESCE(o.muadzin_user_id, p.muadzin_user_id)
    JOIN dbo.udt_users im
      ON im.userid = COALESCE(o.imam_user_id, p.imam_user_id)
    WHERE o.id IS NOT NULL OR p.company_id IS NOT NULL
    ORDER BY v.sort_order;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_company_prayer_schedule_override_delete
    @user_id VARCHAR(50),
    @schedule_date DATE,
    @prayer_code VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @company_id INT;
    SELECT TOP (1) @company_id = ci.company_id
    FROM dbo.udt_company_info_user ci
    JOIN dbo.udt_users u ON u.userid = ci.userid
    JOIN dbo.udt_companies c ON c.id = ci.company_id
    WHERE ci.userid = @user_id AND u.active = 1
      AND ISNULL(u.deleted, 0) = 0 AND c.is_active = 1
      AND UPPER(LTRIM(RTRIM(ISNULL(u.role, '')))) = 'HRD'
    ORDER BY ci.company_id;

    IF @company_id IS NULL
        THROW 52801, 'Hanya HRD perusahaan aktif yang dapat mengubah jadwal.', 1;
    IF @prayer_code NOT IN ('SUBUH','ZUHUR','ASAR','MAGRIB','ISYA')
        THROW 52802, 'Waktu salat tidak valid.', 1;
    DELETE FROM dbo.udt_company_prayer_schedule
    WHERE company_id = @company_id AND schedule_date = @schedule_date
      AND prayer_code = @prayer_code;
END;
GO

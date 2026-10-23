/*
  SENADA - Notifikasi dan broadcast per perusahaan

  Broadcast HRD/Admin selalu dikirim kepada karyawan dalam PT pengirim saja.
  company_id diturunkan dari akun pengirim/penerima di server, bukan client.
*/
USE [ABSENSI];
GO
SET XACT_ABORT ON;
GO

IF COL_LENGTH('dbo.udt_notifications', 'company_id') IS NULL
    ALTER TABLE dbo.udt_notifications ADD company_id INT NULL;
GO

/* Baris lama dipetakan dari pemilik notifikasi. */
UPDATE n
SET company_id = ci.company_id
FROM dbo.udt_notifications n
INNER JOIN dbo.udt_company_info_user ci ON ci.userid = n.user_id
WHERE n.company_id IS NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_notifications_company')
    ALTER TABLE dbo.udt_notifications WITH CHECK
        ADD CONSTRAINT FK_notifications_company
        FOREIGN KEY (company_id) REFERENCES dbo.udt_companies(id);
GO

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.udt_notifications')
      AND name = 'IX_notifications_company_user_active'
)
    CREATE INDEX IX_notifications_company_user_active
        ON dbo.udt_notifications(company_id, user_id, is_active, created_at DESC);
GO

CREATE OR ALTER TRIGGER dbo.trg_notifications_company_guard
ON dbo.udt_notifications
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted i
        LEFT JOIN dbo.udt_company_info_user ci ON ci.userid = i.user_id
        WHERE i.company_id IS NULL
           OR ci.company_id IS NULL
           OR ci.company_id <> i.company_id
    )
        THROW 53300, 'Notifikasi harus berada pada perusahaan penerima yang sama.', 1;
END;
GO

/* Daftar penerima broadcast hanya memuat karyawan dari PT peminta. */
CREATE OR ALTER PROCEDURE dbo.udp_users_get_for_notification
    @request_user_id VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @company_id INT;
    SELECT @company_id = ci.company_id
    FROM dbo.udt_users u
    INNER JOIN dbo.udt_company_info_user ci ON ci.userid = u.userid
    WHERE u.userid = @request_user_id
      AND u.active = 1
      AND ISNULL(u.deleted, 0) = 0;

    IF @company_id IS NULL
        THROW 53301, 'Akun peminta tidak aktif atau belum terhubung ke perusahaan.', 1;

    SELECT ci.userid, ci.name, ci.employeeID AS employee_number,
           ci.organization AS department, ci.job_position AS position, ci.mail
    FROM dbo.udt_company_info_user ci
    INNER JOIN dbo.udt_users u ON u.userid = ci.userid
    WHERE ci.company_id = @company_id
      AND u.active = 1
      AND ISNULL(u.deleted, 0) = 0
    ORDER BY ci.name;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_notifications_insert
    @user_id VARCHAR(50) = NULL,
    @title NVARCHAR(255),
    @message NVARCHAR(MAX),
    @type NVARCHAR(50),
    @reference_id NVARCHAR(50) = NULL,
    @reference_type NVARCHAR(50) = NULL,
    @is_important BIT = 0,
    @action_text NVARCHAR(100) = NULL,
    @action_url NVARCHAR(500) = NULL,
    @expires_at DATETIME2 = NULL,
    @created_by VARCHAR(50),
    @send_to_all BIT = 0,
    @pdf_file_name NVARCHAR(255) = NULL,
    @pdf_file_path NVARCHAR(500) = NULL,
    @pdf_file_size BIGINT = NULL,
    @pdf_uploaded_by VARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @company_id INT, @can_broadcast BIT = 0;
    SELECT TOP (1)
        @company_id = ci.company_id,
        @can_broadcast = CASE
            WHEN UPPER(ISNULL(u.role, '')) IN ('ADMIN', 'HRD') THEN 1
            WHEN UPPER(ISNULL(ci.organization, '')) LIKE '%HRD%' THEN 1
            WHEN UPPER(ISNULL(ci.organization, '')) LIKE '%DIREKTUR%' THEN 1
            ELSE 0 END
    FROM dbo.udt_users u
    INNER JOIN dbo.udt_company_info_user ci ON ci.userid = u.userid
    INNER JOIN dbo.udt_companies co ON co.id = ci.company_id AND co.is_active = 1
    WHERE u.userid = @created_by
      AND u.active = 1
      AND ISNULL(u.deleted, 0) = 0;

    IF @company_id IS NULL OR @can_broadcast = 0
        THROW 53302, 'Hanya HRD/Admin aktif pada perusahaan yang dapat mengirim broadcast.', 1;

    IF @send_to_all = 0 AND NOT EXISTS
    (
        SELECT 1 FROM dbo.udt_company_info_user
        WHERE userid = @user_id AND company_id = @company_id
    )
        THROW 53303, 'Penerima notifikasi bukan anggota perusahaan Anda.', 1;

    BEGIN TRANSACTION;
    IF @send_to_all = 1
    BEGIN
        INSERT dbo.udt_notifications
        (
            user_id, company_id, title, message, type, reference_id, reference_type,
            is_important, action_text, action_url, expires_at, created_at,
            pdf_file_name, pdf_file_path, pdf_file_size, pdf_uploaded_at, pdf_uploaded_by
        )
        SELECT u.userid, @company_id, @title, @message, @type, @reference_id, @reference_type,
               @is_important, @action_text, @action_url, @expires_at, GETDATE(),
               @pdf_file_name, @pdf_file_path, @pdf_file_size,
               CASE WHEN @pdf_file_name IS NOT NULL THEN GETDATE() END, @pdf_uploaded_by
        FROM dbo.udt_users u
        INNER JOIN dbo.udt_company_info_user ci ON ci.userid = u.userid
        WHERE ci.company_id = @company_id
          AND u.active = 1
          AND ISNULL(u.deleted, 0) = 0;

        SELECT @@ROWCOUNT AS affected_rows,
               'Notifikasi berhasil dikirim ke karyawan perusahaan Anda' AS message;
    END
    ELSE
    BEGIN
        INSERT dbo.udt_notifications
        (
            user_id, company_id, title, message, type, reference_id, reference_type,
            is_important, action_text, action_url, expires_at, created_at,
            pdf_file_name, pdf_file_path, pdf_file_size, pdf_uploaded_at, pdf_uploaded_by
        )
        VALUES
        (
            @user_id, @company_id, @title, @message, @type, @reference_id, @reference_type,
            @is_important, @action_text, @action_url, @expires_at, GETDATE(),
            @pdf_file_name, @pdf_file_path, @pdf_file_size,
            CASE WHEN @pdf_file_name IS NOT NULL THEN GETDATE() END, @pdf_uploaded_by
        );
        SELECT 1 AS affected_rows, 'Notifikasi berhasil dibuat' AS message;
    END;
    COMMIT TRANSACTION;
END;
GO

/* Notifikasi otomatis ke satu user juga mewarisi perusahaan penerima. */
CREATE OR ALTER PROCEDURE dbo.udp_notification_create
    @user_id NVARCHAR(50),
    @title NVARCHAR(255),
    @message NVARCHAR(MAX),
    @type NVARCHAR(50),
    @reference_id NVARCHAR(50) = NULL,
    @reference_type NVARCHAR(50) = NULL,
    @is_important BIT = 0,
    @action_text NVARCHAR(100) = NULL,
    @action_url NVARCHAR(500) = NULL,
    @expires_at DATETIME2 = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @company_id INT, @new_id INT;
    SELECT @company_id = company_id
    FROM dbo.udt_company_info_user
    WHERE userid = @user_id;

    IF @company_id IS NULL
    BEGIN
        SELECT 'Error' AS status, 'Penerima tidak terhubung ke perusahaan aktif.' AS message,
               CAST(NULL AS INT) AS notification_id;
        RETURN;
    END;

    BEGIN TRY
        INSERT dbo.udt_notifications
        (
            user_id, company_id, title, message, type, reference_id, reference_type,
            is_important, action_text, action_url, expires_at
        )
        VALUES
        (
            @user_id, @company_id, @title, @message, @type, @reference_id, @reference_type,
            @is_important, @action_text, @action_url, @expires_at
        );
        SET @new_id = CONVERT(INT, SCOPE_IDENTITY());
        SELECT 'Success' AS status, 'Notifikasi berhasil dibuat' AS message,
               @new_id AS notification_id;
    END TRY
    BEGIN CATCH
        SELECT 'Error' AS status, ERROR_MESSAGE() AS message,
               CAST(NULL AS INT) AS notification_id;
    END CATCH;
END;
GO

/* Verifikasi data yang belum dapat dipetakan dari penerima lama. */
SELECT company_id, COUNT(*) AS total_notifications
FROM dbo.udt_notifications
GROUP BY company_id
ORDER BY company_id;
GO

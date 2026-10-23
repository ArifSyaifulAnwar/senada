/*
  SENADA - Dokumen Profil per perusahaan
  Dokumen personal dimiliki user, tetapi company_id disimpan permanen agar
  dokumen PT A tidak dapat dibaca dari alur PT B.
*/
USE [ABSENSI];
GO
SET XACT_ABORT ON;
GO

IF COL_LENGTH('dbo.udt_file_user', 'company_id') IS NULL
    ALTER TABLE dbo.udt_file_user ADD company_id INT NULL;
GO

UPDATE f SET company_id = ci.company_id
FROM dbo.udt_file_user f
INNER JOIN dbo.udt_company_info_user ci ON ci.userid = f.userid
WHERE f.company_id IS NULL;
GO

IF EXISTS (SELECT 1 FROM dbo.udt_file_user WHERE company_id IS NULL)
    THROW 52800, 'Masih ada dokumen profil tanpa company_id.', 1;
GO

ALTER TABLE dbo.udt_file_user ALTER COLUMN company_id INT NOT NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_file_user_company')
    ALTER TABLE dbo.udt_file_user WITH CHECK
        ADD CONSTRAINT FK_file_user_company FOREIGN KEY(company_id) REFERENCES dbo.udt_companies(id);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.udt_file_user') AND name = 'IX_file_user_company_user_uploaded')
    CREATE INDEX IX_file_user_company_user_uploaded
        ON dbo.udt_file_user(company_id, userid, uploaded_at DESC);
GO

CREATE OR ALTER TRIGGER dbo.trg_file_user_company_guard
ON dbo.udt_file_user
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS
    (
        SELECT 1
        FROM inserted i
        LEFT JOIN dbo.udt_company_info_user ci ON ci.userid = i.userid
        WHERE ci.company_id IS NULL OR ci.company_id <> i.company_id
    )
        THROW 52801, 'Perusahaan dokumen tidak sesuai dengan pemilik akun.', 1;
END;
GO

/* @mail hanya dipertahankan untuk kompatibilitas klien lama, bukan sumber tenant. */
CREATE OR ALTER PROCEDURE dbo.udp_file_user_get_by_user
    @userid VARCHAR(50), @mail VARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @company_id INT;
    SELECT @company_id = ci.company_id FROM dbo.udt_users u
    INNER JOIN dbo.udt_company_info_user ci ON ci.userid = u.userid
    WHERE u.userid = @userid AND u.active = 1 AND ISNULL(u.deleted, 0) = 0
      AND (@mail IS NULL OR LOWER(LTRIM(RTRIM(u.mail))) = LOWER(LTRIM(RTRIM(@mail))));
    IF @company_id IS NULL THROW 52802, 'Akun aktif tidak ditemukan.', 1;

    SELECT id, userid, name, mail, filecategory, description, filetype, uploaded_at
    FROM dbo.udt_file_user
    WHERE userid = @userid AND company_id = @company_id
    ORDER BY uploaded_at DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_file_user_insert
    @userid VARCHAR(50), @name VARCHAR(255), @mail VARCHAR(255) = NULL,
    @filecategory VARCHAR(255), @description TEXT = NULL,
    @filecontent VARBINARY(MAX), @filetype VARCHAR(100) = NULL,
    @ResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON; SET @ResultCode = -1;
    DECLARE @company_id INT, @official_mail VARCHAR(255);
    SELECT @company_id=ci.company_id, @official_mail=u.mail FROM dbo.udt_users u
    INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
    WHERE u.userid=@userid AND u.active=1 AND ISNULL(u.deleted,0)=0
      AND (@mail IS NULL OR LOWER(LTRIM(RTRIM(u.mail)))=LOWER(LTRIM(RTRIM(@mail))));
    IF @company_id IS NULL BEGIN SET @ResultCode=-2; RETURN; END;
    BEGIN TRY
        INSERT dbo.udt_file_user(userid,name,mail,filecategory,description,filecontent,filetype,company_id)
        VALUES(@userid,@name,@official_mail,@filecategory,@description,@filecontent,@filetype,@company_id);
        SET @ResultCode=0;
    END TRY BEGIN CATCH SET @ResultCode=-1; END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_file_user_update_by_id
    @id INT, @userid VARCHAR(50), @mail VARCHAR(255) = NULL, @name VARCHAR(255),
    @filecategory VARCHAR(255), @description TEXT = NULL,
    @filecontent VARBINARY(MAX) = NULL, @filetype VARCHAR(100) = NULL,
    @ResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON; SET @ResultCode=-1;
    DECLARE @company_id INT;
    SELECT @company_id=ci.company_id FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
    WHERE u.userid=@userid AND u.active=1 AND ISNULL(u.deleted,0)=0
      AND (@mail IS NULL OR LOWER(LTRIM(RTRIM(u.mail)))=LOWER(LTRIM(RTRIM(@mail))));
    IF @company_id IS NULL BEGIN SET @ResultCode=-2; RETURN; END;
    BEGIN TRY
      UPDATE dbo.udt_file_user SET name=@name,filecategory=@filecategory,description=@description,
        filetype=ISNULL(@filetype,filetype),filecontent=ISNULL(@filecontent,filecontent)
      WHERE id=@id AND userid=@userid AND company_id=@company_id;
      SET @ResultCode=CASE WHEN @@ROWCOUNT=1 THEN 0 ELSE -2 END;
    END TRY BEGIN CATCH SET @ResultCode=-1; END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_file_user_delete_secure
    @id INT, @userid VARCHAR(50), @mail VARCHAR(255) = NULL, @ResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON; SET @ResultCode=-1;
    DECLARE @company_id INT;
    SELECT @company_id=ci.company_id FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
    WHERE u.userid=@userid AND u.active=1 AND ISNULL(u.deleted,0)=0
      AND (@mail IS NULL OR LOWER(LTRIM(RTRIM(u.mail)))=LOWER(LTRIM(RTRIM(@mail))));
    IF @company_id IS NULL BEGIN SET @ResultCode=-2; RETURN; END;
    BEGIN TRY
      DELETE dbo.udt_file_user WHERE id=@id AND userid=@userid AND company_id=@company_id;
      SET @ResultCode=CASE WHEN @@ROWCOUNT=1 THEN 0 ELSE -2 END;
    END TRY BEGIN CATCH SET @ResultCode=-1; END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_file_user_get_by_id
    @id INT, @userid VARCHAR(50), @mail VARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @company_id INT;
    SELECT @company_id=ci.company_id FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
    WHERE u.userid=@userid AND u.active=1 AND ISNULL(u.deleted,0)=0
      AND (@mail IS NULL OR LOWER(LTRIM(RTRIM(u.mail)))=LOWER(LTRIM(RTRIM(@mail))));
    IF @company_id IS NULL THROW 52803, 'Akun aktif tidak ditemukan.',1;
    SELECT id,userid,name,mail,filecategory,description,filecontent,filetype,uploaded_at
    FROM dbo.udt_file_user WHERE id=@id AND userid=@userid AND company_id=@company_id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_file_user_get_info_by_id
    @id INT, @userid VARCHAR(50), @mail VARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @company_id INT;
    SELECT @company_id=ci.company_id FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
    WHERE u.userid=@userid AND u.active=1 AND ISNULL(u.deleted,0)=0
      AND (@mail IS NULL OR LOWER(LTRIM(RTRIM(u.mail)))=LOWER(LTRIM(RTRIM(@mail))));
    IF @company_id IS NULL THROW 52804, 'Akun aktif tidak ditemukan.',1;
    SELECT id,userid,name,mail,filecategory,description,filetype,uploaded_at,DATALENGTH(filecontent) file_size
    FROM dbo.udt_file_user WHERE id=@id AND userid=@userid AND company_id=@company_id;
END;
GO

/* HRD/Admin hanya membaca dokumen karyawan dari PT yang sama. */
CREATE OR ALTER PROCEDURE dbo.usp_GetAllFilesByCompany_HRD
    @RequestUserId VARCHAR(50), @AccessDenied BIT OUTPUT, @Message VARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON; SET @AccessDenied=0; SET @Message=NULL;
    DECLARE @company_id INT,@has_access BIT=0;
    SELECT TOP(1) @company_id=ci.company_id,
      @has_access=CASE WHEN UPPER(ISNULL(u.role,'')) IN('HRD','ADMIN')
        OR UPPER(ISNULL(ci.organization,'')) LIKE '%HRD%'
        OR UPPER(ISNULL(ci.organization,'')) LIKE '%DIREKTUR%'
        OR UPPER(ISNULL(ci.job_position,'')) LIKE '%DIREKTUR%' THEN 1 ELSE 0 END
    FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
    INNER JOIN dbo.udt_companies c ON c.id=ci.company_id AND c.is_active=1
    WHERE u.userid=@RequestUserId AND u.active=1 AND ISNULL(u.deleted,0)=0;
    IF @company_id IS NULL OR @has_access=0 BEGIN SET @AccessDenied=1; SET @Message='Anda tidak memiliki akses untuk melihat file karyawan lain'; END;
    SELECT f.id Id,f.userid UserId,u.name EmployeeName,ci.job_position JobPosition,ci.organization Organization,
      f.name Name,f.filecategory FileCategory,f.description Description,f.filetype FileType,f.uploaded_at UploadedAt
    FROM dbo.udt_file_user f INNER JOIN dbo.udt_users u ON u.userid=f.userid
    INNER JOIN dbo.udt_company_info_user ci ON ci.userid=f.userid AND ci.company_id=f.company_id
    WHERE @AccessDenied=0 AND f.company_id=@company_id
    ORDER BY f.uploaded_at DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_GetFileContent_HRD
    @RequestUserId VARCHAR(50), @FileId INT, @AccessDenied BIT OUTPUT, @Message VARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON; SET @AccessDenied=0; SET @Message=NULL;
    DECLARE @company_id INT,@has_access BIT=0;
    SELECT TOP(1) @company_id=ci.company_id,
      @has_access=CASE WHEN UPPER(ISNULL(u.role,'')) IN('HRD','ADMIN') OR UPPER(ISNULL(ci.organization,'')) LIKE '%HRD%' OR UPPER(ISNULL(ci.organization,'')) LIKE '%DIREKTUR%' OR UPPER(ISNULL(ci.job_position,'')) LIKE '%DIREKTUR%' THEN 1 ELSE 0 END
    FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
    WHERE u.userid=@RequestUserId AND u.active=1 AND ISNULL(u.deleted,0)=0;
    IF @company_id IS NULL OR @has_access=0 BEGIN
      SET @AccessDenied=1; SET @Message='Anda tidak memiliki akses untuk mengunduh file ini';
      SELECT TOP 0 CAST(NULL AS VARBINARY(MAX)) FileContent,CAST(NULL AS VARCHAR(200)) Name,CAST(NULL AS VARCHAR(100)) FileType; RETURN;
    END;
    IF NOT EXISTS(SELECT 1 FROM dbo.udt_file_user WHERE id=@FileId AND company_id=@company_id) BEGIN
      SET @AccessDenied=1; SET @Message='File tidak ditemukan atau bukan dari perusahaan Anda';
      SELECT TOP 0 CAST(NULL AS VARBINARY(MAX)) FileContent,CAST(NULL AS VARCHAR(200)) Name,CAST(NULL AS VARCHAR(100)) FileType; RETURN;
    END;
    SELECT filecontent FileContent,name Name,filetype FileType FROM dbo.udt_file_user WHERE id=@FileId AND company_id=@company_id;
END;
GO

SELECT company_id,COUNT(*) total_dokumen FROM dbo.udt_file_user GROUP BY company_id ORDER BY company_id;
GO

/*
  SENADA - Isolasi File Saya, Persetujuan, dan Aktivitas Harian per perusahaan

  Jalankan pada ABSENSI setelah migration 016 dan 017.
  Semua company_id transaksi diturunkan dari user aktif; client tidak boleh
  memilih tenant sendiri.
*/
USE [ABSENSI];
GO
SET XACT_ABORT ON;
GO

/* ========================================================================== */
/* 1. FILE SAYA / BERKAS KANTOR                                               */
/* ========================================================================== */
IF COL_LENGTH('dbo.udt_office_file_category', 'company_id') IS NULL
    ALTER TABLE dbo.udt_office_file_category ADD company_id INT NULL;
GO

UPDATE c
SET company_id = ci.company_id
FROM dbo.udt_office_file_category c
INNER JOIN dbo.udt_company_info_user ci ON ci.userid = c.created_by_userid
WHERE c.company_id IS NULL;
GO

IF EXISTS (SELECT 1 FROM dbo.udt_office_file_category WHERE company_id IS NULL)
    THROW 51800, 'Masih ada kategori File Saya tanpa perusahaan.', 1;
GO

ALTER TABLE dbo.udt_office_file_category ALTER COLUMN company_id INT NOT NULL;
GO

IF COL_LENGTH('dbo.udt_office_file', 'company_id') IS NULL
    ALTER TABLE dbo.udt_office_file ADD company_id INT NULL;
GO

UPDATE f
SET company_id = ci.company_id
FROM dbo.udt_office_file f
INNER JOIN dbo.udt_company_info_user ci ON ci.userid = f.uploaded_by_userid
WHERE f.company_id IS NULL;
GO

IF EXISTS (SELECT 1 FROM dbo.udt_office_file WHERE company_id IS NULL)
    THROW 51801, 'Masih ada File Saya tanpa perusahaan.', 1;
GO

ALTER TABLE dbo.udt_office_file ALTER COLUMN company_id INT NOT NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name='FK_office_file_category_company')
    ALTER TABLE dbo.udt_office_file_category WITH CHECK
    ADD CONSTRAINT FK_office_file_category_company FOREIGN KEY(company_id) REFERENCES dbo.udt_companies(id);
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name='FK_office_file_company')
    ALTER TABLE dbo.udt_office_file WITH CHECK
    ADD CONSTRAINT FK_office_file_company FOREIGN KEY(company_id) REFERENCES dbo.udt_companies(id);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.udt_office_file_category') AND name='IX_office_file_category_company_active')
    CREATE INDEX IX_office_file_category_company_active ON dbo.udt_office_file_category(company_id,active,name);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.udt_office_file') AND name='IX_office_file_company_active')
    CREATE INDEX IX_office_file_company_active ON dbo.udt_office_file(company_id,active,created_at DESC);
GO

CREATE OR ALTER PROCEDURE dbo.udp_office_file_category_get_all
    @userid VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @company_id INT;
    SELECT @company_id=company_id FROM dbo.udt_company_info_user WHERE userid=@userid;
    IF @company_id IS NULL THROW 51802, 'User belum terhubung ke perusahaan.', 1;

    SELECT id,name
    FROM dbo.udt_office_file_category
    WHERE company_id=@company_id AND active=1
    ORDER BY name;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_office_file_category_insert
    @name NVARCHAR(100),
    @userid VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @company_id INT;
    SELECT @company_id=ci.company_id
    FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
    WHERE u.userid=@userid AND u.active=1 AND ISNULL(u.deleted,0)=0;
    IF @company_id IS NULL THROW 51803, 'User tidak aktif atau belum terhubung ke perusahaan.', 1;

    DECLARE @existing_id INT;
    SELECT TOP(1) @existing_id=id FROM dbo.udt_office_file_category
    WHERE company_id=@company_id AND active=1
      AND LOWER(LTRIM(RTRIM(name)))=LOWER(LTRIM(RTRIM(@name)));
    IF @existing_id IS NOT NULL BEGIN SELECT @existing_id id; RETURN; END;

    INSERT dbo.udt_office_file_category(name,created_by_userid,company_id)
    VALUES(LTRIM(RTRIM(@name)),@userid,@company_id);
    SELECT CONVERT(INT,SCOPE_IDENTITY()) id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_office_file_category_update
    @id INT,
    @name NVARCHAR(100),
    @userid VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @company_id INT;
    SELECT @company_id=company_id FROM dbo.udt_company_info_user WHERE userid=@userid;
    UPDATE dbo.udt_office_file_category SET name=LTRIM(RTRIM(@name))
    WHERE id=@id AND company_id=@company_id AND active=1;
    IF @@ROWCOUNT<>1 THROW 51804, 'Kategori tidak ditemukan pada perusahaan Anda.', 1;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_office_file_category_deactivate
    @id INT,
    @userid VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @company_id INT;
    SELECT @company_id=company_id FROM dbo.udt_company_info_user WHERE userid=@userid;
    UPDATE dbo.udt_office_file_category SET active=0
    WHERE id=@id AND company_id=@company_id AND active=1;
    IF @@ROWCOUNT<>1 THROW 51805, 'Kategori tidak ditemukan pada perusahaan Anda.', 1;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_office_file_get_all
    @userid VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @company_id INT;
    SELECT @company_id=company_id FROM dbo.udt_company_info_user WHERE userid=@userid;
    IF @company_id IS NULL THROW 51806, 'User belum terhubung ke perusahaan.', 1;

    SELECT id,name,category,description,filetype,filesize,uploaded_by_userid,
           uploaded_by_name,created_at,updated_at
    FROM dbo.udt_office_file
    WHERE company_id=@company_id AND active=1
    ORDER BY created_at DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_office_file_get_content
    @id INT,
    @userid VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @company_id INT;
    SELECT @company_id=company_id FROM dbo.udt_company_info_user WHERE userid=@userid;
    SELECT id,name,filetype,filecontent
    FROM dbo.udt_office_file
    WHERE id=@id AND company_id=@company_id AND active=1;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_office_file_insert
    @name NVARCHAR(255), @category NVARCHAR(100), @description NVARCHAR(1000),
    @filecontent VARBINARY(MAX), @filetype NVARCHAR(100), @filesize BIGINT,
    @uploaded_by_userid VARCHAR(50), @uploaded_by_name NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @company_id INT;
    SELECT @company_id=ci.company_id
    FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
    WHERE u.userid=@uploaded_by_userid AND u.active=1 AND ISNULL(u.deleted,0)=0;
    IF @company_id IS NULL THROW 51807, 'Pengunggah tidak aktif atau belum terhubung ke perusahaan.', 1;

    IF NOT EXISTS(SELECT 1 FROM dbo.udt_office_file_category
                  WHERE company_id=@company_id AND active=1 AND name=@category)
        THROW 51808, 'Kategori tidak tersedia pada perusahaan Anda.', 1;

    INSERT dbo.udt_office_file
      (name,category,description,filecontent,filetype,filesize,uploaded_by_userid,
       uploaded_by_name,company_id)
    VALUES(@name,@category,@description,@filecontent,@filetype,@filesize,
           @uploaded_by_userid,@uploaded_by_name,@company_id);
    SELECT CONVERT(INT,SCOPE_IDENTITY()) id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_office_file_update
    @id INT, @name NVARCHAR(255), @category NVARCHAR(100),
    @description NVARCHAR(1000), @filecontent VARBINARY(MAX)=NULL,
    @filetype NVARCHAR(100)=NULL, @filesize BIGINT=NULL,
    @updated_by_userid VARCHAR(50), @updated_by_name NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @company_id INT;
    SELECT @company_id=company_id FROM dbo.udt_company_info_user WHERE userid=@updated_by_userid;
    IF NOT EXISTS(SELECT 1 FROM dbo.udt_office_file_category
                  WHERE company_id=@company_id AND active=1 AND name=@category)
        THROW 51809, 'Kategori tidak tersedia pada perusahaan Anda.', 1;

    UPDATE dbo.udt_office_file
    SET name=@name,category=@category,description=@description,
        filecontent=ISNULL(@filecontent,filecontent),filetype=ISNULL(@filetype,filetype),
        filesize=ISNULL(@filesize,filesize),updated_at=GETDATE(),
        updated_by_userid=@updated_by_userid,updated_by_name=@updated_by_name
    WHERE id=@id AND company_id=@company_id AND active=1;
    IF @@ROWCOUNT<>1 THROW 51810, 'Berkas tidak ditemukan pada perusahaan Anda.', 1;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_office_file_delete
    @id INT,
    @userid VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @company_id INT;
    SELECT @company_id=company_id FROM dbo.udt_company_info_user WHERE userid=@userid;
    UPDATE dbo.udt_office_file SET active=0,updated_at=GETDATE(),updated_by_userid=@userid
    WHERE id=@id AND company_id=@company_id AND active=1;
    IF @@ROWCOUNT<>1 THROW 51811, 'Berkas tidak ditemukan pada perusahaan Anda.', 1;
END;
GO

/* ========================================================================== */
/* 2. AKTIVITAS HARIAN                                                        */
/* ========================================================================== */
IF COL_LENGTH('dbo.udt_daily_activity', 'company_id') IS NULL
    ALTER TABLE dbo.udt_daily_activity ADD company_id INT NULL;
GO

UPDATE a SET company_id=ci.company_id
FROM dbo.udt_daily_activity a
INNER JOIN dbo.udt_company_info_user ci ON ci.userid=a.userid
WHERE a.company_id IS NULL;
GO

IF EXISTS(SELECT 1 FROM dbo.udt_daily_activity WHERE company_id IS NULL)
    THROW 51820, 'Masih ada aktivitas harian tanpa perusahaan.', 1;
GO

ALTER TABLE dbo.udt_daily_activity ALTER COLUMN company_id INT NOT NULL;
GO

IF COL_LENGTH('dbo.udt_daily_activity_category', 'company_id') IS NULL
    ALTER TABLE dbo.udt_daily_activity_category ADD company_id INT NULL;
GO

/* Kategori lama tetap NULL sebagai template global; PT boleh punya override. */
IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_daily_activity_company')
    ALTER TABLE dbo.udt_daily_activity WITH CHECK
    ADD CONSTRAINT FK_daily_activity_company FOREIGN KEY(company_id) REFERENCES dbo.udt_companies(id);
GO

IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_daily_activity_category_company')
    ALTER TABLE dbo.udt_daily_activity_category WITH CHECK
    ADD CONSTRAINT FK_daily_activity_category_company FOREIGN KEY(company_id) REFERENCES dbo.udt_companies(id);
GO

IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.udt_daily_activity') AND name='IX_daily_activity_company_date')
    CREATE INDEX IX_daily_activity_company_date ON dbo.udt_daily_activity(company_id,activity_date DESC,userid);
GO

CREATE OR ALTER TRIGGER dbo.trg_daily_activity_company_guard
ON dbo.udt_daily_activity
AFTER INSERT,UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS(
        SELECT 1 FROM inserted i
        LEFT JOIN dbo.udt_company_info_user ci ON ci.userid=i.userid
        WHERE ci.company_id IS NULL OR ci.company_id<>i.company_id)
        THROW 51821, 'Perusahaan aktivitas tidak sesuai dengan pemilik akun.', 1;
    IF EXISTS(
        SELECT 1 FROM inserted i
        LEFT JOIN dbo.udt_office_locations o ON o.id=i.office_location_id
        WHERE i.office_location_id IS NOT NULL
          AND (o.company_id IS NULL OR o.company_id<>i.company_id))
        THROW 51822, 'Lokasi aktivitas berasal dari perusahaan lain.', 1;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_GetDailyActivityCategories
    @UserId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @company_id INT;
    SELECT @company_id=company_id FROM dbo.udt_company_info_user WHERE userid=@UserId;
    IF @company_id IS NULL THROW 51823, 'User belum terhubung ke perusahaan.', 1;

    ;WITH ranked AS(
      SELECT id,category_key,label,icon_name,sort_order,
             ROW_NUMBER() OVER(PARTITION BY LOWER(category_key)
                               ORDER BY CASE WHEN company_id=@company_id THEN 0 ELSE 1 END,id) rn
      FROM dbo.udt_daily_activity_category
      WHERE is_active=1 AND (company_id=@company_id OR company_id IS NULL)
    )
    SELECT id,category_key,label,icon_name,sort_order FROM ranked WHERE rn=1 ORDER BY sort_order;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_CreateDailyActivity
    @UserId VARCHAR(50), @ActivityDate DATE, @CategoryId INT,
    @Description TEXT, @OfficeLocationId INT=NULL, @LocationText VARCHAR(200)=NULL,
    @StartTime TIME=NULL, @EndTime TIME=NULL, @NewActivityId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @company_id INT;
    SELECT @company_id=ci.company_id
    FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
    WHERE u.userid=@UserId AND u.active=1 AND ISNULL(u.deleted,0)=0;
    IF @company_id IS NULL THROW 51824, 'User tidak aktif atau belum terhubung ke perusahaan.', 1;
    IF NOT EXISTS(SELECT 1 FROM dbo.udt_daily_activity_category
                  WHERE id=@CategoryId AND is_active=1 AND (company_id=@company_id OR company_id IS NULL))
        THROW 51825, 'Kategori aktivitas tidak tersedia pada perusahaan Anda.', 1;
    IF @OfficeLocationId IS NOT NULL AND NOT EXISTS(
        SELECT 1 FROM dbo.udt_office_locations
        WHERE id=@OfficeLocationId AND company_id=@company_id AND is_active=1)
        THROW 51826, 'Lokasi kantor tidak tersedia pada perusahaan Anda.', 1;

    INSERT dbo.udt_daily_activity
      (userid,company_id,activity_date,category_id,description,office_location_id,
       location_text,start_time,end_time,status,created_at,updated_at)
    VALUES(@UserId,@company_id,@ActivityDate,@CategoryId,@Description,@OfficeLocationId,
           @LocationText,@StartTime,@EndTime,'pending',GETDATE(),GETDATE());
    SET @NewActivityId=CONVERT(INT,SCOPE_IDENTITY());
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_GetDailyActivitiesByUser
    @UserId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @company_id INT;
    SELECT @company_id=company_id FROM dbo.udt_company_info_user WHERE userid=@UserId;

    SELECT a.id,a.activity_date,a.description,a.category_id,c.category_key,
           c.label category_label,c.icon_name,a.office_location_id,ol.office_name,
           a.location_text,a.start_time,a.end_time,a.status,a.review_notes,a.created_at
    FROM dbo.udt_daily_activity a
    INNER JOIN dbo.udt_daily_activity_category c ON c.id=a.category_id
    LEFT JOIN dbo.udt_office_locations ol ON ol.id=a.office_location_id AND ol.company_id=a.company_id
    WHERE a.userid=@UserId AND a.company_id=@company_id
    ORDER BY a.activity_date DESC,a.created_at DESC;

    SELECT att.id,att.activity_id,att.name,att.filetype,att.uploaded_at
    FROM dbo.udt_daily_activity_attachment att
    INNER JOIN dbo.udt_daily_activity a ON a.id=att.activity_id
    WHERE a.userid=@UserId AND a.company_id=@company_id
    ORDER BY att.uploaded_at;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_UpdateDailyActivity
    @ActivityId INT,@UserId VARCHAR(50),@ActivityDate DATE,@CategoryId INT,
    @Description VARCHAR(MAX),@OfficeLocationId INT=NULL,@LocationText VARCHAR(200)=NULL,
    @StartTime TIME=NULL,@EndTime TIME=NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @company_id INT;
    SELECT @company_id=ci.company_id FROM dbo.udt_users u
    INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
    WHERE u.userid=@UserId AND u.active=1 AND ISNULL(u.deleted,0)=0;
    IF @company_id IS NULL THROW 51827, 'User tidak aktif atau belum terhubung ke perusahaan.', 1;
    IF NULLIF(LTRIM(RTRIM(@Description)),'') IS NULL THROW 51828, 'Deskripsi wajib diisi.', 1;
    IF @ActivityDate IS NULL OR @ActivityDate>CONVERT(DATE,GETDATE()) THROW 51829, 'Tanggal tidak valid.', 1;
    IF NOT EXISTS(SELECT 1 FROM dbo.udt_daily_activity_category
                  WHERE id=@CategoryId AND is_active=1 AND (company_id=@company_id OR company_id IS NULL))
        THROW 51830, 'Kategori tidak tersedia pada perusahaan Anda.', 1;
    IF @OfficeLocationId IS NOT NULL AND NOT EXISTS(SELECT 1 FROM dbo.udt_office_locations
                  WHERE id=@OfficeLocationId AND company_id=@company_id AND is_active=1)
        THROW 51831, 'Lokasi tidak tersedia pada perusahaan Anda.', 1;
    IF (@StartTime IS NULL AND @EndTime IS NOT NULL) OR (@StartTime IS NOT NULL AND @EndTime IS NULL)
       OR (@StartTime IS NOT NULL AND @EndTime<=@StartTime)
        THROW 51832, 'Jam mulai dan selesai tidak valid.', 1;

    UPDATE dbo.udt_daily_activity
    SET activity_date=@ActivityDate,category_id=@CategoryId,description=LTRIM(RTRIM(@Description)),
        office_location_id=@OfficeLocationId,location_text=NULLIF(LTRIM(RTRIM(@LocationText)),''),
        start_time=@StartTime,end_time=@EndTime,updated_at=GETDATE()
    WHERE id=@ActivityId AND userid=@UserId AND company_id=@company_id;
    IF @@ROWCOUNT<>1 THROW 51833, 'Aktivitas tidak ditemukan atau bukan milik user.', 1;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_GetDailyActivityAttachmentContent_HRD
    @RequestUserId VARCHAR(50),@AttachmentId INT,@AccessDenied BIT OUTPUT,@Message VARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @AccessDenied=0; SET @Message=NULL;
    DECLARE @company_id INT,@has_access BIT=0;
    SELECT TOP(1) @company_id=ci.company_id,
      @has_access=CASE WHEN UPPER(LTRIM(RTRIM(ISNULL(u.role,'')))) IN('HRD','ADMIN')
        OR UPPER(ISNULL(ci.organization,'')) LIKE '%HRD%'
        OR UPPER(ISNULL(ci.organization,'')) LIKE '%DIREKTUR%'
        OR UPPER(ISNULL(ci.job_position,'')) LIKE '%DIREKTUR%' THEN 1 ELSE 0 END
    FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
    WHERE u.userid=@RequestUserId AND u.active=1 AND ISNULL(u.deleted,0)=0;

    IF @company_id IS NULL OR @has_access=0 BEGIN
      SET @AccessDenied=1; SET @Message='Anda tidak memiliki akses untuk mengunduh file ini';
      SELECT TOP 0 CAST(NULL AS VARBINARY(MAX)) FileContent,CAST(NULL AS VARCHAR(255)) Name,CAST(NULL AS VARCHAR(100)) FileType;
      RETURN;
    END;

    SELECT att.filecontent FileContent,att.name Name,att.filetype FileType
    FROM dbo.udt_daily_activity_attachment att
    INNER JOIN dbo.udt_daily_activity a ON a.id=att.activity_id
    WHERE att.id=@AttachmentId AND a.company_id=@company_id;

    IF @@ROWCOUNT=0 BEGIN SET @AccessDenied=1; SET @Message='File tidak ditemukan atau bukan dari perusahaan Anda'; END;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_GetAllDailyActivitiesByCompany_HRD
    @RequestUserId VARCHAR(50),@AccessDenied BIT OUTPUT,@Message VARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON; SET @AccessDenied=0; SET @Message=NULL;
    DECLARE @company_id INT,@has_access BIT=0;
    SELECT TOP(1) @company_id=ci.company_id,
      @has_access=CASE WHEN UPPER(LTRIM(RTRIM(ISNULL(u.role,'')))) IN('HRD','ADMIN')
        OR UPPER(ISNULL(ci.organization,'')) LIKE '%HRD%'
        OR UPPER(ISNULL(ci.organization,'')) LIKE '%DIREKTUR%'
        OR UPPER(ISNULL(ci.job_position,'')) LIKE '%DIREKTUR%' THEN 1 ELSE 0 END
    FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
    INNER JOIN dbo.udt_companies co ON co.id=ci.company_id AND co.is_active=1
    WHERE u.userid=@RequestUserId AND u.active=1 AND ISNULL(u.deleted,0)=0;
    IF @company_id IS NULL OR @has_access=0 BEGIN
      SET @AccessDenied=1; SET @Message='Anda tidak memiliki akses untuk melihat aktivitas karyawan lain';
    END;

    SELECT a.id Id,a.userid UserId,u.name EmployeeName,ci.job_position JobPosition,
      ci.organization Organization,a.activity_date ActivityDate,a.description Description,
      a.category_id CategoryId,cat.category_key CategoryKey,cat.label CategoryLabel,
      cat.icon_name IconName,a.office_location_id OfficeLocationId,ol.office_name OfficeName,
      a.location_text LocationText,a.start_time StartTime,a.end_time EndTime,a.status Status,
      a.review_notes ReviewNotes,a.created_at CreatedAt
    FROM dbo.udt_daily_activity a
    INNER JOIN dbo.udt_users u ON u.userid=a.userid AND u.active=1 AND ISNULL(u.deleted,0)=0
    INNER JOIN dbo.udt_company_info_user ci ON ci.userid=a.userid AND ci.company_id=a.company_id
    INNER JOIN dbo.udt_daily_activity_category cat ON cat.id=a.category_id
    LEFT JOIN dbo.udt_office_locations ol ON ol.id=a.office_location_id AND ol.company_id=a.company_id
    WHERE @AccessDenied=0 AND a.company_id=@company_id
    ORDER BY a.activity_date DESC,a.created_at DESC;

    SELECT att.id Id,att.activity_id ActivityId,att.name Name,att.filetype FileType,att.uploaded_at UploadedAt
    FROM dbo.udt_daily_activity_attachment att
    INNER JOIN dbo.udt_daily_activity a ON a.id=att.activity_id
    WHERE @AccessDenied=0 AND a.company_id=@company_id
    ORDER BY att.uploaded_at;
END;
GO

/* ========================================================================== */
/* 3. HALAMAN PERSETUJUAN: ASSET DAN INVENTARIS                              */
/* ========================================================================== */
IF COL_LENGTH('dbo.udt_asset_items','company_id') IS NULL ALTER TABLE dbo.udt_asset_items ADD company_id INT NULL;
IF COL_LENGTH('dbo.udt_asset_requests','company_id') IS NULL ALTER TABLE dbo.udt_asset_requests ADD company_id INT NULL;
IF COL_LENGTH('dbo.udt_inventory_items','company_id') IS NULL ALTER TABLE dbo.udt_inventory_items ADD company_id INT NULL;
IF COL_LENGTH('dbo.udt_inventory_requests','company_id') IS NULL ALTER TABLE dbo.udt_inventory_requests ADD company_id INT NULL;
GO

UPDATE i SET company_id=c.id FROM dbo.udt_asset_items i INNER JOIN dbo.udt_companies c
 ON LOWER(LTRIM(RTRIM(c.company_name)))=LOWER(LTRIM(RTRIM(i.company_name))) WHERE i.company_id IS NULL;
UPDATE r SET company_id=ci.company_id FROM dbo.udt_asset_requests r INNER JOIN dbo.udt_company_info_user ci ON ci.userid=r.userid WHERE r.company_id IS NULL;
UPDATE i SET company_id=c.id FROM dbo.udt_inventory_items i INNER JOIN dbo.udt_companies c
 ON LOWER(LTRIM(RTRIM(c.company_name)))=LOWER(LTRIM(RTRIM(i.company_name))) WHERE i.company_id IS NULL;
UPDATE r SET company_id=ci.company_id FROM dbo.udt_inventory_requests r INNER JOIN dbo.udt_company_info_user ci ON ci.userid=r.userid WHERE r.company_id IS NULL;
GO

IF EXISTS(SELECT 1 FROM dbo.udt_asset_items WHERE company_id IS NULL) OR
   EXISTS(SELECT 1 FROM dbo.udt_asset_requests WHERE company_id IS NULL) OR
   EXISTS(SELECT 1 FROM dbo.udt_inventory_items WHERE company_id IS NULL) OR
   EXISTS(SELECT 1 FROM dbo.udt_inventory_requests WHERE company_id IS NULL)
    THROW 51840, 'Masih ada data asset/inventaris tanpa perusahaan.', 1;
GO

IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_asset_items_company')
 ALTER TABLE dbo.udt_asset_items WITH CHECK ADD CONSTRAINT FK_asset_items_company FOREIGN KEY(company_id) REFERENCES dbo.udt_companies(id);
IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_asset_requests_company')
 ALTER TABLE dbo.udt_asset_requests WITH CHECK ADD CONSTRAINT FK_asset_requests_company FOREIGN KEY(company_id) REFERENCES dbo.udt_companies(id);
IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_inventory_items_company')
 ALTER TABLE dbo.udt_inventory_items WITH CHECK ADD CONSTRAINT FK_inventory_items_company FOREIGN KEY(company_id) REFERENCES dbo.udt_companies(id);
IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_inventory_requests_company')
 ALTER TABLE dbo.udt_inventory_requests WITH CHECK ADD CONSTRAINT FK_inventory_requests_company FOREIGN KEY(company_id) REFERENCES dbo.udt_companies(id);
GO

IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.udt_asset_requests') AND name='IX_asset_requests_company_status')
 CREATE INDEX IX_asset_requests_company_status ON dbo.udt_asset_requests(company_id,status,created_at);
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.udt_inventory_requests') AND name='IX_inventory_requests_company_status')
 CREATE INDEX IX_inventory_requests_company_status ON dbo.udt_inventory_requests(company_id,status,created_at);
GO

/* Item legacy masih menerima company_name; guard menerjemahkannya ke ID resmi. */
CREATE OR ALTER TRIGGER dbo.trg_asset_item_company_guard ON dbo.udt_asset_items AFTER INSERT,UPDATE AS
BEGIN
 SET NOCOUNT ON;
 UPDATE ai SET company_id=c.id FROM dbo.udt_asset_items ai INNER JOIN inserted i ON i.id=ai.id
 INNER JOIN dbo.udt_companies c ON LOWER(LTRIM(RTRIM(c.company_name)))=LOWER(LTRIM(RTRIM(ai.company_name)));
 IF EXISTS(SELECT 1 FROM inserted i INNER JOIN dbo.udt_asset_items ai ON ai.id=i.id
   LEFT JOIN dbo.udt_companies c ON c.id=ai.company_id
   WHERE ai.company_id IS NULL OR c.id IS NULL OR LOWER(LTRIM(RTRIM(c.company_name)))<>LOWER(LTRIM(RTRIM(ai.company_name))))
   THROW 51844,'Perusahaan item asset tidak valid.',1;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_inventory_item_company_guard ON dbo.udt_inventory_items AFTER INSERT,UPDATE AS
BEGIN
 SET NOCOUNT ON;
 UPDATE ii SET company_id=c.id FROM dbo.udt_inventory_items ii INNER JOIN inserted i ON i.id=ii.id
 INNER JOIN dbo.udt_companies c ON LOWER(LTRIM(RTRIM(c.company_name)))=LOWER(LTRIM(RTRIM(ii.company_name)));
 IF EXISTS(SELECT 1 FROM inserted i INNER JOIN dbo.udt_inventory_items ii ON ii.id=i.id
   LEFT JOIN dbo.udt_companies c ON c.id=ii.company_id
   WHERE ii.company_id IS NULL OR c.id IS NULL OR LOWER(LTRIM(RTRIM(c.company_name)))<>LOWER(LTRIM(RTRIM(ii.company_name))))
   THROW 51845,'Perusahaan item inventaris tidak valid.',1;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_asset_request_company_guard ON dbo.udt_asset_requests AFTER INSERT,UPDATE AS
BEGIN
 SET NOCOUNT ON;
 UPDATE r SET company_id=ci.company_id FROM dbo.udt_asset_requests r INNER JOIN inserted i ON i.id=r.id
 INNER JOIN dbo.udt_company_info_user ci ON ci.userid=i.userid WHERE r.company_id IS NULL;
 IF EXISTS(SELECT 1 FROM inserted i INNER JOIN dbo.udt_asset_requests r ON r.id=i.id
   INNER JOIN dbo.udt_company_info_user ci ON ci.userid=r.userid
   INNER JOIN dbo.udt_asset_items ai ON ai.id=r.asset_item_id
   WHERE ISNULL(r.company_id,-1)<>ci.company_id OR ISNULL(ai.company_id,-1)<>ci.company_id)
   THROW 51841,'Pengajuan asset harus berada dalam perusahaan yang sama.',1;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_inventory_request_company_guard ON dbo.udt_inventory_requests AFTER INSERT,UPDATE AS
BEGIN
 SET NOCOUNT ON;
 UPDATE r SET company_id=ci.company_id FROM dbo.udt_inventory_requests r INNER JOIN inserted i ON i.id=r.id
 INNER JOIN dbo.udt_company_info_user ci ON ci.userid=i.userid WHERE r.company_id IS NULL;
 IF EXISTS(SELECT 1 FROM inserted i INNER JOIN dbo.udt_inventory_requests r ON r.id=i.id
   INNER JOIN dbo.udt_company_info_user ci ON ci.userid=r.userid
   INNER JOIN dbo.udt_inventory_items ii ON ii.id=r.inventory_item_id
   WHERE ISNULL(r.company_id,-1)<>ci.company_id OR ISNULL(ii.company_id,-1)<>ci.company_id)
   THROW 51842,'Pengajuan inventaris harus berada dalam perusahaan yang sama.',1;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_asset_request_get_pending @hrd_userid VARCHAR(50) AS
BEGIN
 SET NOCOUNT ON; DECLARE @company_id INT,@allowed BIT=0;
 SELECT TOP(1) @company_id=ci.company_id,@allowed=CASE WHEN UPPER(ISNULL(ci.organization,'')) LIKE '%HRD%'
  AND (UPPER(ISNULL(ci.job_position,'')) LIKE '%HEAD%' OR UPPER(ISNULL(ci.job_level,''))='HEAD') THEN 1 ELSE 0 END
 FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
 WHERE u.userid=@hrd_userid AND u.active=1 AND ISNULL(u.deleted,0)=0;

 SELECT r.id,r.userid,u.name user_name,ci.job_position user_job,r.asset_item_id,
  ai.nama_barang,ai.stok stok_tersedia,r.kategori,r.jumlah,r.catatan,r.status,
  r.created_at tanggal_pengajuan,DATEDIFF(DAY,r.created_at,GETDATE()) days_waiting
 FROM dbo.udt_asset_requests r
 INNER JOIN dbo.udt_asset_items ai ON ai.id=r.asset_item_id AND ai.company_id=r.company_id
 INNER JOIN dbo.udt_company_info_user ci ON ci.userid=r.userid AND ci.company_id=r.company_id
 LEFT JOIN dbo.udt_users u ON u.userid=r.userid
 WHERE @allowed=1 AND r.company_id=@company_id AND r.status='Pending'
 ORDER BY r.created_at;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_asset_request_get_pending_count @hrd_userid VARCHAR(50) AS
BEGIN
 SET NOCOUNT ON; DECLARE @company_id INT,@allowed BIT=0;
 SELECT TOP(1) @company_id=ci.company_id,@allowed=CASE WHEN UPPER(ISNULL(ci.organization,'')) LIKE '%HRD%'
  AND (UPPER(ISNULL(ci.job_position,'')) LIKE '%HEAD%' OR UPPER(ISNULL(ci.job_level,''))='HEAD') THEN 1 ELSE 0 END
 FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
 WHERE u.userid=@hrd_userid AND u.active=1 AND ISNULL(u.deleted,0)=0;
 SELECT COUNT(*) pending_count FROM dbo.udt_asset_requests
 WHERE @allowed=1 AND company_id=@company_id AND status='Pending';
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_asset_request_review
 @id INT,@hrd_userid VARCHAR(50),@status NVARCHAR(20),@rejection_reason NVARCHAR(500)=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @status NOT IN('Approved','Rejected') BEGIN SELECT 0 success,N'Status tidak valid.' message; RETURN; END;
 DECLARE @company_id INT,@item_id INT,@qty INT,@current NVARCHAR(20);
 SELECT TOP(1) @company_id=ci.company_id FROM dbo.udt_users u
 INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
 WHERE u.userid=@hrd_userid AND u.active=1 AND ISNULL(u.deleted,0)=0
 AND UPPER(ISNULL(ci.organization,'')) LIKE '%HRD%'
 AND (UPPER(ISNULL(ci.job_position,'')) LIKE '%HEAD%' OR UPPER(ISNULL(ci.job_level,''))='HEAD');
 IF @company_id IS NULL BEGIN SELECT 0 success,N'Hanya Head HRD aktif yang dapat memproses pengajuan asset.' message; RETURN; END;
 SELECT @item_id=asset_item_id,@qty=jumlah,@current=status FROM dbo.udt_asset_requests WITH(UPDLOCK,ROWLOCK)
 WHERE id=@id AND company_id=@company_id;
 IF @current IS NULL BEGIN SELECT 0 success,N'Pengajuan tidak ditemukan pada perusahaan Anda.' message; RETURN; END;
 IF @current<>'Pending' BEGIN SELECT 0 success,N'Pengajuan sudah diproses sebelumnya.' message; RETURN; END;
 BEGIN TRY
  BEGIN TRANSACTION;
  IF @status='Approved' BEGIN
   UPDATE dbo.udt_asset_items SET stok=stok-@qty,updated_at=GETDATE()
   WHERE id=@item_id AND company_id=@company_id AND stok>=@qty;
   IF @@ROWCOUNT<>1 THROW 51843,'Stok asset tidak mencukupi.',1;
  END;
  UPDATE dbo.udt_asset_requests SET status=@status,approved_by=@hrd_userid,approved_at=GETDATE(),
   rejection_reason=CASE WHEN @status='Rejected' THEN @rejection_reason ELSE NULL END,updated_at=GETDATE()
  WHERE id=@id AND company_id=@company_id AND status='Pending';
  COMMIT; SELECT 1 success,CASE WHEN @status='Approved' THEN N'Pengajuan disetujui.' ELSE N'Pengajuan ditolak.' END message;
 END TRY BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; SELECT 0 success,N'Terjadi kesalahan: '+ERROR_MESSAGE() message; END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_inventory_request_get_pending @CallerUserId VARCHAR(50) AS
BEGIN
 SET NOCOUNT ON; DECLARE @company_id INT,@allowed BIT=0;
 SELECT TOP(1) @company_id=ci.company_id,@allowed=CASE WHEN UPPER(ISNULL(ci.organization,'')) LIKE '%HRD%'
  AND (UPPER(ISNULL(ci.job_position,'')) LIKE '%HEAD%' OR UPPER(ISNULL(ci.job_level,''))='HEAD') THEN 1 ELSE 0 END
 FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
 WHERE u.userid=@CallerUserId AND u.active=1 AND ISNULL(u.deleted,0)=0;
 SELECT r.id,r.inventory_item_id,i.kode_aset,i.nama_barang,i.kategori,r.userid,u.name user_name,
  ci.job_position user_job,r.tanggal_pinjam,r.tanggal_rencana_kembali,r.catatan,r.status,
  r.reviewed_by,r.reviewed_at,r.rejection_reason,r.created_at
 FROM dbo.udt_inventory_requests r
 INNER JOIN dbo.udt_inventory_items i ON i.id=r.inventory_item_id AND i.company_id=r.company_id
 INNER JOIN dbo.udt_company_info_user ci ON ci.userid=r.userid AND ci.company_id=r.company_id
 LEFT JOIN dbo.udt_users u ON u.userid=r.userid
 WHERE @allowed=1 AND r.company_id=@company_id AND r.status='Pending'
 ORDER BY r.created_at;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_inventory_request_review
 @id INT,@reviewed_by VARCHAR(50),@status NVARCHAR(20),@rejection_reason NVARCHAR(500)=NULL
AS
BEGIN
 SET NOCOUNT ON;
 IF @status NOT IN('Approved','Rejected') BEGIN SELECT 0 success,N'Status harus Approved atau Rejected.' message; RETURN; END;
 DECLARE @company_id INT,@item_id INT,@requester VARCHAR(50),@current NVARCHAR(20),@kategori NVARCHAR(100),@catatan NVARCHAR(500);
 SELECT TOP(1) @company_id=ci.company_id FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
 WHERE u.userid=@reviewed_by AND u.active=1 AND ISNULL(u.deleted,0)=0
 AND UPPER(ISNULL(ci.organization,'')) LIKE '%HRD%'
 AND (UPPER(ISNULL(ci.job_position,'')) LIKE '%HEAD%' OR UPPER(ISNULL(ci.job_level,''))='HEAD');
 IF @company_id IS NULL BEGIN SELECT 0 success,N'Hanya Head HRD aktif yang dapat memproses inventaris.' message; RETURN; END;
 SELECT @item_id=inventory_item_id,@requester=userid,@current=status,@catatan=catatan
 FROM dbo.udt_inventory_requests WHERE id=@id AND company_id=@company_id;
 IF @item_id IS NULL BEGIN SELECT 0 success,N'Pengajuan tidak ditemukan pada perusahaan Anda.' message; RETURN; END;
 IF @current<>'Pending' BEGIN SELECT 0 success,N'Pengajuan sudah diproses sebelumnya.' message; RETURN; END;
 IF @status='Rejected' BEGIN
  UPDATE dbo.udt_inventory_requests SET status='Rejected',reviewed_by=@reviewed_by,reviewed_at=GETDATE(),rejection_reason=@rejection_reason
  WHERE id=@id AND company_id=@company_id AND status='Pending';
  SELECT 1 success,N'Pengajuan berhasil ditolak.' message; RETURN;
 END;
 SELECT @kategori=kategori FROM dbo.udt_inventory_items WHERE id=@item_id AND company_id=@company_id;
 DECLARE @admins TABLE(userid VARCHAR(50),name NVARCHAR(200),job_position NVARCHAR(200),organization NVARCHAR(200));
 INSERT @admins EXEC dbo.udp_inventory_get_auto_admin_inventaris @userid=@requester,@kategori=@kategori;
 DECLARE @admin VARCHAR(50); SELECT TOP(1) @admin=userid FROM @admins;
 IF @admin IS NULL OR NOT EXISTS(SELECT 1 FROM dbo.udt_company_info_user WHERE userid=@admin AND company_id=@company_id)
 BEGIN SELECT 0 success,N'Admin Inventaris satu perusahaan belum diatur.' message; RETURN; END;
 DECLARE @assign TABLE(success INT,message NVARCHAR(500));
 INSERT @assign EXEC dbo.udp_inventory_assign @inventory_item_id=@item_id,@penanggung_jawab_userid=@requester,
  @admin_inventaris_userid=@admin,@catatan=@catatan,@userid=@reviewed_by;
 IF ISNULL((SELECT TOP(1) success FROM @assign),0)<>1 BEGIN SELECT 0 success,ISNULL((SELECT TOP(1) message FROM @assign),N'Gagal menyerahkan barang.') message; RETURN; END;
 UPDATE dbo.udt_inventory_requests SET status='Approved',reviewed_by=@reviewed_by,reviewed_at=GETDATE()
 WHERE id=@id AND company_id=@company_id AND status='Pending';
 SELECT 1 success,N'Pengajuan berhasil disetujui dan barang diserahkan.' message;
END;
GO

/* Verifikasi */
SELECT 'office_file' entity,company_id,COUNT(*) total FROM dbo.udt_office_file GROUP BY company_id
UNION ALL SELECT 'office_category',company_id,COUNT(*) FROM dbo.udt_office_file_category GROUP BY company_id
UNION ALL SELECT 'daily_activity',company_id,COUNT(*) FROM dbo.udt_daily_activity GROUP BY company_id
UNION ALL SELECT 'asset_request',company_id,COUNT(*) FROM dbo.udt_asset_requests GROUP BY company_id
UNION ALL SELECT 'inventory_request',company_id,COUNT(*) FROM dbo.udt_inventory_requests GROUP BY company_id;
GO

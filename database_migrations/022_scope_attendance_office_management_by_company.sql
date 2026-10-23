/*
  SENADA - Lokasi kantor dan konfigurasi absensi per perusahaan

  Dampak:
  - lokasi/radius kantor PT A tidak dapat dilihat, diubah, atau dipakai PT B;
  - HRD/Admin mengelola lokasi milik PT sendiri saja;
  - daftar lokasi pada halaman absen tetap berasal dari perusahaan akun login;
  - verifikasi wajah tetap menentukan kantor/radius di SQL Server, bukan dari
    data yang dikirim Flutter.

  Jalankan setelah 014_scope_live_attendance_office_by_company.sql.
*/
USE [ABSENSI];
GO
SET XACT_ABORT ON;
GO

IF EXISTS (SELECT 1 FROM dbo.udt_office_locations WHERE company_id IS NULL)
    THROW 52200, 'Masih ada lokasi kantor tanpa company_id. Jalankan migration 014 dan perbaiki data terlebih dahulu.', 1;
GO

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.udt_office_locations')
      AND name = 'IX_office_locations_company_active_name'
)
    CREATE INDEX IX_office_locations_company_active_name
        ON dbo.udt_office_locations(company_id, is_active, office_name);
GO

/* Seluruh procedure pengelolaan memakai user peminta sebagai sumber tenant. */
CREATE OR ALTER PROCEDURE dbo.udp_office_locations_getall
    @request_user_id VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @company_id INT, @can_manage BIT = 0;
    SELECT TOP (1)
        @company_id = ci.company_id,
        @can_manage = CASE
            WHEN UPPER(LTRIM(RTRIM(ISNULL(u.role, '')))) IN ('ADMIN', 'HRD') THEN 1
            WHEN UPPER(ISNULL(ci.organization, '')) LIKE '%HRD%' THEN 1
            WHEN UPPER(ISNULL(ci.organization, '')) LIKE '%DIREKTUR%' THEN 1
            WHEN UPPER(ISNULL(ci.job_position, '')) LIKE '%DIREKTUR%' THEN 1
            ELSE 0 END
    FROM dbo.udt_users u
    INNER JOIN dbo.udt_company_info_user ci ON ci.userid = u.userid
    INNER JOIN dbo.udt_companies c ON c.id = ci.company_id AND c.is_active = 1
    WHERE u.userid = @request_user_id
      AND u.active = 1
      AND ISNULL(u.deleted, 0) = 0;

    IF @company_id IS NULL OR @can_manage = 0
        THROW 52201, 'Anda tidak memiliki akses mengelola lokasi kantor perusahaan.', 1;

    SELECT id, office_name, latitude, longitude, radius_meters, is_active, created_at,
           CASE WHEN ISNULL(is_active, 0) = 1 THEN 'Aktif' ELSE 'Tidak Aktif' END AS status_text
    FROM dbo.udt_office_locations
    WHERE company_id = @company_id
    ORDER BY is_active DESC, office_name, id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_office_locations_getbyid
    @id INT,
    @request_user_id VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @company_id INT, @can_manage BIT = 0;
    SELECT TOP (1) @company_id = ci.company_id,
        @can_manage = CASE WHEN UPPER(ISNULL(u.role,'')) IN ('ADMIN','HRD')
              OR UPPER(ISNULL(ci.organization,'')) LIKE '%HRD%'
              OR UPPER(ISNULL(ci.organization,'')) LIKE '%DIREKTUR%'
              OR UPPER(ISNULL(ci.job_position,'')) LIKE '%DIREKTUR%' THEN 1 ELSE 0 END
    FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
    WHERE u.userid=@request_user_id AND u.active=1 AND ISNULL(u.deleted,0)=0;
    IF @company_id IS NULL OR @can_manage=0 THROW 52202, 'Anda tidak memiliki akses lokasi kantor perusahaan.', 1;

    SELECT id,office_name,latitude,longitude,radius_meters,is_active,created_at,
           CASE WHEN ISNULL(is_active,0)=1 THEN 'Aktif' ELSE 'Tidak Aktif' END status_text
    FROM dbo.udt_office_locations WHERE id=@id AND company_id=@company_id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_office_locations_create
    @office_name VARCHAR(100),
    @latitude DECIMAL(10,8),
    @longitude DECIMAL(11,8),
    @radius_meters DECIMAL(10,2),
    @is_active BIT = 1,
    @request_user_id VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SET @office_name = NULLIF(LTRIM(RTRIM(@office_name)), '');
    DECLARE @company_id INT, @can_manage BIT = 0;
    SELECT TOP (1) @company_id=ci.company_id,
      @can_manage=CASE WHEN UPPER(ISNULL(u.role,'')) IN ('ADMIN','HRD')
       OR UPPER(ISNULL(ci.organization,'')) LIKE '%HRD%'
       OR UPPER(ISNULL(ci.organization,'')) LIKE '%DIREKTUR%'
       OR UPPER(ISNULL(ci.job_position,'')) LIKE '%DIREKTUR%' THEN 1 ELSE 0 END
    FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
    WHERE u.userid=@request_user_id AND u.active=1 AND ISNULL(u.deleted,0)=0;
    IF @company_id IS NULL OR @can_manage=0 THROW 52203, 'Anda tidak memiliki akses membuat lokasi kantor.', 1;
    IF @office_name IS NULL OR @latitude NOT BETWEEN -90 AND 90 OR @longitude NOT BETWEEN -180 AND 180
       OR @radius_meters IS NULL OR @radius_meters < 1 OR @radius_meters > 10000
       THROW 52204, 'Data lokasi kantor tidak valid.', 1;
    IF EXISTS(SELECT 1 FROM dbo.udt_office_locations WHERE company_id=@company_id AND LOWER(LTRIM(RTRIM(office_name)))=LOWER(@office_name))
       THROW 52205, 'Nama lokasi kantor sudah digunakan pada perusahaan Anda.', 1;

    INSERT dbo.udt_office_locations(office_name,latitude,longitude,radius_meters,is_active,created_at,company_id)
    VALUES(@office_name,@latitude,@longitude,@radius_meters,ISNULL(@is_active,1),GETDATE(),@company_id);
    SELECT 1 success, N'Lokasi kantor berhasil ditambahkan.' message, CONVERT(INT,SCOPE_IDENTITY()) newId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_office_locations_update
    @id INT, @office_name VARCHAR(100), @latitude DECIMAL(10,8), @longitude DECIMAL(11,8),
    @radius_meters DECIMAL(10,2), @is_active BIT, @request_user_id VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SET @office_name=NULLIF(LTRIM(RTRIM(@office_name)), '');
    DECLARE @company_id INT,@can_manage BIT=0;
    SELECT TOP(1) @company_id=ci.company_id,@can_manage=CASE WHEN UPPER(ISNULL(u.role,'')) IN('ADMIN','HRD') OR UPPER(ISNULL(ci.organization,'')) LIKE '%HRD%' OR UPPER(ISNULL(ci.organization,'')) LIKE '%DIREKTUR%' OR UPPER(ISNULL(ci.job_position,'')) LIKE '%DIREKTUR%' THEN 1 ELSE 0 END FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid WHERE u.userid=@request_user_id AND u.active=1 AND ISNULL(u.deleted,0)=0;
    IF @company_id IS NULL OR @can_manage=0 THROW 52206, 'Anda tidak memiliki akses mengubah lokasi kantor.', 1;
    IF @office_name IS NULL OR @latitude NOT BETWEEN -90 AND 90 OR @longitude NOT BETWEEN -180 AND 180 OR @radius_meters IS NULL OR @radius_meters<1 OR @radius_meters>10000 THROW 52207, 'Data lokasi kantor tidak valid.',1;
    IF EXISTS(SELECT 1 FROM dbo.udt_office_locations WHERE company_id=@company_id AND id<>@id AND LOWER(LTRIM(RTRIM(office_name)))=LOWER(@office_name)) THROW 52208, 'Nama lokasi kantor sudah digunakan pada perusahaan Anda.',1;
    UPDATE dbo.udt_office_locations SET office_name=@office_name,latitude=@latitude,longitude=@longitude,radius_meters=@radius_meters,is_active=@is_active WHERE id=@id AND company_id=@company_id;
    IF @@ROWCOUNT<>1 THROW 52209, 'Lokasi kantor tidak ditemukan pada perusahaan Anda.',1;
    SELECT 1 success,N'Lokasi kantor berhasil diperbarui.' message;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_office_locations_delete
    @id INT, @request_user_id VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @company_id INT,@can_manage BIT=0;
    SELECT TOP(1) @company_id=ci.company_id,@can_manage=CASE WHEN UPPER(ISNULL(u.role,'')) IN('ADMIN','HRD') OR UPPER(ISNULL(ci.organization,'')) LIKE '%HRD%' OR UPPER(ISNULL(ci.organization,'')) LIKE '%DIREKTUR%' OR UPPER(ISNULL(ci.job_position,'')) LIKE '%DIREKTUR%' THEN 1 ELSE 0 END FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid WHERE u.userid=@request_user_id AND u.active=1 AND ISNULL(u.deleted,0)=0;
    IF @company_id IS NULL OR @can_manage=0 THROW 52210, 'Anda tidak memiliki akses menghapus lokasi kantor.',1;
    /* Soft delete agar histori absensi lama tetap memiliki referensi lokasi. */
    UPDATE dbo.udt_office_locations SET is_active=0 WHERE id=@id AND company_id=@company_id;
    IF @@ROWCOUNT<>1 THROW 52211, 'Lokasi kantor tidak ditemukan pada perusahaan Anda.',1;
    SELECT 1 success,N'Lokasi kantor dinonaktifkan.' message;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_office_locations_toggle_status
    @id INT, @request_user_id VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @company_id INT,@can_manage BIT=0;
    SELECT TOP(1) @company_id=ci.company_id,@can_manage=CASE WHEN UPPER(ISNULL(u.role,'')) IN('ADMIN','HRD') OR UPPER(ISNULL(ci.organization,'')) LIKE '%HRD%' OR UPPER(ISNULL(ci.organization,'')) LIKE '%DIREKTUR%' OR UPPER(ISNULL(ci.job_position,'')) LIKE '%DIREKTUR%' THEN 1 ELSE 0 END FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid WHERE u.userid=@request_user_id AND u.active=1 AND ISNULL(u.deleted,0)=0;
    IF @company_id IS NULL OR @can_manage=0 THROW 52212, 'Anda tidak memiliki akses mengubah status lokasi kantor.',1;
    UPDATE dbo.udt_office_locations SET is_active=CASE WHEN ISNULL(is_active,0)=1 THEN 0 ELSE 1 END WHERE id=@id AND company_id=@company_id;
    IF @@ROWCOUNT<>1 THROW 52213, 'Lokasi kantor tidak ditemukan pada perusahaan Anda.',1;
    SELECT 1 success,N'Status lokasi kantor berhasil diubah.' message;
END;
GO

/* Boleh dipanggil setiap user aktif, tetapi hasilnya hanya kantor PT-nya. */
CREATE OR ALTER PROCEDURE dbo.udp_office_locations_check_location
    @latitude DECIMAL(10,8), @longitude DECIMAL(11,8), @request_user_id VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @company_id INT;
    SELECT TOP(1) @company_id=ci.company_id FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid WHERE u.userid=@request_user_id AND u.active=1 AND ISNULL(u.deleted,0)=0;
    IF @company_id IS NULL THROW 52214, 'User tidak aktif atau belum terhubung ke perusahaan.',1;
    DECLARE @point geography=geography::Point(@latitude,@longitude,4326);
    SELECT id,office_name,latitude,longitude,radius_meters,
      CAST(@point.STDistance(geography::Point(latitude,longitude,4326)) AS DECIMAL(10,2)) distance_meters,
      CASE WHEN @point.STDistance(geography::Point(latitude,longitude,4326))<=radius_meters THEN 1 ELSE 0 END is_within_range
    FROM dbo.udt_office_locations WHERE company_id=@company_id AND is_active=1
    ORDER BY @point.STDistance(geography::Point(latitude,longitude,4326));
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_office_locations_active
    @request_user_id VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @company_id INT;
    SELECT TOP(1) @company_id=ci.company_id FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid WHERE u.userid=@request_user_id AND u.active=1 AND ISNULL(u.deleted,0)=0;
    IF @company_id IS NULL THROW 52215, 'User tidak aktif atau belum terhubung ke perusahaan.',1;
    SELECT id,office_name,latitude,longitude,radius_meters FROM dbo.udt_office_locations WHERE company_id=@company_id AND is_active=1 ORDER BY office_name,id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_get_office_location_statistics
    @request_user_id VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @company_id INT,@can_manage BIT=0;
    SELECT TOP(1) @company_id=ci.company_id,@can_manage=CASE WHEN UPPER(ISNULL(u.role,'')) IN('ADMIN','HRD') OR UPPER(ISNULL(ci.organization,'')) LIKE '%HRD%' OR UPPER(ISNULL(ci.organization,'')) LIKE '%DIREKTUR%' OR UPPER(ISNULL(ci.job_position,'')) LIKE '%DIREKTUR%' THEN 1 ELSE 0 END FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid WHERE u.userid=@request_user_id AND u.active=1 AND ISNULL(u.deleted,0)=0;
    IF @company_id IS NULL OR @can_manage=0 THROW 52216, 'Anda tidak memiliki akses statistik lokasi kantor.',1;
    SELECT COUNT(*) TotalLocations,SUM(CASE WHEN is_active=1 THEN 1 ELSE 0 END) ActiveLocations,SUM(CASE WHEN ISNULL(is_active,0)=0 THEN 1 ELSE 0 END) InactiveLocations,ISNULL(AVG(radius_meters),0) AverageRadius FROM dbo.udt_office_locations WHERE company_id=@company_id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_export_office_locations
    @request_user_id VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @company_id INT,@can_manage BIT=0;
    SELECT TOP(1) @company_id=ci.company_id,@can_manage=CASE WHEN UPPER(ISNULL(u.role,'')) IN('ADMIN','HRD') OR UPPER(ISNULL(ci.organization,'')) LIKE '%HRD%' OR UPPER(ISNULL(ci.organization,'')) LIKE '%DIREKTUR%' OR UPPER(ISNULL(ci.job_position,'')) LIKE '%DIREKTUR%' THEN 1 ELSE 0 END FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid WHERE u.userid=@request_user_id AND u.active=1 AND ISNULL(u.deleted,0)=0;
    IF @company_id IS NULL OR @can_manage=0 THROW 52217, 'Anda tidak memiliki akses ekspor lokasi kantor.',1;
    SELECT id,office_name,latitude,longitude,radius_meters,CASE WHEN ISNULL(is_active,0)=1 THEN 'Aktif' ELSE 'Tidak Aktif' END status,created_at FROM dbo.udt_office_locations WHERE company_id=@company_id ORDER BY office_name,id;
END;
GO

/* Verifikasi tenant dan procedure. */
SELECT company_id,COUNT(*) total_lokasi,SUM(CASE WHEN is_active=1 THEN 1 ELSE 0 END) lokasi_aktif
FROM dbo.udt_office_locations GROUP BY company_id ORDER BY company_id;

SELECT name,modify_date FROM sys.procedures WHERE name IN
('udp_get_office_locations','udp_office_locations_getall','udp_office_locations_getbyid',
 'udp_office_locations_create','udp_office_locations_update','udp_office_locations_delete',
 'udp_office_locations_toggle_status','udp_office_locations_check_location','udp_office_locations_active',
 'udp_get_office_location_statistics','udp_export_office_locations') ORDER BY name;
GO

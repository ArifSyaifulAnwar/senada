/*
  SENADA - Isolasi penuh modul Asset per perusahaan

  Jalankan pada ABSENSI setelah migration 018.
  Seluruh tenant diturunkan dari userid aktif. Client tidak dapat memilih
  company_id sendiri dan semua detail, gambar, stok, pengajuan, approval,
  pengembalian, kantor, serta laporan dibatasi ke perusahaan yang sama.
*/
USE [ABSENSI];
GO
SET XACT_ABORT ON;
GO

/* ========================================================================== */
/* 1. TENANT PERMANEN DAN INDEX                                               */
/* ========================================================================== */
IF COL_LENGTH('dbo.udt_asset_categories','company_id') IS NULL
    ALTER TABLE dbo.udt_asset_categories ADD company_id INT NULL;
GO

UPDATE c
SET c.company_id=COALESCE(ci.company_id,co.id)
FROM dbo.udt_asset_categories c
LEFT JOIN dbo.udt_company_info_user ci ON ci.userid=c.created_by
LEFT JOIN dbo.udt_companies co
  ON LOWER(LTRIM(RTRIM(co.company_name)))=LOWER(LTRIM(RTRIM(c.company_name)))
WHERE c.company_id IS NULL;
GO

IF EXISTS(SELECT 1 FROM dbo.udt_asset_categories WHERE company_id IS NULL)
    THROW 51900,'Masih ada kategori asset tanpa perusahaan.',1;
IF EXISTS(SELECT 1 FROM dbo.udt_asset_items WHERE company_id IS NULL)
    THROW 51901,'Masih ada barang asset tanpa perusahaan.',1;
IF EXISTS(SELECT 1 FROM dbo.udt_asset_requests WHERE company_id IS NULL)
    THROW 51902,'Masih ada pengajuan asset tanpa perusahaan.',1;
GO

IF EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.udt_asset_categories') AND name='IX_asset_categories_company_active')
 DROP INDEX IX_asset_categories_company_active ON dbo.udt_asset_categories;
IF EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.udt_asset_items') AND name='IX_asset_items_company_active_office')
 DROP INDEX IX_asset_items_company_active_office ON dbo.udt_asset_items;
IF EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.udt_asset_requests') AND name='IX_asset_requests_company_status')
 DROP INDEX IX_asset_requests_company_status ON dbo.udt_asset_requests;
GO

ALTER TABLE dbo.udt_asset_categories ALTER COLUMN company_id INT NOT NULL;
ALTER TABLE dbo.udt_asset_items ALTER COLUMN company_id INT NOT NULL;
ALTER TABLE dbo.udt_asset_requests ALTER COLUMN company_id INT NOT NULL;
GO

IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_asset_categories_company')
 ALTER TABLE dbo.udt_asset_categories WITH CHECK ADD CONSTRAINT FK_asset_categories_company
 FOREIGN KEY(company_id) REFERENCES dbo.udt_companies(id);
GO

IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.udt_asset_categories') AND name='IX_asset_categories_company_active')
 CREATE INDEX IX_asset_categories_company_active
 ON dbo.udt_asset_categories(company_id,aktif,urutan) INCLUDE(nama_kategori,icon_key,warna_hex);
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.udt_asset_items') AND name='IX_asset_items_company_active_office')
 CREATE INDEX IX_asset_items_company_active_office
 ON dbo.udt_asset_items(company_id,aktif,office_location_id) INCLUDE(kategori_id,nama_barang,stok);
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.udt_asset_requests') AND name='IX_asset_requests_company_status')
 CREATE INDEX IX_asset_requests_company_status
 ON dbo.udt_asset_requests(company_id,status,created_at) INCLUDE(userid,asset_item_id,jumlah);
GO

/* Konsistensi tenant tetap terlindungi walaupun ada SP lama/direct insert. */
CREATE OR ALTER TRIGGER dbo.trg_asset_category_company_guard ON dbo.udt_asset_categories
AFTER INSERT,UPDATE AS
BEGIN
 SET NOCOUNT ON;
 IF EXISTS(
   SELECT 1 FROM inserted i
   LEFT JOIN dbo.udt_companies c ON c.id=i.company_id
   WHERE c.id IS NULL OR LOWER(LTRIM(RTRIM(c.company_name)))<>LOWER(LTRIM(RTRIM(i.company_name))))
   THROW 51903,'Perusahaan kategori asset tidak valid.',1;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_asset_item_company_guard ON dbo.udt_asset_items
AFTER INSERT,UPDATE AS
BEGIN
 SET NOCOUNT ON;
 IF EXISTS(
   SELECT 1 FROM inserted i
   INNER JOIN dbo.udt_asset_categories k ON k.id=i.kategori_id
   INNER JOIN dbo.udt_office_locations o ON o.id=i.office_location_id
   LEFT JOIN dbo.udt_companies c ON c.id=i.company_id
   WHERE c.id IS NULL OR k.company_id<>i.company_id OR o.company_id<>i.company_id
      OR LOWER(LTRIM(RTRIM(c.company_name)))<>LOWER(LTRIM(RTRIM(i.company_name))))
   THROW 51904,'Kategori, kantor, dan barang asset harus berada pada perusahaan yang sama.',1;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_asset_request_company_guard ON dbo.udt_asset_requests
AFTER INSERT,UPDATE AS
BEGIN
 SET NOCOUNT ON;
 IF EXISTS(
   SELECT 1 FROM inserted i
   INNER JOIN dbo.udt_company_info_user ci ON ci.userid=i.userid
   INNER JOIN dbo.udt_asset_items ai ON ai.id=i.asset_item_id
   WHERE ci.company_id<>i.company_id OR ai.company_id<>i.company_id)
   THROW 51905,'Pemohon dan barang asset harus berasal dari perusahaan yang sama.',1;
END;
GO

/* ========================================================================== */
/* 2. HAK AKSES DAN KATEGORI                                                  */
/* ========================================================================== */
CREATE OR ALTER PROCEDURE dbo.udp_asset_can_manage_stock @userid VARCHAR(50) AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @can BIT=0;
 IF EXISTS(
   SELECT 1 FROM dbo.udt_users u
   INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
   INNER JOIN dbo.udt_companies c ON c.id=ci.company_id AND c.is_active=1
   WHERE u.userid=@userid AND u.active=1 AND ISNULL(u.deleted,0)=0
   AND (UPPER(LTRIM(RTRIM(ISNULL(u.role,'')))) IN('HRD','ADMIN')
     OR UPPER(ISNULL(ci.organization,'')) LIKE '%HRD%'
     OR UPPER(ISNULL(ci.job_position,'')) LIKE '%HRD%')) SET @can=1;
 SELECT CAST(1 AS BIT) success,@can can_manage,
   CASE WHEN @can=1 THEN N'User memiliki akses kelola stok asset'
        ELSE N'User tidak memiliki akses kelola stok asset' END message;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_asset_is_head_hrd @userid VARCHAR(50) AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @is_head BIT=0;
 IF EXISTS(
   SELECT 1 FROM dbo.udt_users u
   INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
   INNER JOIN dbo.udt_companies c ON c.id=ci.company_id AND c.is_active=1
   WHERE u.userid=@userid AND u.active=1 AND ISNULL(u.deleted,0)=0
   AND UPPER(ISNULL(ci.organization,'')) LIKE '%HRD%'
   AND (UPPER(ISNULL(ci.job_position,'')) LIKE '%HEAD%' OR UPPER(ISNULL(ci.job_level,''))='HEAD'))
   SET @is_head=1;
 SELECT CAST(1 AS BIT) success,@is_head is_head_hrd,
  CASE WHEN @is_head=1 THEN N'User adalah Head HRD' ELSE N'User bukan Head HRD' END message;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_asset_category_get_all @userid VARCHAR(50) AS
BEGIN
 SET NOCOUNT ON; DECLARE @company_id INT;
 SELECT @company_id=ci.company_id FROM dbo.udt_users u
 INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
 WHERE u.userid=@userid AND u.active=1 AND ISNULL(u.deleted,0)=0;
 IF @company_id IS NULL THROW 51906,'User tidak aktif atau belum terhubung ke perusahaan.',1;
 SELECT id,nama_kategori,icon_key,warna_hex,urutan
 FROM dbo.udt_asset_categories WHERE company_id=@company_id AND aktif=1
 ORDER BY urutan,nama_kategori;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_asset_category_create
 @userid VARCHAR(50),@nama_kategori NVARCHAR(50),@icon_key NVARCHAR(50)='category',@warna_hex NVARCHAR(9)='#607D8B'
AS
BEGIN
 SET NOCOUNT ON; DECLARE @company_id INT,@company_name NVARCHAR(200);
 SELECT TOP(1) @company_id=ci.company_id,@company_name=c.company_name
 FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
 INNER JOIN dbo.udt_companies c ON c.id=ci.company_id AND c.is_active=1
 WHERE u.userid=@userid AND u.active=1 AND ISNULL(u.deleted,0)=0
 AND (UPPER(LTRIM(RTRIM(ISNULL(u.role,'')))) IN('HRD','ADMIN')
   OR UPPER(ISNULL(ci.organization,'')) LIKE '%HRD%' OR UPPER(ISNULL(ci.job_position,'')) LIKE '%HRD%');
 IF @company_id IS NULL BEGIN SELECT 0 success,N'Hanya tim HRD perusahaan aktif yang dapat menambahkan kategori.' message,CAST(NULL AS INT) id; RETURN; END;
 SET @nama_kategori=NULLIF(LTRIM(RTRIM(@nama_kategori)),'');
 IF @nama_kategori IS NULL BEGIN SELECT 0 success,N'Nama kategori wajib diisi.' message,CAST(NULL AS INT) id; RETURN; END;
 DECLARE @existing INT;
 SELECT @existing=id FROM dbo.udt_asset_categories WHERE company_id=@company_id AND LOWER(LTRIM(RTRIM(nama_kategori)))=LOWER(@nama_kategori);
 IF @existing IS NOT NULL BEGIN SELECT 0 success,N'Kategori dengan nama tersebut sudah ada pada perusahaan Anda.' message,@existing id; RETURN; END;
 DECLARE @urutan INT=(SELECT ISNULL(MAX(urutan),0)+1 FROM dbo.udt_asset_categories WHERE company_id=@company_id);
 INSERT dbo.udt_asset_categories(company_name,nama_kategori,icon_key,warna_hex,urutan,aktif,created_by,created_at,updated_at,company_id)
 VALUES(@company_name,@nama_kategori,@icon_key,@warna_hex,@urutan,1,@userid,GETDATE(),GETDATE(),@company_id);
 SELECT 1 success,N'Kategori berhasil ditambahkan.' message,CONVERT(INT,SCOPE_IDENTITY()) id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_asset_category_update
 @id INT,@userid VARCHAR(50),@nama_kategori NVARCHAR(50),@icon_key NVARCHAR(50),@warna_hex NVARCHAR(9)
AS
BEGIN
 SET NOCOUNT ON; DECLARE @company_id INT,@old NVARCHAR(50);
 SELECT TOP(1) @company_id=ci.company_id FROM dbo.udt_users u
 INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
 WHERE u.userid=@userid AND u.active=1 AND ISNULL(u.deleted,0)=0
 AND (UPPER(LTRIM(RTRIM(ISNULL(u.role,'')))) IN('HRD','ADMIN')
   OR UPPER(ISNULL(ci.organization,'')) LIKE '%HRD%' OR UPPER(ISNULL(ci.job_position,'')) LIKE '%HRD%');
 SELECT @old=nama_kategori FROM dbo.udt_asset_categories WHERE id=@id AND company_id=@company_id;
 IF @old IS NULL BEGIN SELECT 0 success,N'Kategori tidak ditemukan pada perusahaan Anda.' message; RETURN; END;
 IF EXISTS(SELECT 1 FROM dbo.udt_asset_categories WHERE company_id=@company_id AND id<>@id AND LOWER(LTRIM(RTRIM(nama_kategori)))=LOWER(LTRIM(RTRIM(@nama_kategori))))
 BEGIN SELECT 0 success,N'Nama kategori sudah dipakai.' message; RETURN; END;
 UPDATE dbo.udt_asset_categories SET nama_kategori=LTRIM(RTRIM(@nama_kategori)),icon_key=@icon_key,warna_hex=@warna_hex,updated_at=GETDATE()
 WHERE id=@id AND company_id=@company_id;
 UPDATE dbo.udt_asset_items SET kategori=LTRIM(RTRIM(@nama_kategori)),updated_by=@userid,updated_at=GETDATE()
 WHERE kategori_id=@id AND company_id=@company_id;
 SELECT 1 success,N'Kategori berhasil diupdate.' message;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_asset_category_toggle_aktif @id INT,@userid VARCHAR(50) AS
BEGIN
 SET NOCOUNT ON; DECLARE @company_id INT;
 SELECT TOP(1) @company_id=ci.company_id FROM dbo.udt_users u
 INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
 WHERE u.userid=@userid AND u.active=1 AND ISNULL(u.deleted,0)=0
 AND (UPPER(LTRIM(RTRIM(ISNULL(u.role,'')))) IN('HRD','ADMIN')
   OR UPPER(ISNULL(ci.organization,'')) LIKE '%HRD%' OR UPPER(ISNULL(ci.job_position,'')) LIKE '%HRD%');
 UPDATE dbo.udt_asset_categories SET aktif=CASE WHEN aktif=1 THEN 0 ELSE 1 END,updated_at=GETDATE()
 WHERE id=@id AND company_id=@company_id;
 IF @@ROWCOUNT<>1 BEGIN SELECT 0 success,N'Kategori tidak ditemukan pada perusahaan Anda.' message,CAST(NULL AS BIT) aktif; RETURN; END;
 SELECT 1 success,CASE WHEN aktif=1 THEN N'Kategori diaktifkan.' ELSE N'Kategori dinonaktifkan.' END message,aktif
 FROM dbo.udt_asset_categories WHERE id=@id AND company_id=@company_id;
END;
GO

/* ========================================================================== */
/* 3. MASTER BARANG, GAMBAR, DAN KANTOR                                       */
/* ========================================================================== */
CREATE OR ALTER PROCEDURE dbo.udp_asset_office_get_all @userid VARCHAR(50) AS
BEGIN
 SET NOCOUNT ON; DECLARE @company_id INT;
 SELECT @company_id=ci.company_id FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
 WHERE u.userid=@userid AND u.active=1 AND ISNULL(u.deleted,0)=0;
 IF @company_id IS NULL THROW 51907,'User tidak aktif atau belum terhubung ke perusahaan.',1;
 SELECT id,office_name,latitude,longitude FROM dbo.udt_office_locations
 WHERE company_id=@company_id AND is_active=1 ORDER BY office_name;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_asset_item_create
 @userid VARCHAR(50),@nama_barang NVARCHAR(200),@kategori_id INT,@office_location_id INT,
 @deskripsi NVARCHAR(500)=NULL,@stok INT,@gambar_path NVARCHAR(500)=NULL,@gambar_filename NVARCHAR(255)=NULL
AS
BEGIN
 SET NOCOUNT ON; DECLARE @company_id INT,@company_name NVARCHAR(200),@nama_kategori NVARCHAR(50);
 SELECT TOP(1) @company_id=ci.company_id,@company_name=c.company_name
 FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
 INNER JOIN dbo.udt_companies c ON c.id=ci.company_id AND c.is_active=1
 WHERE u.userid=@userid AND u.active=1 AND ISNULL(u.deleted,0)=0
 AND (UPPER(LTRIM(RTRIM(ISNULL(u.role,'')))) IN('HRD','ADMIN')
   OR UPPER(ISNULL(ci.organization,'')) LIKE '%HRD%' OR UPPER(ISNULL(ci.job_position,'')) LIKE '%HRD%');
 IF @company_id IS NULL BEGIN SELECT 0 success,N'Hanya tim HRD perusahaan aktif yang dapat menambah barang.' message,CAST(NULL AS INT) id; RETURN; END;
 IF @stok<0 BEGIN SELECT 0 success,N'Stok tidak boleh negatif.' message,CAST(NULL AS INT) id; RETURN; END;
 SELECT @nama_kategori=nama_kategori FROM dbo.udt_asset_categories WHERE id=@kategori_id AND company_id=@company_id AND aktif=1;
 IF @nama_kategori IS NULL BEGIN SELECT 0 success,N'Kategori tidak tersedia pada perusahaan Anda.' message,CAST(NULL AS INT) id; RETURN; END;
 IF NOT EXISTS(SELECT 1 FROM dbo.udt_office_locations WHERE id=@office_location_id AND company_id=@company_id AND is_active=1)
 BEGIN SELECT 0 success,N'Lokasi kantor tidak tersedia pada perusahaan Anda.' message,CAST(NULL AS INT) id; RETURN; END;
 IF EXISTS(SELECT 1 FROM dbo.udt_asset_items WHERE company_id=@company_id AND nama_barang=@nama_barang AND kategori_id=@kategori_id AND office_location_id=@office_location_id)
 BEGIN SELECT 0 success,N'Barang dengan nama dan kategori yang sama sudah ada di kantor ini.' message,CAST(NULL AS INT) id; RETURN; END;
 INSERT dbo.udt_asset_items(company_name,company_id,nama_barang,kategori,kategori_id,office_location_id,deskripsi,stok,gambar_path,gambar_filename,aktif,created_by,created_at,updated_by,updated_at)
 VALUES(@company_name,@company_id,@nama_barang,@nama_kategori,@kategori_id,@office_location_id,@deskripsi,@stok,@gambar_path,@gambar_filename,1,@userid,GETDATE(),@userid,GETDATE());
 SELECT 1 success,N'Barang berhasil ditambahkan.' message,CONVERT(INT,SCOPE_IDENTITY()) id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_asset_item_update
 @id INT,@userid VARCHAR(50),@nama_barang NVARCHAR(200),@kategori_id INT,@office_location_id INT,
 @deskripsi NVARCHAR(500)=NULL,@stok INT,@gambar_path NVARCHAR(500)=NULL,@gambar_filename NVARCHAR(255)=NULL,@ganti_gambar BIT=0
AS
BEGIN
 SET NOCOUNT ON; DECLARE @company_id INT,@nama_kategori NVARCHAR(50);
 SELECT TOP(1) @company_id=ci.company_id FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
 WHERE u.userid=@userid AND u.active=1 AND ISNULL(u.deleted,0)=0
 AND (UPPER(LTRIM(RTRIM(ISNULL(u.role,'')))) IN('HRD','ADMIN')
   OR UPPER(ISNULL(ci.organization,'')) LIKE '%HRD%' OR UPPER(ISNULL(ci.job_position,'')) LIKE '%HRD%');
 IF NOT EXISTS(SELECT 1 FROM dbo.udt_asset_items WHERE id=@id AND company_id=@company_id)
 BEGIN SELECT 0 success,N'Barang tidak ditemukan pada perusahaan Anda.' message; RETURN; END;
 IF @stok<0 BEGIN SELECT 0 success,N'Stok tidak boleh negatif.' message; RETURN; END;
 SELECT @nama_kategori=nama_kategori FROM dbo.udt_asset_categories WHERE id=@kategori_id AND company_id=@company_id AND aktif=1;
 IF @nama_kategori IS NULL BEGIN SELECT 0 success,N'Kategori tidak tersedia pada perusahaan Anda.' message; RETURN; END;
 IF NOT EXISTS(SELECT 1 FROM dbo.udt_office_locations WHERE id=@office_location_id AND company_id=@company_id AND is_active=1)
 BEGIN SELECT 0 success,N'Lokasi kantor tidak tersedia pada perusahaan Anda.' message; RETURN; END;
 IF EXISTS(SELECT 1 FROM dbo.udt_asset_items WHERE company_id=@company_id AND id<>@id AND nama_barang=@nama_barang AND kategori_id=@kategori_id AND office_location_id=@office_location_id)
 BEGIN SELECT 0 success,N'Barang yang sama sudah ada di kantor ini.' message; RETURN; END;
 UPDATE dbo.udt_asset_items SET nama_barang=@nama_barang,kategori=@nama_kategori,kategori_id=@kategori_id,
  office_location_id=@office_location_id,deskripsi=@deskripsi,stok=@stok,
  gambar_path=CASE WHEN @ganti_gambar=1 THEN @gambar_path ELSE gambar_path END,
  gambar_filename=CASE WHEN @ganti_gambar=1 THEN @gambar_filename ELSE gambar_filename END,
  updated_by=@userid,updated_at=GETDATE()
 WHERE id=@id AND company_id=@company_id;
 SELECT 1 success,N'Barang berhasil diupdate.' message;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_asset_item_get_catalog
 @userid VARCHAR(50),@kategori_id INT=NULL,@office_location_id INT=NULL AS
BEGIN
 SET NOCOUNT ON; DECLARE @company_id INT;
 SELECT @company_id=ci.company_id FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
 WHERE u.userid=@userid AND u.active=1 AND ISNULL(u.deleted,0)=0;
 IF @company_id IS NULL THROW 51908,'User tidak aktif atau belum terhubung ke perusahaan.',1;
 SELECT i.id,i.nama_barang,i.kategori,i.kategori_id,k.icon_key,k.warna_hex,i.office_location_id,o.office_name,
  i.deskripsi,i.stok,i.gambar_path,i.gambar_filename,i.aktif
 FROM dbo.udt_asset_items i
 LEFT JOIN dbo.udt_asset_categories k ON k.id=i.kategori_id AND k.company_id=i.company_id
 LEFT JOIN dbo.udt_office_locations o ON o.id=i.office_location_id AND o.company_id=i.company_id
 WHERE i.company_id=@company_id AND i.aktif=1
 AND (@kategori_id IS NULL OR i.kategori_id=@kategori_id)
 AND (@office_location_id IS NULL OR i.office_location_id=@office_location_id)
 ORDER BY o.office_name,ISNULL(k.urutan,999),i.nama_barang;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_asset_item_get_all @userid VARCHAR(50) AS
BEGIN
 SET NOCOUNT ON; DECLARE @company_id INT,@allowed BIT=0;
 SELECT TOP(1) @company_id=ci.company_id,@allowed=CASE WHEN UPPER(LTRIM(RTRIM(ISNULL(u.role,'')))) IN('HRD','ADMIN')
  OR UPPER(ISNULL(ci.organization,'')) LIKE '%HRD%' OR UPPER(ISNULL(ci.job_position,'')) LIKE '%HRD%' THEN 1 ELSE 0 END
 FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
 WHERE u.userid=@userid AND u.active=1 AND ISNULL(u.deleted,0)=0;
 IF @company_id IS NULL OR @allowed=0 THROW 51909,'User tidak memiliki akses kelola asset.',1;
 SELECT i.id,i.nama_barang,i.kategori,i.kategori_id,k.icon_key,k.warna_hex,i.office_location_id,o.office_name,
  i.deskripsi,i.stok,i.gambar_path,i.gambar_filename,i.aktif,i.created_by,i.created_at,i.updated_by,i.updated_at
 FROM dbo.udt_asset_items i
 LEFT JOIN dbo.udt_asset_categories k ON k.id=i.kategori_id AND k.company_id=i.company_id
 LEFT JOIN dbo.udt_office_locations o ON o.id=i.office_location_id AND o.company_id=i.company_id
 WHERE i.company_id=@company_id ORDER BY o.office_name,ISNULL(k.urutan,999),i.nama_barang;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_asset_item_get_by_id @id INT,@viewer_userid VARCHAR(50) AS
BEGIN
 SET NOCOUNT ON; DECLARE @company_id INT;
 SELECT @company_id=ci.company_id FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
 WHERE u.userid=@viewer_userid AND u.active=1 AND ISNULL(u.deleted,0)=0;
 SELECT id,company_name,nama_barang,kategori,deskripsi,stok,gambar_path,gambar_filename,aktif,
  created_by,created_at,updated_by,updated_at
 FROM dbo.udt_asset_items WHERE id=@id AND company_id=@company_id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_asset_item_toggle_aktif @id INT,@userid VARCHAR(50) AS
BEGIN
 SET NOCOUNT ON; DECLARE @company_id INT;
 SELECT TOP(1) @company_id=ci.company_id FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
 WHERE u.userid=@userid AND u.active=1 AND ISNULL(u.deleted,0)=0
 AND (UPPER(LTRIM(RTRIM(ISNULL(u.role,'')))) IN('HRD','ADMIN') OR UPPER(ISNULL(ci.organization,'')) LIKE '%HRD%' OR UPPER(ISNULL(ci.job_position,'')) LIKE '%HRD%');
 UPDATE dbo.udt_asset_items SET aktif=CASE WHEN aktif=1 THEN 0 ELSE 1 END,updated_by=@userid,updated_at=GETDATE()
 WHERE id=@id AND company_id=@company_id;
 IF @@ROWCOUNT<>1 BEGIN SELECT 0 success,N'Barang tidak ditemukan pada perusahaan Anda.' message,CAST(NULL AS BIT) aktif; RETURN; END;
 SELECT 1 success,CASE WHEN aktif=1 THEN N'Barang diaktifkan.' ELSE N'Barang dinonaktifkan.' END message,aktif
 FROM dbo.udt_asset_items WHERE id=@id AND company_id=@company_id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_asset_item_delete @id INT,@userid VARCHAR(50) AS
BEGIN
 SET NOCOUNT ON; DECLARE @company_id INT;
 SELECT TOP(1) @company_id=ci.company_id FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
 WHERE u.userid=@userid AND u.active=1 AND ISNULL(u.deleted,0)=0
 AND (UPPER(LTRIM(RTRIM(ISNULL(u.role,'')))) IN('HRD','ADMIN') OR UPPER(ISNULL(ci.organization,'')) LIKE '%HRD%' OR UPPER(ISNULL(ci.job_position,'')) LIKE '%HRD%');
 IF NOT EXISTS(SELECT 1 FROM dbo.udt_asset_items WHERE id=@id AND company_id=@company_id)
 BEGIN SELECT 0 success,N'Barang tidak ditemukan pada perusahaan Anda.' message; RETURN; END;
 IF EXISTS(SELECT 1 FROM dbo.udt_asset_requests WHERE asset_item_id=@id AND company_id=@company_id)
 BEGIN UPDATE dbo.udt_asset_items SET aktif=0,updated_by=@userid,updated_at=GETDATE() WHERE id=@id AND company_id=@company_id;
  SELECT 1 success,N'Barang memiliki riwayat pengajuan sehingga dinonaktifkan.' message; RETURN; END;
 DELETE dbo.udt_asset_items WHERE id=@id AND company_id=@company_id;
 SELECT 1 success,N'Barang berhasil dihapus.' message;
END;
GO

/* ========================================================================== */
/* 4. PENGAJUAN, APPROVAL, DAN PENGEMBALIAN                                   */
/* ========================================================================== */
CREATE OR ALTER PROCEDURE dbo.udp_asset_request_create
 @userid VARCHAR(50),@asset_item_id INT,@kategori NVARCHAR(20),@jumlah INT,@catatan NVARCHAR(500)=NULL,
 @tanggal_pinjam DATE=NULL,@tanggal_rencana_kembali DATE=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 DECLARE @company_id INT,@stock INT,@is_head BIT=0;
 SELECT @company_id=ci.company_id FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
 INNER JOIN dbo.udt_companies c ON c.id=ci.company_id AND c.is_active=1
 WHERE u.userid=@userid AND u.active=1 AND ISNULL(u.deleted,0)=0;
 IF @company_id IS NULL BEGIN SELECT 0 success,N'User tidak aktif atau belum terhubung ke perusahaan.' message,CAST(NULL AS INT) id,CAST(0 AS BIT) auto_approved; RETURN; END;
 SET @kategori=LOWER(LTRIM(RTRIM(@kategori)));
 IF @kategori NOT IN('dipinjam','diambil') OR @jumlah<=0 BEGIN SELECT 0 success,N'Jenis atau jumlah pengajuan tidak valid.' message,CAST(NULL AS INT) id,CAST(0 AS BIT) auto_approved; RETURN; END;
 SELECT @stock=stok FROM dbo.udt_asset_items WHERE id=@asset_item_id AND company_id=@company_id AND aktif=1;
 IF @stock IS NULL BEGIN SELECT 0 success,N'Barang tidak ditemukan pada perusahaan Anda.' message,CAST(NULL AS INT) id,CAST(0 AS BIT) auto_approved; RETURN; END;
 IF @jumlah>@stock BEGIN SELECT 0 success,N'Stok tidak mencukupi. Tersedia: '+CONVERT(NVARCHAR(10),@stock) message,CAST(NULL AS INT) id,CAST(0 AS BIT) auto_approved; RETURN; END;
 IF EXISTS(SELECT 1 FROM dbo.udt_company_info_user WHERE userid=@userid AND company_id=@company_id
   AND UPPER(ISNULL(organization,'')) LIKE '%HRD%' AND (UPPER(ISNULL(job_position,'')) LIKE '%HEAD%' OR UPPER(ISNULL(job_level,''))='HEAD')) SET @is_head=1;
 BEGIN TRY
  BEGIN TRANSACTION;
  IF @is_head=1 BEGIN
   UPDATE dbo.udt_asset_items SET stok=stok-@jumlah,updated_at=GETDATE(),updated_by=@userid
   WHERE id=@asset_item_id AND company_id=@company_id AND stok>=@jumlah;
   IF @@ROWCOUNT<>1 THROW 51910,'Stok berubah dan tidak lagi mencukupi.',1;
  END;
  INSERT dbo.udt_asset_requests(asset_item_id,userid,kategori,jumlah,catatan,status,approved_by,approved_at,created_at,updated_at,tanggal_pinjam,tanggal_rencana_kembali,company_id)
  VALUES(@asset_item_id,@userid,@kategori,@jumlah,@catatan,CASE WHEN @is_head=1 THEN 'Approved' ELSE 'Pending' END,
   CASE WHEN @is_head=1 THEN @userid END,CASE WHEN @is_head=1 THEN GETDATE() END,GETDATE(),GETDATE(),@tanggal_pinjam,@tanggal_rencana_kembali,@company_id);
  DECLARE @id INT=CONVERT(INT,SCOPE_IDENTITY()); COMMIT;
  SELECT 1 success,CASE WHEN @is_head=1 THEN N'Pengajuan otomatis disetujui.' ELSE N'Pengajuan dikirim ke Head HRD perusahaan Anda.' END message,@id id,@is_head auto_approved;
 END TRY BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; SELECT 0 success,N'Terjadi kesalahan: '+ERROR_MESSAGE() message,CAST(NULL AS INT) id,CAST(0 AS BIT) auto_approved; END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_asset_request_get_my @userid VARCHAR(50) AS
BEGIN
 SET NOCOUNT ON; DECLARE @company_id INT;
 SELECT @company_id=company_id FROM dbo.udt_company_info_user WHERE userid=@userid;
 SELECT r.id,r.asset_item_id,ai.nama_barang,r.kategori,r.jumlah,r.status,r.catatan,r.rejection_reason,
  r.created_at tanggal_pengajuan,r.approved_at,r.tanggal_kembali,r.tanggal_pinjam,r.tanggal_rencana_kembali
 FROM dbo.udt_asset_requests r INNER JOIN dbo.udt_asset_items ai ON ai.id=r.asset_item_id AND ai.company_id=r.company_id
 WHERE r.userid=@userid AND r.company_id=@company_id ORDER BY r.created_at DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_asset_request_get_by_id @id INT,@viewer_userid VARCHAR(50) AS
BEGIN
 SET NOCOUNT ON; DECLARE @company_id INT;
 SELECT @company_id=ci.company_id FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
 WHERE u.userid=@viewer_userid AND u.active=1 AND ISNULL(u.deleted,0)=0;
 SELECT r.id,r.userid,r.asset_item_id,ai.nama_barang,r.kategori,r.jumlah,r.status,r.catatan,r.rejection_reason,
  r.created_at tanggal_pengajuan,r.approved_at,r.tanggal_kembali,r.tanggal_pinjam,r.tanggal_rencana_kembali
 FROM dbo.udt_asset_requests r INNER JOIN dbo.udt_asset_items ai ON ai.id=r.asset_item_id AND ai.company_id=r.company_id
 WHERE r.id=@id AND r.company_id=@company_id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_asset_request_get_borrow_letter_data
 @id INT,@viewer_userid VARCHAR(50) AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @company_id INT,@borrower VARCHAR(50),@item_category NVARCHAR(50),@head VARCHAR(50),@head_name NVARCHAR(200);
 SELECT @company_id=ci.company_id FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
 WHERE u.userid=@viewer_userid AND u.active=1 AND ISNULL(u.deleted,0)=0;
 SELECT @borrower=r.userid,@item_category=ai.kategori FROM dbo.udt_asset_requests r
 INNER JOIN dbo.udt_asset_items ai ON ai.id=r.asset_item_id AND ai.company_id=r.company_id
 WHERE r.id=@id AND r.company_id=@company_id;
 IF @borrower IS NULL BEGIN SELECT NULL id WHERE 1=0; RETURN; END;

 DECLARE @admins TABLE(userid VARCHAR(50),name NVARCHAR(200),job_position NVARCHAR(200),organization NVARCHAR(200));
 INSERT @admins EXEC dbo.udp_inventory_get_auto_admin_inventaris @userid=@borrower,@kategori=@item_category;

 SELECT TOP(1) @head=ci.userid,@head_name=u.name FROM dbo.udt_company_info_user ci
 INNER JOIN dbo.udt_users u ON u.userid=ci.userid
 WHERE ci.company_id=@company_id AND u.active=1 AND ISNULL(u.deleted,0)=0
 AND UPPER(ISNULL(ci.organization,'')) LIKE '%HRD%'
 AND (UPPER(ISNULL(ci.job_position,'')) LIKE '%HEAD%' OR UPPER(ISNULL(ci.job_level,''))='HEAD')
 ORDER BY CASE WHEN UPPER(ISNULL(ci.job_position,'')) LIKE 'HEAD%' THEN 0 ELSE 1 END,ci.userid;

 SELECT r.id,ai.nama_barang,ai.kategori,r.jumlah,r.catatan,r.tanggal_pinjam,r.tanggal_rencana_kembali,r.status,
  r.userid peminjam_userid,pu.name peminjam_name,pci.job_position peminjam_job,
  adm.userid admin_inventaris_userid,adm.name admin_inventaris_name,adm.job_position admin_inventaris_job,
  @head head_hrd_userid,@head_name head_hrd_name
 FROM dbo.udt_asset_requests r INNER JOIN dbo.udt_asset_items ai ON ai.id=r.asset_item_id AND ai.company_id=r.company_id
 LEFT JOIN dbo.udt_users pu ON pu.userid=r.userid
 LEFT JOIN dbo.udt_company_info_user pci ON pci.userid=r.userid AND pci.company_id=r.company_id
 OUTER APPLY(SELECT TOP(1) userid,name,job_position FROM @admins) adm
 WHERE r.id=@id AND r.company_id=@company_id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_asset_request_mark_returned @id INT,@userid VARCHAR(50) AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON; DECLARE @company_id INT,@item INT,@qty INT,@kind NVARCHAR(20),@status NVARCHAR(20);
 SELECT TOP(1) @company_id=ci.company_id FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
 WHERE u.userid=@userid AND u.active=1 AND ISNULL(u.deleted,0)=0
 AND UPPER(ISNULL(ci.organization,'')) LIKE '%HRD%'
 AND (UPPER(ISNULL(ci.job_position,'')) LIKE '%HEAD%' OR UPPER(ISNULL(ci.job_level,''))='HEAD');
 SELECT @item=asset_item_id,@qty=jumlah,@kind=kategori,@status=status FROM dbo.udt_asset_requests WITH(UPDLOCK,ROWLOCK)
 WHERE id=@id AND company_id=@company_id;
 IF @item IS NULL BEGIN SELECT 0 success,N'Pengajuan tidak ditemukan pada perusahaan Anda.' message; RETURN; END;
 IF @kind<>'dipinjam' BEGIN SELECT 0 success,N'Hanya barang dipinjam yang dapat dikembalikan.' message; RETURN; END;
 IF @status<>'Approved' BEGIN SELECT 0 success,N'Pengajuan belum disetujui atau sudah dikembalikan.' message; RETURN; END;
 BEGIN TRY BEGIN TRANSACTION;
  UPDATE dbo.udt_asset_items SET stok=stok+@qty,updated_by=@userid,updated_at=GETDATE() WHERE id=@item AND company_id=@company_id;
  IF @@ROWCOUNT<>1 THROW 51911,'Barang tidak ditemukan pada perusahaan Anda.',1;
  UPDATE dbo.udt_asset_requests SET status='Dikembalikan',tanggal_kembali=GETDATE(),dikembalikan_oleh=@userid,updated_at=GETDATE()
  WHERE id=@id AND company_id=@company_id AND status='Approved';
  COMMIT; SELECT 1 success,N'Barang berhasil dikonfirmasi dikembalikan.' message;
 END TRY BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; SELECT 0 success,N'Terjadi kesalahan: '+ERROR_MESSAGE() message; END CATCH;
END;
GO

/* 018 sudah mengunci pending/count/review. Definisikan kembali agar migration ini mandiri. */
CREATE OR ALTER PROCEDURE dbo.udp_asset_request_get_pending @hrd_userid VARCHAR(50) AS
BEGIN
 SET NOCOUNT ON; DECLARE @company_id INT,@allowed BIT=0;
 SELECT TOP(1) @company_id=ci.company_id,@allowed=CASE WHEN UPPER(ISNULL(ci.organization,'')) LIKE '%HRD%'
  AND (UPPER(ISNULL(ci.job_position,'')) LIKE '%HEAD%' OR UPPER(ISNULL(ci.job_level,''))='HEAD') THEN 1 ELSE 0 END
 FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
 WHERE u.userid=@hrd_userid AND u.active=1 AND ISNULL(u.deleted,0)=0;
 SELECT r.id,r.userid,u.name user_name,ci.job_position user_job,r.asset_item_id,ai.nama_barang,ai.stok stok_tersedia,
  r.kategori,r.jumlah,r.catatan,r.status,r.created_at tanggal_pengajuan,DATEDIFF(DAY,r.created_at,GETDATE()) days_waiting
 FROM dbo.udt_asset_requests r INNER JOIN dbo.udt_asset_items ai ON ai.id=r.asset_item_id AND ai.company_id=r.company_id
 INNER JOIN dbo.udt_company_info_user ci ON ci.userid=r.userid AND ci.company_id=r.company_id LEFT JOIN dbo.udt_users u ON u.userid=r.userid
 WHERE @allowed=1 AND r.company_id=@company_id AND r.status='Pending' ORDER BY r.created_at;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_asset_request_get_pending_count @hrd_userid VARCHAR(50) AS
BEGIN
 SET NOCOUNT ON; DECLARE @company_id INT,@allowed BIT=0;
 SELECT TOP(1) @company_id=ci.company_id,@allowed=CASE WHEN UPPER(ISNULL(ci.organization,'')) LIKE '%HRD%'
  AND (UPPER(ISNULL(ci.job_position,'')) LIKE '%HEAD%' OR UPPER(ISNULL(ci.job_level,''))='HEAD') THEN 1 ELSE 0 END
 FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
 WHERE u.userid=@hrd_userid AND u.active=1 AND ISNULL(u.deleted,0)=0;
 SELECT COUNT(*) pending_count FROM dbo.udt_asset_requests WHERE @allowed=1 AND company_id=@company_id AND status='Pending';
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_asset_request_review
 @id INT,@hrd_userid VARCHAR(50),@status NVARCHAR(20),@rejection_reason NVARCHAR(500)=NULL AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @status NOT IN('Approved','Rejected') BEGIN SELECT 0 success,N'Status tidak valid.' message; RETURN; END;
 DECLARE @company_id INT,@item INT,@qty INT,@current NVARCHAR(20);
 SELECT TOP(1) @company_id=ci.company_id FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
 WHERE u.userid=@hrd_userid AND u.active=1 AND ISNULL(u.deleted,0)=0 AND UPPER(ISNULL(ci.organization,'')) LIKE '%HRD%'
 AND (UPPER(ISNULL(ci.job_position,'')) LIKE '%HEAD%' OR UPPER(ISNULL(ci.job_level,''))='HEAD');
 IF @company_id IS NULL BEGIN SELECT 0 success,N'Hanya Head HRD aktif yang dapat memproses pengajuan.' message; RETURN; END;
 SELECT @item=asset_item_id,@qty=jumlah,@current=status FROM dbo.udt_asset_requests WITH(UPDLOCK,ROWLOCK)
 WHERE id=@id AND company_id=@company_id;
 IF @current IS NULL BEGIN SELECT 0 success,N'Pengajuan tidak ditemukan pada perusahaan Anda.' message; RETURN; END;
 IF @current<>'Pending' BEGIN SELECT 0 success,N'Pengajuan sudah diproses.' message; RETURN; END;
 BEGIN TRY BEGIN TRANSACTION;
  IF @status='Approved' BEGIN UPDATE dbo.udt_asset_items SET stok=stok-@qty,updated_by=@hrd_userid,updated_at=GETDATE()
   WHERE id=@item AND company_id=@company_id AND stok>=@qty; IF @@ROWCOUNT<>1 THROW 51912,'Stok tidak mencukupi.',1; END;
  UPDATE dbo.udt_asset_requests SET status=@status,approved_by=@hrd_userid,approved_at=GETDATE(),
   rejection_reason=CASE WHEN @status='Rejected' THEN @rejection_reason END,updated_at=GETDATE()
  WHERE id=@id AND company_id=@company_id AND status='Pending';
  COMMIT; SELECT 1 success,CASE WHEN @status='Approved' THEN N'Pengajuan disetujui.' ELSE N'Pengajuan ditolak.' END message;
 END TRY BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; SELECT 0 success,N'Terjadi kesalahan: '+ERROR_MESSAGE() message; END CATCH;
END;
GO

/* ========================================================================== */
/* 5. LAPORAN ASSET                                                           */
/* ========================================================================== */
CREATE OR ALTER PROCEDURE dbo.udp_asset_report_get_periods @requester_userid VARCHAR(50),@tahun INT=NULL AS
BEGIN
 SET NOCOUNT ON; DECLARE @company_id INT;
 SELECT TOP(1) @company_id=ci.company_id FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
 WHERE u.userid=@requester_userid AND u.active=1 AND ISNULL(u.deleted,0)=0 AND UPPER(ISNULL(ci.organization,'')) LIKE '%HRD%'
 AND (UPPER(ISNULL(ci.job_position,'')) LIKE '%HEAD%' OR UPPER(ISNULL(ci.job_level,''))='HEAD');
 IF @company_id IS NULL THROW 51913,'Hanya Head HRD aktif yang dapat melihat laporan asset.',1;
 SELECT id,tahun,bulan,tanggal_mulai,tanggal_selesai,keterangan FROM dbo.udt_work_period
 WHERE company_id=@company_id AND (@tahun IS NULL OR tahun=@tahun) AND ISNULL(deleted,0)=0 ORDER BY tahun DESC,bulan DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_asset_report_get_employees_in_period @requester_userid VARCHAR(50),@work_period_id INT AS
BEGIN
 SET NOCOUNT ON; DECLARE @company_id INT,@start DATE,@end DATE;
 SELECT TOP(1) @company_id=ci.company_id FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
 WHERE u.userid=@requester_userid AND u.active=1 AND ISNULL(u.deleted,0)=0 AND UPPER(ISNULL(ci.organization,'')) LIKE '%HRD%'
 AND (UPPER(ISNULL(ci.job_position,'')) LIKE '%HEAD%' OR UPPER(ISNULL(ci.job_level,''))='HEAD');
 SELECT @start=tanggal_mulai,@end=tanggal_selesai FROM dbo.udt_work_period
 WHERE id=@work_period_id AND company_id=@company_id AND ISNULL(deleted,0)=0;
 SELECT r.userid,u.name,ci.job_position,COUNT(*) jumlah_transaksi FROM dbo.udt_asset_requests r
 INNER JOIN dbo.udt_users u ON u.userid=r.userid INNER JOIN dbo.udt_company_info_user ci ON ci.userid=r.userid AND ci.company_id=r.company_id
 WHERE r.company_id=@company_id AND r.status IN('Approved','Dikembalikan') AND CONVERT(DATE,r.approved_at) BETWEEN @start AND @end
 GROUP BY r.userid,u.name,ci.job_position ORDER BY u.name;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_asset_report_get_detail
 @requester_userid VARCHAR(50),@userid VARCHAR(50),@work_period_id INT AS
BEGIN
 SET NOCOUNT ON; DECLARE @company_id INT,@start DATE,@end DATE;
 SELECT TOP(1) @company_id=ci.company_id FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
 WHERE u.userid=@requester_userid AND u.active=1 AND ISNULL(u.deleted,0)=0 AND UPPER(ISNULL(ci.organization,'')) LIKE '%HRD%'
 AND (UPPER(ISNULL(ci.job_position,'')) LIKE '%HEAD%' OR UPPER(ISNULL(ci.job_level,''))='HEAD');
 SELECT @start=tanggal_mulai,@end=tanggal_selesai FROM dbo.udt_work_period WHERE id=@work_period_id AND company_id=@company_id AND ISNULL(deleted,0)=0;
 SELECT r.id,r.approved_at,ai.nama_barang,ai.kategori,r.kategori jenis,r.jumlah,o.office_name,r.status
 FROM dbo.udt_asset_requests r INNER JOIN dbo.udt_asset_items ai ON ai.id=r.asset_item_id AND ai.company_id=r.company_id
 LEFT JOIN dbo.udt_office_locations o ON o.id=ai.office_location_id AND o.company_id=r.company_id
 WHERE r.company_id=@company_id AND r.userid=@userid AND r.status IN('Approved','Dikembalikan')
 AND CONVERT(DATE,r.approved_at) BETWEEN @start AND @end ORDER BY r.approved_at;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_asset_report_get_header_info
 @requester_userid VARCHAR(50),@userid VARCHAR(50),@work_period_id INT AS
BEGIN
 SET NOCOUNT ON; DECLARE @company_id INT,@head VARCHAR(50),@head_name NVARCHAR(200);
 SELECT TOP(1) @company_id=ci.company_id FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
 WHERE u.userid=@requester_userid AND u.active=1 AND ISNULL(u.deleted,0)=0 AND UPPER(ISNULL(ci.organization,'')) LIKE '%HRD%'
 AND (UPPER(ISNULL(ci.job_position,'')) LIKE '%HEAD%' OR UPPER(ISNULL(ci.job_level,''))='HEAD');
 SELECT TOP(1) @head=ci.userid,@head_name=u.name FROM dbo.udt_company_info_user ci INNER JOIN dbo.udt_users u ON u.userid=ci.userid
 WHERE ci.company_id=@company_id AND u.active=1 AND ISNULL(u.deleted,0)=0 AND UPPER(ISNULL(ci.organization,'')) LIKE '%HRD%'
 AND (UPPER(ISNULL(ci.job_position,'')) LIKE '%HEAD%' OR UPPER(ISNULL(ci.job_level,''))='HEAD')
 ORDER BY CASE WHEN UPPER(ISNULL(ci.job_position,'')) LIKE 'HEAD%' THEN 0 ELSE 1 END,ci.userid;
 SELECT u.userid karyawan_userid,u.name nama_karyawan,ci.job_position,ci.organization,wp.tahun,wp.bulan,
  wp.tanggal_mulai,wp.tanggal_selesai,wp.keterangan periode_keterangan,@head head_hrd_userid,@head_name nama_head_hrd
 FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid AND ci.company_id=@company_id
 INNER JOIN dbo.udt_work_period wp ON wp.id=@work_period_id AND wp.company_id=@company_id AND ISNULL(wp.deleted,0)=0
 WHERE u.userid=@userid AND ISNULL(u.deleted,0)=0;
END;
GO

/* Verifikasi struktur dan jumlah data per perusahaan. */
SELECT 'category' entity,company_id,COUNT(*) total FROM dbo.udt_asset_categories GROUP BY company_id
UNION ALL SELECT 'item',company_id,COUNT(*) FROM dbo.udt_asset_items GROUP BY company_id
UNION ALL SELECT 'request',company_id,COUNT(*) FROM dbo.udt_asset_requests GROUP BY company_id
ORDER BY entity,company_id;
GO

SELECT name,modify_date FROM sys.procedures WHERE name LIKE 'udp_asset_%' ORDER BY name;
GO

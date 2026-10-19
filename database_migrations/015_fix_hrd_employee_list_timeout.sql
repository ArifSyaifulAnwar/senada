/*
  SENADA - Perbaikan timeout daftar karyawan HRD

  Akar masalah:
  udp_hrd_employee_list lama mengubah FotoProfil VARBINARY(MAX) menjadi hex
  untuk SETIAP karyawan. Daftar 35 karyawan dapat memerlukan sekitar 88 detik,
  sedangkan command timeout API hanya 30 detik.

  Perbaikan:
  - list tidak lagi membawa foto penuh (foto tetap tersedia dari endpoint detail);
  - isolasi tenant memakai company_id, bukan teks company_name;
  - requester harus aktif dan mempunyai akses HRD/Admin/Direktur;
  - manager hanya boleh dibaca dari perusahaan yang sama;
  - menambahkan index untuk pencarian anggota perusahaan.
*/

USE [ABSENSI];
GO
SET XACT_ABORT ON;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.udt_company_info_user')
      AND name = 'IX_company_info_user_company_userid'
)
BEGIN
    CREATE INDEX IX_company_info_user_company_userid
        ON dbo.udt_company_info_user(company_id, userid)
        INCLUDE(employeeID, organization, employment_status, manager);
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_hrd_employee_list
    @hrdUserId   NVARCHAR(50),
    @searchQuery NVARCHAR(100) = NULL,
    @department  NVARCHAR(100) = NULL,
    @status      NVARCHAR(50)  = NULL,
    @sortBy      NVARCHAR(50)  = 'name_asc',
    @page        INT           = 1,
    @pageSize    INT           = 50
AS
BEGIN
    SET NOCOUNT ON;

    SET @hrdUserId = NULLIF(LTRIM(RTRIM(@hrdUserId)), '');
    SET @searchQuery = NULLIF(LTRIM(RTRIM(@searchQuery)), '');
    SET @department = NULLIF(LTRIM(RTRIM(@department)), '');
    SET @status = NULLIF(LTRIM(RTRIM(@status)), '');
    SET @sortBy = LOWER(ISNULL(NULLIF(LTRIM(RTRIM(@sortBy)), ''), 'name_asc'));

    IF @hrdUserId IS NULL
        THROW 51500, 'HrdUserId wajib diisi.', 1;

    DECLARE @companyId INT;
    DECLARE @hasAccess BIT = 0;

    SELECT TOP (1)
        @companyId = ci.company_id,
        @hasAccess = CASE
            WHEN UPPER(LTRIM(RTRIM(ISNULL(u.role, '')))) IN ('HRD', 'ADMIN') THEN 1
            WHEN UPPER(LTRIM(RTRIM(ISNULL(ci.organization, ''))))
                IN ('HRD', 'HRD & GA', 'HRD&GA') THEN 1
            WHEN UPPER(ISNULL(ci.organization, '')) LIKE '%DIREKTUR%' THEN 1
            WHEN UPPER(ISNULL(ci.job_position, '')) LIKE '%DIREKTUR%' THEN 1
            ELSE 0
        END
    FROM dbo.udt_users u
    INNER JOIN dbo.udt_company_info_user ci ON ci.userid = u.userid
    INNER JOIN dbo.udt_companies c
        ON c.id = ci.company_id
       AND c.is_active = 1
    WHERE u.userid = @hrdUserId
      AND u.active = 1
      AND ISNULL(u.deleted, 0) = 0;

    IF @companyId IS NULL
        THROW 51501, 'Akun tidak aktif atau belum terhubung ke perusahaan.', 1;

    IF @hasAccess = 0
        THROW 51502, 'Akun tidak memiliki akses daftar karyawan.', 1;

    IF @page IS NULL OR @page < 1 SET @page = 1;
    IF @pageSize IS NULL OR @pageSize < 1 SET @pageSize = 50;
    IF @pageSize > 1000 SET @pageSize = 1000;

    IF @sortBy NOT IN ('name_asc', 'name_desc', 'join_date_asc', 'join_date_desc')
        SET @sortBy = 'name_asc';

    DECLARE @offset INT = (@page - 1) * @pageSize;

    ;WITH filtered AS
    (
        SELECT
            u.id,
            u.userid,
            u.name,
            u.mail,
            u.phone,
            u.additional_phone,
            u.address,
            u.citizen_id_address,
            u.residential_address,
            u.postal_code,
            u.jobs,
            u.gender,
            u.place_of_birth,
            u.birth_date,
            u.marital_status,
            u.blood_type,
            u.religion,
            u.nik,
            u.nip,
            u.npwp,
            u.passport_number,
            u.passport_expiry,
            u.active,
            u.last_login,
            u.created_at,
            u.updated_at,

            /* Foto penuh hanya diambil oleh endpoint detail. */
            CAST(NULL AS NVARCHAR(MAX)) AS FotoProfil,

            ci.employeeID,
            ci.barcode,
            ci.company_name,
            ci.branch,
            ci.organization AS department,
            ci.job_position,
            ci.job_level,
            ci.employment_status,
            ci.join_date,
            ci.end_contract_date,
            ci.working_period_year,
            ci.working_period_month,
            ci.working_period_day,
            ci.grade,
            ci.class,
            ci.approval_line,
            ci.manager AS manager_userid,
            mgr.name AS manager,
            mgr.name AS manager_name,
            ci.bank_name,
            ci.bank_account_number,
            ci.bank_account_name,
            CASE
                WHEN u.active = 0 THEN 'Non-Aktif'
                WHEN UPPER(LTRIM(RTRIM(ISNULL(ci.employment_status, '')))) = 'CUTI'
                    THEN 'Cuti'
                ELSE 'Aktif'
            END AS status_display
        FROM dbo.udt_users u
        INNER JOIN dbo.udt_company_info_user ci
            ON ci.userid = u.userid
           AND ci.company_id = @companyId
        LEFT JOIN dbo.udt_company_info_user mgrCi
            ON mgrCi.userid = ci.manager
           AND mgrCi.company_id = @companyId
        LEFT JOIN dbo.udt_users mgr
            ON mgr.userid = mgrCi.userid
           AND ISNULL(mgr.deleted, 0) = 0
        WHERE ISNULL(u.deleted, 0) = 0
          AND
          (
              @searchQuery IS NULL
              OR u.name LIKE '%' + @searchQuery + '%'
              OR ci.employeeID LIKE '%' + @searchQuery + '%'
              OR u.mail LIKE '%' + @searchQuery + '%'
          )
          AND (@department IS NULL OR ci.organization = @department)
          AND
          (
              @status IS NULL
              OR CASE
                    WHEN u.active = 0 THEN 'Non-Aktif'
                    WHEN UPPER(LTRIM(RTRIM(ISNULL(ci.employment_status, '')))) = 'CUTI'
                        THEN 'Cuti'
                    ELSE 'Aktif'
                 END = @status
          )
    )
    SELECT
        *,
        COUNT(1) OVER () AS total_count
    FROM filtered
    ORDER BY
        CASE WHEN @sortBy = 'name_asc'       THEN name      END ASC,
        CASE WHEN @sortBy = 'name_desc'      THEN name      END DESC,
        CASE WHEN @sortBy = 'join_date_asc'  THEN join_date END ASC,
        CASE WHEN @sortBy = 'join_date_desc' THEN join_date END DESC,
        name ASC,
        id ASC
    OFFSET @offset ROWS FETCH NEXT @pageSize ROWS ONLY;
END;
GO

/* Verifikasi metadata result set. */
EXEC sys.sp_describe_first_result_set
    @tsql = N'EXEC dbo.udp_hrd_employee_list
        @hrdUserId = ''23100020'',
        @searchQuery = NULL,
        @department = NULL,
        @status = ''Aktif'',
        @sortBy = ''name_asc'',
        @page = 1,
        @pageSize = 1000;';
GO


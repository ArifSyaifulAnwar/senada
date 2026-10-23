/*
  SENADA - Daftar dan detail karyawan per perusahaan

  Daftar karyawan selalu menggunakan company_id akun yang sedang login.
  Tidak ada lagi fallback global atau pencocokan company_name.
*/
USE [ABSENSI];
GO
SET XACT_ABORT ON;
GO

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id=OBJECT_ID('dbo.udt_company_info_user')
      AND name='IX_company_info_user_company_directory'
)
    CREATE INDEX IX_company_info_user_company_directory
    ON dbo.udt_company_info_user(company_id, organization, userid)
    INCLUDE(employeeID, job_position, employment_status, join_date);
GO

CREATE OR ALTER PROCEDURE dbo.udp_employee_get_all
    @search_query NVARCHAR(100)=NULL,
    @department NVARCHAR(100)=NULL,
    @status NVARCHAR(50)=NULL,
    @sort_by NVARCHAR(50)='name_asc',
    @page INT=1,
    @page_size INT=1000,
    @user_id VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SET @user_id=NULLIF(LTRIM(RTRIM(@user_id)), '');
    SET @search_query=NULLIF(LTRIM(RTRIM(@search_query)), '');
    SET @department=NULLIF(LTRIM(RTRIM(@department)), '');
    SET @status=NULLIF(LTRIM(RTRIM(@status)), '');
    SET @sort_by=LOWER(ISNULL(NULLIF(LTRIM(RTRIM(@sort_by)),''),'name_asc'));
    IF @user_id IS NULL THROW 52500,'UserId peminta wajib diisi.',1;

    DECLARE @company_id INT;
    SELECT TOP(1) @company_id=ci.company_id
    FROM dbo.udt_users requester
    INNER JOIN dbo.udt_company_info_user ci ON ci.userid=requester.userid
    INNER JOIN dbo.udt_companies co ON co.id=ci.company_id AND co.is_active=1
    WHERE requester.userid=@user_id AND requester.active=1 AND ISNULL(requester.deleted,0)=0;
    IF @company_id IS NULL THROW 52501,'Akun tidak aktif atau belum terhubung ke perusahaan.',1;

    IF @page IS NULL OR @page<1 SET @page=1;
    IF @page_size IS NULL OR @page_size<1 SET @page_size=50;
    IF @page_size>1000 SET @page_size=1000;
    IF @sort_by NOT IN ('name_asc','name_desc','join_date_asc','join_date_desc') SET @sort_by='name_asc';
    DECLARE @offset INT=(@page-1)*@page_size;

    SELECT u.id,u.userid,u.name,u.mail,u.phone,u.address,u.gender,u.birth_date,u.nik,u.nip,u.npwp,
           u.active,u.last_login,u.created_at,
           CAST(NULL AS VARBINARY(MAX)) FotoProfil,
           c.employeeID,c.company_name,c.branch,c.organization,c.job_position,c.job_level,
           c.employment_status,c.join_date,c.end_contract_date,c.working_period_year,
           c.working_period_month,c.working_period_day,c.grade,c.class,c.approval_line,c.manager,
           CASE WHEN u.active=0 THEN 'Non-Aktif'
                WHEN c.end_contract_date IS NOT NULL AND c.end_contract_date<GETDATE() THEN 'Non-Aktif'
                WHEN UPPER(ISNULL(c.employment_status,''))='CUTI' THEN 'Cuti'
                ELSE 'Aktif' END status_display,
           CONCAT_WS(',',c.job_position,c.organization) skills,
           COUNT(*) OVER() total_count,
           CEILING(CAST(COUNT(*) OVER() AS FLOAT)/@page_size) total_pages
    INTO #directory
    FROM dbo.udt_users u
    INNER JOIN dbo.udt_company_info_user c ON c.userid=u.userid AND c.company_id=@company_id
    WHERE ISNULL(u.deleted,0)=0
      AND (@search_query IS NULL OR u.name LIKE '%'+@search_query+'%' OR u.mail LIKE '%'+@search_query+'%' OR c.employeeID LIKE '%'+@search_query+'%')
      AND (@department IS NULL OR c.organization=@department)
      AND (@status IS NULL OR CASE WHEN u.active=0 THEN 'Non-Aktif'
                    WHEN c.end_contract_date IS NOT NULL AND c.end_contract_date<GETDATE() THEN 'Non-Aktif'
                    WHEN UPPER(ISNULL(c.employment_status,''))='CUTI' THEN 'Cuti' ELSE 'Aktif' END=@status);

    SELECT * FROM #directory
    ORDER BY CASE WHEN @sort_by='name_asc' THEN name END ASC,
             CASE WHEN @sort_by='name_desc' THEN name END DESC,
             CASE WHEN @sort_by='join_date_asc' THEN join_date END ASC,
             CASE WHEN @sort_by='join_date_desc' THEN join_date END DESC,
             name,id
    OFFSET @offset ROWS FETCH NEXT @page_size ROWS ONLY;

    SELECT COUNT(*) total_employees,
           SUM(CASE WHEN active=1 AND (end_contract_date IS NULL OR end_contract_date>=GETDATE()) AND ISNULL(employment_status,'')<>'Cuti' THEN 1 ELSE 0 END) active_employees,
           SUM(CASE WHEN UPPER(ISNULL(employment_status,''))='CUTI' THEN 1 ELSE 0 END) on_leave_employees,
           SUM(CASE WHEN active=0 OR (end_contract_date IS NOT NULL AND end_contract_date<GETDATE()) THEN 1 ELSE 0 END) inactive_employees
    FROM #directory;

    SELECT organization department,COUNT(*) total_employees,
           SUM(CASE WHEN active=1 AND (end_contract_date IS NULL OR end_contract_date>=GETDATE()) AND ISNULL(employment_status,'')<>'Cuti' THEN 1 ELSE 0 END) active_employees,
           SUM(CASE WHEN UPPER(ISNULL(employment_status,''))='CUTI' THEN 1 ELSE 0 END) on_leave_employees,
           SUM(CASE WHEN active=0 OR (end_contract_date IS NOT NULL AND end_contract_date<GETDATE()) THEN 1 ELSE 0 END) inactive_employees
    FROM #directory WHERE organization IS NOT NULL GROUP BY organization ORDER BY organization;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_employee_get_detail
    @employee_id INT=NULL,
    @userid VARCHAR(50)=NULL,
    @employeeID VARCHAR(255)=NULL,
    @request_user_id VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SET @request_user_id=NULLIF(LTRIM(RTRIM(@request_user_id)), '');
    IF @request_user_id IS NULL THROW 52502,'UserId peminta wajib diisi.',1;
    DECLARE @company_id INT;
    SELECT TOP(1) @company_id=ci.company_id
    FROM dbo.udt_users requester INNER JOIN dbo.udt_company_info_user ci ON ci.userid=requester.userid
    INNER JOIN dbo.udt_companies co ON co.id=ci.company_id AND co.is_active=1
    WHERE requester.userid=@request_user_id AND requester.active=1 AND ISNULL(requester.deleted,0)=0;
    IF @company_id IS NULL THROW 52503,'Akun tidak aktif atau belum terhubung ke perusahaan.',1;

    SELECT TOP(1) u.id,u.userid,u.name,u.mail,u.phone,u.additional_phone,u.address,u.citizen_id_address,
      u.residential_address,u.postal_code,u.jobs,u.gender,u.place_of_birth,u.birth_date,u.marital_status,
      u.blood_type,u.religion,u.nik,u.npwp,u.nip,u.passport_number,u.passport_expiry,u.active,u.last_login,
      u.created_at,u.updated_at,u.FotoProfil,c.employeeID,c.barcode,c.company_name,c.branch,c.organization,
      c.job_position,c.job_level,c.employment_status,c.join_date,c.end_contract_date,c.working_period_year,
      c.working_period_month,c.working_period_day,c.grade,c.class,c.approval_line,c.manager,
      CASE WHEN u.active=0 THEN 'Non-Aktif' WHEN c.end_contract_date IS NOT NULL AND c.end_contract_date<GETDATE() THEN 'Non-Aktif'
           WHEN UPPER(ISNULL(c.employment_status,''))='CUTI' THEN 'Cuti' ELSE 'Aktif' END status_display
    FROM dbo.udt_users u
    INNER JOIN dbo.udt_company_info_user c ON c.userid=u.userid AND c.company_id=@company_id
    WHERE ISNULL(u.deleted,0)=0
      AND ((@userid IS NOT NULL AND u.userid=@userid)
       OR (@userid IS NULL AND @employee_id IS NOT NULL AND u.id=@employee_id)
       OR (@userid IS NULL AND @employeeID IS NOT NULL AND c.employeeID=@employeeID));
END;
GO

SELECT name,modify_date FROM sys.procedures
WHERE name IN ('udp_employee_get_all','udp_employee_get_detail') ORDER BY name;
GO

/*
  SENADA - Otorisasi TTD per perusahaan
  TTD disimpan sebagai file, sehingga tenant ditentukan saat akses dari user
  peminta dan target user. Tidak ada company_id dari client yang dipercaya.
*/
USE [ABSENSI];
GO
SET XACT_ABORT ON;
GO

CREATE OR ALTER PROCEDURE dbo.udp_signature_authorize
    @request_user_id VARCHAR(50),
    @target_user_id  VARCHAR(50),
    @require_hrd     BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @request_company_id INT, @target_company_id INT, @is_hrd BIT=0;

    SELECT TOP(1)
      @request_company_id=ci.company_id,
      @is_hrd=CASE WHEN UPPER(ISNULL(u.role,'')) IN('HRD','ADMIN')
                    OR UPPER(ISNULL(ci.organization,'')) LIKE '%HRD%'
                    OR UPPER(ISNULL(ci.organization,'')) LIKE '%DIREKTUR%'
                    OR UPPER(ISNULL(ci.job_position,'')) LIKE '%DIREKTUR%'
                   THEN 1 ELSE 0 END
    FROM dbo.udt_users u
    INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
    INNER JOIN dbo.udt_companies c ON c.id=ci.company_id AND c.is_active=1
    WHERE u.userid=@request_user_id AND u.active=1 AND ISNULL(u.deleted,0)=0;

    SELECT TOP(1) @target_company_id=ci.company_id
    FROM dbo.udt_users u
    INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
    WHERE u.userid=@target_user_id AND u.active=1 AND ISNULL(u.deleted,0)=0;

    SELECT CAST(CASE
      WHEN @request_company_id IS NULL OR @request_company_id<>@target_company_id THEN 0
      WHEN @require_hrd=1 AND @is_hrd=0 THEN 0
      WHEN @require_hrd=0 AND @request_user_id<>@target_user_id AND @is_hrd=0 THEN 0
      ELSE 1 END AS BIT) AS is_authorized;
END;
GO

SELECT name,modify_date FROM sys.procedures WHERE name='udp_signature_authorize';
GO

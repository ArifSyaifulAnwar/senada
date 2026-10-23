/*
  SENADA - Otorisasi actor Izin/Dinas Luar per perusahaan

  Setiap akses pengajuan berdasarkan ID wajib memvalidasi actor login. Actor
  dapat mengakses apabila ia pemilik pengajuan, approver yang memang ditunjuk,
  atau HRD/Admin/Direktur aktif dari PT yang sama.
*/
USE [ABSENSI];
GO
SET XACT_ABORT ON;
GO

CREATE OR ALTER PROCEDURE dbo.udp_timeoff_actor_authorize
    @timeOffId INT,
    @actorUserId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @company_id INT, @privileged BIT = 0;

    SELECT TOP (1)
        @company_id = ci.company_id,
        @privileged = CASE
            WHEN UPPER(ISNULL(u.role, '')) IN ('HRD', 'ADMIN') THEN 1
            WHEN UPPER(ISNULL(ci.organization, '')) LIKE '%HRD%' THEN 1
            WHEN UPPER(ISNULL(ci.organization, '')) LIKE '%DIREKTUR%' THEN 1
            WHEN UPPER(ISNULL(ci.job_position, '')) LIKE '%DIREKTUR%' THEN 1
            ELSE 0 END
    FROM dbo.udt_users u
    INNER JOIN dbo.udt_company_info_user ci ON ci.userid = u.userid
    INNER JOIN dbo.udt_companies co ON co.id = ci.company_id AND co.is_active = 1
    WHERE u.userid = @actorUserId
      AND u.active = 1
      AND ISNULL(u.deleted, 0) = 0;

    SELECT CAST(CASE WHEN @company_id IS NOT NULL AND EXISTS
    (
        SELECT 1
        FROM dbo.udt_timeoff t
        WHERE t.id = @timeOffId
          AND t.company_id = @company_id
          AND
          (
              @privileged = 1
              OR t.userid = @actorUserId
              OR t.manager_userid = @actorUserId
              OR t.finance_userid = @actorUserId
              OR t.laporan_head_userid = @actorUserId
              OR t.hrd_approved_by = @actorUserId
          )
    ) THEN 1 ELSE 0 END AS BIT) AS is_authorized;
END;
GO

SELECT name, modify_date
FROM sys.procedures
WHERE name = 'udp_timeoff_actor_authorize';
GO

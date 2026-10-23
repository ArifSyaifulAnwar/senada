/* Soft-delete akun sendiri: password wajib, data PT dan histori tetap utuh. */
USE [ABSENSI];
GO
SET XACT_ABORT ON;
GO

CREATE OR ALTER PROCEDURE dbo.udp_self_delete_account
    @UserId        VARCHAR(50),
    @Password      VARCHAR(255),
    @ResultCode    INT OUTPUT,
    @ResultMessage VARCHAR(255) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @ResultCode = -99;
    SET @ResultMessage = 'Gagal menghapus akun.';
    SET @UserId = NULLIF(LTRIM(RTRIM(@UserId)), '');

    IF @UserId IS NULL OR NULLIF(@Password, '') IS NULL
    BEGIN SET @ResultCode=-10; SET @ResultMessage='UserId dan password wajib diisi.'; RETURN; END;

    DECLARE @company_id INT;
    SELECT @company_id=ci.company_id
    FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
    INNER JOIN dbo.udt_companies c ON c.id=ci.company_id AND c.is_active=1
    WHERE u.userid=@UserId AND u.active=1 AND ISNULL(u.deleted,0)=0
      AND u.pw=HASHBYTES('SHA2_256',@Password);
    IF @company_id IS NULL
    BEGIN SET @ResultCode=-11; SET @ResultMessage='Password salah atau akun tidak aktif.'; RETURN; END;

    /* Jangan meninggalkan perusahaan tanpa satu pun pengelola aktif. */
    IF EXISTS
    (
      SELECT 1 FROM dbo.udt_company_info_user ci INNER JOIN dbo.udt_users u ON u.userid=ci.userid
      WHERE ci.userid=@UserId AND ci.company_id=@company_id AND u.active=1 AND ISNULL(u.deleted,0)=0
        AND (UPPER(ISNULL(u.role,'')) IN('HRD','ADMIN') OR UPPER(ISNULL(ci.organization,'')) LIKE '%HRD%')
    )
    AND NOT EXISTS
    (
      SELECT 1 FROM dbo.udt_company_info_user ci INNER JOIN dbo.udt_users u ON u.userid=ci.userid
      WHERE ci.userid<>@UserId AND ci.company_id=@company_id AND u.active=1 AND ISNULL(u.deleted,0)=0
        AND (UPPER(ISNULL(u.role,'')) IN('HRD','ADMIN') OR UPPER(ISNULL(ci.organization,'')) LIKE '%HRD%')
    )
    BEGIN SET @ResultCode=-12; SET @ResultMessage='Akun tidak dapat dihapus karena merupakan pengelola terakhir perusahaan.'; RETURN; END;

    UPDATE dbo.udt_users SET active=0,deleted=1,updated_at=GETDATE(),updateby=@UserId
    WHERE userid=@UserId AND active=1 AND ISNULL(deleted,0)=0;
    IF @@ROWCOUNT<>1 BEGIN SET @ResultCode=-13; SET @ResultMessage='Akun tidak ditemukan atau sudah dihapus.'; RETURN; END;
    SET @ResultCode=1; SET @ResultMessage='Akun berhasil dinonaktifkan.';
END;
GO

SELECT name,modify_date FROM sys.procedures WHERE name='udp_self_delete_account';
GO

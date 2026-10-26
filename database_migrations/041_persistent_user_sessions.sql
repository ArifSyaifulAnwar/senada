/*
  SENADA - Sesi login persisten dengan refresh-token berotasi

  Access token tetap singkat (8 jam), tetapi aplikasi dapat memperbaruinya
  otomatis selama pengguna belum logout dan refresh token masih aktif.
  Token mentah tidak pernah disimpan di database, hanya hash SHA-256-nya.
*/
USE [ABSENSI];
GO
SET XACT_ABORT ON;
GO

IF OBJECT_ID('dbo.udt_user_refresh_session', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.udt_user_refresh_session
    (
        id BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_udt_user_refresh_session PRIMARY KEY,
        userid VARCHAR(50) NOT NULL,
        token_hash CHAR(64) NOT NULL,
        expires_at DATETIME2(0) NOT NULL,
        created_at DATETIME2(0) NOT NULL CONSTRAINT DF_udt_user_refresh_session_created_at DEFAULT SYSUTCDATETIME(),
        last_used_at DATETIME2(0) NULL,
        revoked_at DATETIME2(0) NULL
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.udt_user_refresh_session') AND name='UX_user_refresh_session_hash')
    CREATE UNIQUE INDEX UX_user_refresh_session_hash ON dbo.udt_user_refresh_session(token_hash);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.udt_user_refresh_session') AND name='IX_user_refresh_session_valid')
    CREATE INDEX IX_user_refresh_session_valid ON dbo.udt_user_refresh_session(userid, expires_at, revoked_at);
GO

CREATE OR ALTER PROCEDURE dbo.usp_user_refresh_session_create
    @UserId VARCHAR(50), @TokenHash CHAR(64), @ExpiresAt DATETIME2(0)
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM dbo.udt_users WHERE userid=@UserId AND active=1 AND ISNULL(deleted,0)=0)
        THROW 54100, 'Akun tidak aktif atau tidak ditemukan.', 1;
    INSERT dbo.udt_user_refresh_session(userid,token_hash,expires_at)
    VALUES(@UserId,@TokenHash,@ExpiresAt);
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_user_refresh_session_rotate
    @CurrentTokenHash CHAR(64), @NewTokenHash CHAR(64), @NewExpiresAt DATETIME2(0)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @UserId VARCHAR(50);
    BEGIN TRANSACTION;
    SELECT @UserId=s.userid
    FROM dbo.udt_user_refresh_session s WITH (UPDLOCK,HOLDLOCK)
    INNER JOIN dbo.udt_users u ON u.userid=s.userid AND u.active=1 AND ISNULL(u.deleted,0)=0
    WHERE s.token_hash=@CurrentTokenHash AND s.revoked_at IS NULL AND s.expires_at>SYSUTCDATETIME();

    IF @UserId IS NULL
    BEGIN
        ROLLBACK TRANSACTION;
        RETURN;
    END;
    UPDATE dbo.udt_user_refresh_session SET revoked_at=SYSUTCDATETIME(),last_used_at=SYSUTCDATETIME()
    WHERE token_hash=@CurrentTokenHash AND revoked_at IS NULL;
    INSERT dbo.udt_user_refresh_session(userid,token_hash,expires_at)
    VALUES(@UserId,@NewTokenHash,@NewExpiresAt);
    COMMIT TRANSACTION;

    SELECT u.userid,u.role FROM dbo.udt_users u WHERE u.userid=@UserId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_user_refresh_session_revoke
    @TokenHash CHAR(64)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.udt_user_refresh_session
    SET revoked_at=SYSUTCDATETIME(),last_used_at=SYSUTCDATETIME()
    WHERE token_hash=@TokenHash AND revoked_at IS NULL;
END;
GO

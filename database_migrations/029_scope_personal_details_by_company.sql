/*
  SENADA - Kontak Darurat, Keluarga, Pendidikan, dan Pengalaman per PT.
  Teguran telah memakai company_id melalui migration 020.
*/
USE [ABSENSI];
GO
SET XACT_ABORT ON;
GO

IF COL_LENGTH('dbo.udt_emergency_contacts','company_id') IS NULL ALTER TABLE dbo.udt_emergency_contacts ADD company_id INT NULL;
IF COL_LENGTH('dbo.udt_family_members','company_id') IS NULL ALTER TABLE dbo.udt_family_members ADD company_id INT NULL;
IF COL_LENGTH('dbo.udt_educations','company_id') IS NULL ALTER TABLE dbo.udt_educations ADD company_id INT NULL;
IF COL_LENGTH('dbo.udt_experiences','company_id') IS NULL ALTER TABLE dbo.udt_experiences ADD company_id INT NULL;
GO

UPDATE x SET company_id=ci.company_id FROM dbo.udt_emergency_contacts x INNER JOIN dbo.udt_company_info_user ci ON ci.userid=x.user_id WHERE x.company_id IS NULL;
UPDATE x SET company_id=ci.company_id FROM dbo.udt_family_members x INNER JOIN dbo.udt_company_info_user ci ON ci.userid=x.userid WHERE x.company_id IS NULL;
UPDATE x SET company_id=ci.company_id FROM dbo.udt_educations x INNER JOIN dbo.udt_company_info_user ci ON ci.userid=x.userid WHERE x.company_id IS NULL;
UPDATE x SET company_id=ci.company_id FROM dbo.udt_experiences x INNER JOIN dbo.udt_company_info_user ci ON ci.userid=x.userid WHERE x.company_id IS NULL;
GO

IF EXISTS(SELECT 1 FROM dbo.udt_emergency_contacts WHERE company_id IS NULL)
 OR EXISTS(SELECT 1 FROM dbo.udt_family_members WHERE company_id IS NULL)
 OR EXISTS(SELECT 1 FROM dbo.udt_educations WHERE company_id IS NULL)
 OR EXISTS(SELECT 1 FROM dbo.udt_experiences WHERE company_id IS NULL)
    THROW 52900, 'Masih ada detail profil tanpa perusahaan.',1;
GO

IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_emergency_contacts_company') ALTER TABLE dbo.udt_emergency_contacts WITH CHECK ADD CONSTRAINT FK_emergency_contacts_company FOREIGN KEY(company_id) REFERENCES dbo.udt_companies(id);
IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_family_members_company') ALTER TABLE dbo.udt_family_members WITH CHECK ADD CONSTRAINT FK_family_members_company FOREIGN KEY(company_id) REFERENCES dbo.udt_companies(id);
IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_educations_company') ALTER TABLE dbo.udt_educations WITH CHECK ADD CONSTRAINT FK_educations_company FOREIGN KEY(company_id) REFERENCES dbo.udt_companies(id);
IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_experiences_company') ALTER TABLE dbo.udt_experiences WITH CHECK ADD CONSTRAINT FK_experiences_company FOREIGN KEY(company_id) REFERENCES dbo.udt_companies(id);
GO

IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.udt_emergency_contacts') AND name='IX_emergency_contacts_company_user') CREATE INDEX IX_emergency_contacts_company_user ON dbo.udt_emergency_contacts(company_id,user_id,is_active);
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.udt_family_members') AND name='IX_family_members_company_user') CREATE INDEX IX_family_members_company_user ON dbo.udt_family_members(company_id,userid,is_active);
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.udt_educations') AND name='IX_educations_company_user') CREATE INDEX IX_educations_company_user ON dbo.udt_educations(company_id,userid,is_active);
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.udt_experiences') AND name='IX_experiences_company_user') CREATE INDEX IX_experiences_company_user ON dbo.udt_experiences(company_id,userid,is_active);
GO

/* Legacy create procedure tidak membawa company_id; trigger mengisinya dari pemilik. */
CREATE OR ALTER TRIGGER dbo.trg_emergency_contacts_company_guard ON dbo.udt_emergency_contacts AFTER INSERT,UPDATE AS
BEGIN
 SET NOCOUNT ON;
 UPDATE x SET company_id=ci.company_id FROM dbo.udt_emergency_contacts x INNER JOIN inserted i ON i.id=x.id INNER JOIN dbo.udt_company_info_user ci ON ci.userid=x.user_id WHERE x.company_id IS NULL;
 IF EXISTS(SELECT 1 FROM inserted i INNER JOIN dbo.udt_emergency_contacts x ON x.id=i.id LEFT JOIN dbo.udt_company_info_user ci ON ci.userid=x.user_id WHERE ci.company_id IS NULL OR x.company_id<>ci.company_id) THROW 52901,'Perusahaan kontak darurat tidak sesuai dengan pemilik.',1;
END;
GO
CREATE OR ALTER TRIGGER dbo.trg_family_members_company_guard ON dbo.udt_family_members AFTER INSERT,UPDATE AS
BEGIN
 SET NOCOUNT ON;
 UPDATE x SET company_id=ci.company_id FROM dbo.udt_family_members x INNER JOIN inserted i ON i.id=x.id INNER JOIN dbo.udt_company_info_user ci ON ci.userid=x.userid WHERE x.company_id IS NULL;
 IF EXISTS(SELECT 1 FROM inserted i INNER JOIN dbo.udt_family_members x ON x.id=i.id LEFT JOIN dbo.udt_company_info_user ci ON ci.userid=x.userid WHERE ci.company_id IS NULL OR x.company_id<>ci.company_id) THROW 52902,'Perusahaan keluarga tidak sesuai dengan pemilik.',1;
END;
GO
CREATE OR ALTER TRIGGER dbo.trg_educations_company_guard ON dbo.udt_educations AFTER INSERT,UPDATE AS
BEGIN
 SET NOCOUNT ON;
 UPDATE x SET company_id=ci.company_id FROM dbo.udt_educations x INNER JOIN inserted i ON i.id=x.id INNER JOIN dbo.udt_company_info_user ci ON ci.userid=x.userid WHERE x.company_id IS NULL;
 IF EXISTS(SELECT 1 FROM inserted i INNER JOIN dbo.udt_educations x ON x.id=i.id LEFT JOIN dbo.udt_company_info_user ci ON ci.userid=x.userid WHERE ci.company_id IS NULL OR x.company_id<>ci.company_id) THROW 52903,'Perusahaan pendidikan tidak sesuai dengan pemilik.',1;
END;
GO
CREATE OR ALTER TRIGGER dbo.trg_experiences_company_guard ON dbo.udt_experiences AFTER INSERT,UPDATE AS
BEGIN
 SET NOCOUNT ON;
 UPDATE x SET company_id=ci.company_id FROM dbo.udt_experiences x INNER JOIN inserted i ON i.id=x.id INNER JOIN dbo.udt_company_info_user ci ON ci.userid=x.userid WHERE x.company_id IS NULL;
 IF EXISTS(SELECT 1 FROM inserted i INNER JOIN dbo.udt_experiences x ON x.id=i.id LEFT JOIN dbo.udt_company_info_user ci ON ci.userid=x.userid WHERE ci.company_id IS NULL OR x.company_id<>ci.company_id) THROW 52904,'Perusahaan pengalaman tidak sesuai dengan pemilik.',1;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_emergency_contact_get_list @user_id NVARCHAR(50),@include_inactive BIT=0 AS
BEGIN
 SET NOCOUNT ON; DECLARE @company_id INT; SELECT @company_id=ci.company_id FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid WHERE u.userid=@user_id AND u.active=1 AND ISNULL(u.deleted,0)=0;
 SELECT id,user_id,name,relationship,phone_number,email,address,is_primary,is_active,created_at,updated_at FROM dbo.udt_emergency_contacts WHERE user_id=@user_id AND company_id=@company_id AND (@include_inactive=1 OR is_active=1) ORDER BY is_primary DESC,created_at;
END;
GO
CREATE OR ALTER PROCEDURE dbo.udp_family_member_get_list @user_id VARCHAR(50),@include_inactive BIT=0 AS
BEGIN
 SET NOCOUNT ON; DECLARE @company_id INT; SELECT @company_id=ci.company_id FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid WHERE u.userid=@user_id AND u.active=1 AND ISNULL(u.deleted,0)=0;
 SELECT id,userid user_id,name,relationship,phone_number,birth_date,address,is_active,created_at,updated_at,created_by,updated_by FROM dbo.udt_family_members WHERE userid=@user_id AND company_id=@company_id AND (@include_inactive=1 OR is_active=1) ORDER BY created_at;
END;
GO
CREATE OR ALTER PROCEDURE dbo.udp_education_get_list @user_id VARCHAR(50),@include_inactive BIT=0 AS
BEGIN
 SET NOCOUNT ON; DECLARE @company_id INT; SELECT @company_id=ci.company_id FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid WHERE u.userid=@user_id AND u.active=1 AND ISNULL(u.deleted,0)=0;
 SELECT id,userid user_id,institution,degree,field,start_year,end_year,grade,is_active,created_at,updated_at,created_by,updated_by FROM dbo.udt_educations WHERE userid=@user_id AND company_id=@company_id AND (@include_inactive=1 OR is_active=1) ORDER BY start_year DESC,created_at DESC;
END;
GO
CREATE OR ALTER PROCEDURE dbo.udp_experience_get_list @user_id VARCHAR(50),@include_inactive BIT=0 AS
BEGIN
 SET NOCOUNT ON; DECLARE @company_id INT; SELECT @company_id=ci.company_id FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid WHERE u.userid=@user_id AND u.active=1 AND ISNULL(u.deleted,0)=0;
 SELECT id,userid user_id,company,position,start_period,end_period,description,is_active,created_at,updated_at,created_by,updated_by FROM dbo.udt_experiences WHERE userid=@user_id AND company_id=@company_id AND (@include_inactive=1 OR is_active=1) ORDER BY created_at DESC;
END;
GO

SELECT 'emergency' entity,company_id,COUNT(*) total FROM dbo.udt_emergency_contacts GROUP BY company_id
UNION ALL SELECT 'family',company_id,COUNT(*) FROM dbo.udt_family_members GROUP BY company_id
UNION ALL SELECT 'education',company_id,COUNT(*) FROM dbo.udt_educations GROUP BY company_id
UNION ALL SELECT 'experience',company_id,COUNT(*) FROM dbo.udt_experiences GROUP BY company_id;
GO

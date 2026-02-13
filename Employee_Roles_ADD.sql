DECLARE @json NVARCHAR(MAX) = 



--//---
/* Parse JSON into a table */
;WITH Emp AS (
    SELECT 
        j.EmployeeNO,
        r.[value] AS RoleName
    FROM OPENJSON(@json)
    WITH (
        EmployeeNO NVARCHAR(50),
        Roles NVARCHAR(MAX) AS JSON
    ) j
    CROSS APPLY OPENJSON(j.Roles) r
),
Map AS (
    SELECT 
        e.ID AS EmployeeID,
        r.ID AS RoleID,
        e.EmployeeNo,
        r.[Role] AS RoleName
    FROM Emp x
    JOIN Employee e ON e.EmployeeNo = x.EmployeeNo AND e.Active = 1
    JOIN [Role] r ON r.[Role]     = x.RoleName AND r.Active = 1
)
SELECT * INTO #ToProcess
FROM Map;
 
/* Loop through each pair and insert if missing */
DECLARE @EmployeeID INT, @RoleID INT;

DECLARE cur CURSOR FOR
SELECT EmployeeID, RoleID FROM #ToProcess;

OPEN cur;
FETCH NEXT FROM cur INTO @EmployeeID, @RoleID;

WHILE @@FETCH_STATUS = 0
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM Employee_Role
        WHERE EmployeeID = @EmployeeID
          AND RoleID = @RoleID
          AND Active = 1
    )
    BEGIN
        PRINT 'Inserting Role ' + CAST(@RoleID AS NVARCHAR(20)) 
              + ' for EmployeeID ' + CAST(@EmployeeID AS NVARCHAR(20));

        DECLARE 
            @ReferenceID INT = NULL,
            @LastUpdateOn DATETIME = NULL,
            @LastUpdatedBy NVARCHAR(50) = NULL,
            @CreatedOn DATETIME = GETDATE(),
            @CreatedBy NVARCHAR(50) = 'ADMIN',
            @Active BIT = 1,
            @LastDeleteOn DATETIME = NULL,
            @LastDeletedBy NVARCHAR(50) = NULL,
            @LastReactivateOn DATETIME = NULL,
            @LastReactivatedBy NVARCHAR(50) = NULL,
            @ArchiveID INT = NULL,
            @LastArchiveOn DATETIME = NULL,
            @LastArchivedBy NVARCHAR(50) = NULL,
            @LastRestoreOn DATETIME = NULL,
            @LastRestoredBy NVARCHAR(50) = NULL,
            @RowVersionStamp INT = NULL,
            @DSInstanceID NVARCHAR(100) = NULL,
            @DSInstanceName NVARCHAR(100) = NULL,
            @__SupportTriggers__ BIT = 0,
            @__SupportBLOB__ BIT = 0;

        EXEC [dbo].[flx_spEmployeeRoleInsert]
              @EmployeeID
            , @RoleID
            , @ReferenceID
            , @LastUpdateOn
            , @LastUpdatedBy
            , @CreatedOn
            , @CreatedBy
            , @Active
            , @LastDeleteOn
            , @LastDeletedBy
            , @LastReactivateOn
            , @LastReactivatedBy
            , @ArchiveID
            , @LastArchiveOn
            , @LastArchivedBy
            , @LastRestoreOn
            , @LastRestoredBy
            , @RowVersionStamp OUTPUT
            , @DSInstanceID
            , @DSInstanceName
            , @__SupportTriggers__
            , @__SupportBLOB__;
    END
    ELSE
    BEGIN
        PRINT 'Skipping EmployeeID ' + CAST(@EmployeeID AS NVARCHAR(20))
            + ' — Role already exists';
    END

    FETCH NEXT FROM cur INTO @EmployeeID, @RoleID;
END

CLOSE cur;
DEALLOCATE cur;

Drop table #ToProcess

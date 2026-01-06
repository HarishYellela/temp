
/* ===========================
   Inputs
   =========================== */
DECLARE @UILanguage  INT           = 1033;   -- NULL = keep existing per employee
DECLARE @TimeZoneID  INT           = 0;   -- NULL = keep existing per employee

-- XML template with placeholders to fill
DECLARE @XmlTemplate NVARCHAR(MAX) = N'<?xml version="1.0" encoding="utf-8"?>'
    + N'<LocalizationPersonalizationInfo xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
    + N'<UILanguage>{UILanguage}</UILanguage>'
    + N'<DatabaseLanguage>1033</DatabaseLanguage>'
    + N'<TimeZoneID>{TimeZoneID}</TimeZoneID>'
    + N'</LocalizationPersonalizationInfo>';

BEGIN TRY
    BEGIN TRAN;

    /* ===========================
       Detect storage format (encoded vs raw)
       =========================== */
    DECLARE @IsEncoded BIT = 0;
    IF EXISTS (
        SELECT 1
        FROM dbo.EMPLOYEE_PERSONALIZATION EP
        WHERE EP.Name = 'Localization'
          AND EP.Value LIKE N'%&lt;%' and Ep.EmployeeID =600001483
    )
        SET @IsEncoded = 1;

    /* ===========================
       Temp table (backup + working values)
       =========================== */
    IF OBJECT_ID('tempdb..#EP_Work') IS NOT NULL DROP TABLE #EP_Work;
    CREATE TABLE #EP_Work (
        EmployeeID   INT           NOT NULL,
        Name         NVARCHAR(100) NOT NULL,
        OldValue     NVARCHAR(MAX) NULL,
        IsEncoded    BIT           NOT NULL,
        UILanguage   INT           NULL,
        TimeZoneID   INT           NULL,
        UpdatedXml   NVARCHAR(MAX) NULL
    );

    /* ===========================
       Step A/B: Load rows & extract UILanguage/TimeZoneID via string parsing
       =========================== */
    INSERT INTO #EP_Work (EmployeeID, Name, OldValue, IsEncoded, UILanguage, TimeZoneID)
    SELECT
        EP.EmployeeID,
        EP.Name,
        EP.Value AS OldValue,
        CASE WHEN EP.Value LIKE N'%&lt;%' THEN 1 ELSE 0 END AS IsEncoded,

        -- UILanguage
        TRY_CONVERT(INT,
            CASE 
              WHEN EP.Value LIKE N'%&lt;%' THEN
                   SUBSTRING(
                       EP.Value,
                       CHARINDEX(N'&lt;UILanguage&gt;', EP.Value) + LEN(N'&lt;UILanguage&gt;'),
                       CHARINDEX(N'&lt;/UILanguage&gt;', EP.Value) - 
                       (CHARINDEX(N'&lt;UILanguage&gt;', EP.Value) + LEN(N'&lt;UILanguage&gt;'))
                   )
              ELSE
                   SUBSTRING(
                       EP.Value,
                       CHARINDEX(N'<UILanguage>', EP.Value) + LEN(N'<UILanguage>'),
                       CHARINDEX(N'</UILanguage>', EP.Value) - 
                       (CHARINDEX(N'<UILanguage>', EP.Value) + LEN(N'<UILanguage>'))
                   )
            END
        ) AS UILanguage,

        -- TimeZoneID
        TRY_CONVERT(INT,
            CASE 
              WHEN EP.Value LIKE N'%&lt;%' THEN
                   SUBSTRING(
                       EP.Value,
                       CHARINDEX(N'&lt;TimeZoneID&gt;', EP.Value) + LEN(N'&lt;TimeZoneID&gt;'),
                       CHARINDEX(N'&lt;/TimeZoneID&gt;', EP.Value) - 
                       (CHARINDEX(N'&lt;TimeZoneID&gt;', EP.Value) + LEN(N'&lt;TimeZoneID&gt;'))
                   )
              ELSE
                   SUBSTRING(
                       EP.Value,
                       CHARINDEX(N'<TimeZoneID>', EP.Value) + LEN(N'<TimeZoneID>'),
                       CHARINDEX(N'</TimeZoneID>', EP.Value) - 
                       (CHARINDEX(N'<TimeZoneID>', EP.Value) + LEN(N'<TimeZoneID>'))
                   )
            END
        ) AS TimeZoneID
    FROM dbo.EMPLOYEE_PERSONALIZATION EP
    WHERE EP.Name = 'Localization' and Ep.EmployeeID =600001483;

    /* ===========================
       Step C/D: Build UpdatedXml using inputs or per-employee fallback
       =========================== */
    UPDATE W
    SET W.UpdatedXml =
        CASE WHEN @IsEncoded = 1 OR W.IsEncoded = 1 THEN
            -- Build raw XML then encode to &lt;&gt;&amp;&quot;&apos;
            REPLACE(
              REPLACE(
                REPLACE(
                  REPLACE(
                    REPLACE(
                        REPLACE(
                            REPLACE(@XmlTemplate,
                                    N'{UILanguage}', CAST(COALESCE(@UILanguage, W.UILanguage) AS NVARCHAR(20))),
                                    N'{TimeZoneID}', CAST(COALESCE(@TimeZoneID, W.TimeZoneID) AS NVARCHAR(20)))
                        , N'&', N'&amp;')   -- encode & first
                    , N'<', N'&lt;')
                  , N'>', N'&gt;')
                , N'"', N'&quot;')
              , N'''', N'&apos;')
        ELSE
            -- Store raw XML directly
            REPLACE(
                REPLACE(@XmlTemplate,
                        N'{UILanguage}', CAST(COALESCE(@UILanguage, W.UILanguage) AS NVARCHAR(20))),
                        N'{TimeZoneID}', CAST(COALESCE(@TimeZoneID, W.TimeZoneID) AS NVARCHAR(20)))
        END
    FROM #EP_Work W;

    /* ===========================
       Step E: Single final UPDATE
       =========================== */
    UPDATE EP
    SET EP.Value = W.UpdatedXml
    FROM dbo.EMPLOYEE_PERSONALIZATION EP
    JOIN #EP_Work W
      ON W.EmployeeID = EP.EmployeeID
     AND W.Name = EP.Name
    WHERE EP.Name = 'Localization' and Ep.EmployeeID =600001483

    PRINT CONCAT('Rows updated: ', @@ROWCOUNT);

    COMMIT TRAN;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRAN;
    THROW;
END CATCH;

-- Optional: verify a few rows
SELECT TOP (10) EmployeeID, Name, UILanguage, TimeZoneID, UpdatedXml
FROM #EP_Work
ORDER BY EmployeeID;

DECLARE @TableName NVARCHAR(128);
DECLARE @IndexName NVARCHAR(128);
DECLARE @SchemaName NVARCHAR(128);
DECLARE @SQL NVARCHAR(MAX);

-- Cursor to loop through fragmented indexes
DECLARE IndexCursor CURSOR FOR
SELECT 
    s.name AS SchemaName,
    t.name AS TableName,
    i.name AS IndexName--,  ips.avg_fragmentation_in_percent
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') AS ips
JOIN sys.indexes i ON ips.object_id = i.object_id AND ips.index_id = i.index_id
JOIN sys.tables t ON i.object_id = t.object_id
JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE ips.avg_fragmentation_in_percent > 30
AND i.name IS NOT NULL
AND i.type_desc IN ('CLUSTERED', 'NONCLUSTERED') and t.name in ('Work_Center')--,'WIP_OPERATION','WIP_COMPONENT','COMPONENT')-- Only rebuild real indexes
ORDER BY ips.avg_fragmentation_in_percent DESC;

OPEN IndexCursor;
FETCH NEXT FROM IndexCursor INTO @SchemaName, @TableName, @IndexName;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @SQL = 'ALTER INDEX [' + @IndexName + '] ON [' + @SchemaName + '].[' + @TableName + '] REBUILD;';
    PRINT @SQL;  -- Optional: comment this out if you don't want to see the commands
    EXEC sp_executesql @SQL;

    FETCH NEXT FROM IndexCursor INTO @SchemaName, @TableName, @IndexName;
END

CLOSE IndexCursor;
DEALLOCATE IndexCursor;

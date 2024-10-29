-- SQL SERVER
-- Remove more then half rows in large table with some condition by copy data and switch tables

BEGIN TRY
	SELECT TOP (0) * INTO BigTable_temp
	FROM dbo.BigTable;

	SET IDENTITY_INSERT dbo.BigTable_temp ON;

	--------------------------------------------------------------------------
	DECLARE @batchSize INT = 10000;
	DECLARE @minId INT, @maxId INT;

	SELECT @MinId = MIN(Id), @maxId = MAX(Id) FROM [dbo].[BigTable];


	WHILE (@MinId < @maxId)
	BEGIN
		INSERT INTO dbo.BigTable_temp([Id], [ColumnOne], [JsonData], [XmlData], [Created], [CreatedBy], [Modified], [ModifiedByColumTwo])
		SELECT * FROM dbo.BigTable(NOLOCK)
		WHERE Id BETWEEN @minId AND @minId + @batchSize - 1
			AND RIGHT(ColumnOne,14) <> 'deleteMePlease';  
				-- in output table we not need data where ColumnOne ends with 'deleteMePlease', the where condition can be anything, preferably including some index

		SET @minId += @batchSize
		-- Adding a delay of 50 milliseconds
		WAITFOR DELAY '00:00:00.050';
	END
	SELECT @minId = @maxId + 1,@maxId = MAX(Id) FROM [dbo].[BigTable];

	WHILE (@MinId < @maxId)
	BEGIN
		INSERT INTO dbo.BigTable_temp([Id], [ColumnOne], [JsonData], [XmlData], [Created], [CreatedBy], [Modified], [ModifiedByColumTwo])
		SELECT * FROM dbo.BigTable
		WHERE Id BETWEEN @minId AND @minId+@batchSize-1
			AND RIGHT(ColumnOne,14) <> 'deleteMePlease';

		SET @minId += @batchSize
		-- Adding a delay of 50 milliseconds
		WAITFOR DELAY '00:00:00.050';
	END

	BEGIN TRANSACTION;

	INSERT INTO dbo.BigTable_temp WITH(TABLOCKX)([Id], [ColumnOne], [JsonData], [XmlData], [Created], [CreatedBy], [Modified], [ModifiedByColumTwo])
	SELECT * FROM dbo.BigTable(TABLOCKX)
	WHERE Id > @maxId
		AND RIGHT(ColumnOne,13) <> 'deleteMePlease';

	TRUNCATE TABLE dbo.BigTable;
	
	-- remember to create the same indexes on temp table like on orginal table, to satisfy switch statement

	ALTER TABLE dbo.BigTable_temp ADD CONSTRAINT PK_BigTable PRIMARY KEY (Id)

	ALTER TABLE dbo.BigTable_temp SWITCH TO dbo.BigTable;

	DECLARE @id INT = IDENT_CURRENT('dbo.BigTable_temp');
	DBCC CHECKIDENT ('dbo.BigTable', RESEED, @id);

	COMMIT;
    
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
		ROLLBACK;
	THROW;
END CATCH

-- Test it before run on production !!!
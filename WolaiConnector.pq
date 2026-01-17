// Wolai Connector for Power BI
[Version = "1.1.1"]
section WolaiConnector;

// 数据源种类定义
WolaiConnector = [
    TestConnection = (dataSourcePath) => {"WolaiConnector.Contents"},
    Authentication = [
        Key = [
            KeyLabel = "App ID | App Secret",
            Label = "Wolai API 认证"
        ]
    ],
    Label = "Wolai Connector",
    SupportsDirectQuery = false
];

// 发布设置
WolaiConnector.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { "Wolai Connector", "Wolai Connector Help" },
    LearnMoreUrl = "https://www.wolai.com/wolai/7FB9PLeqZ1ni9FfD11WuUi",
    SourceImage = WolaiConnector.Icons,
    SourceTypeImage = WolaiConnector.Icons
];

WolaiConnector.Icons = [
    Icon16 = { Extension.Contents("WolaiConnector16.png"), Extension.Contents("WolaiConnector20.png"), Extension.Contents("WolaiConnector24.png"), Extension.Contents("WolaiConnector32.png") },
    Icon32 = { Extension.Contents("WolaiConnector32.png"), Extension.Contents("WolaiConnector40.png"), Extension.Contents("WolaiConnector48.png"), Extension.Contents("WolaiConnector64.png") }
];

// 定义数据源：核心实现，要求传入 database_id
[DataSource.Kind="WolaiConnector", Publish="WolaiConnector.Publish"]
shared WolaiConnector.Contents = (database_id as text, optional debug_mode as logical, optional databases as text) =>
    let
        credentials = Extension.CurrentCredential(),

        rawKey = 
            if Record.HasFields(credentials, "Key") and credentials[Key] <> null then 
                Text.Trim(Text.From(credentials[Key])) 
            else 
                null,

        keyDelimiter = 
            if rawKey <> null and Text.Contains(rawKey, "|") then 
                "|" 
            else if rawKey <> null and Text.Contains(rawKey, ",") then 
                "," 
            else 
                null,

        keyParts = 
            if keyDelimiter <> null then 
                List.Transform(Text.Split(rawKey, keyDelimiter), each Text.Trim(_)) 
            else 
                {},

        app_id = 
            if List.Count(keyParts) >= 1 and keyParts{0} <> "" then 
                keyParts{0}
            else 
                error "请在凭据中填写 App ID 和 App Secret，格式为: AppID|AppSecret。",

        app_secret = 
            if List.Count(keyParts) >= 2 and keyParts{1} <> "" then 
                keyParts{1}
            else 
                error "请在凭据中填写 App ID 和 App Secret，格式为: AppID|AppSecret。",

        target_database_id = Text.Trim(database_id),

        is_debug = if (debug_mode <> null) then debug_mode else false,
        
        token = GetWolaiToken(app_id, app_secret),

        result = 
            if target_database_id <> null and target_database_id <> "" then 
                GetDatabaseContent(token, target_database_id, is_debug)
            else
                error "请在参数中填写数据库 ID（database_id）。"
    in
        result;

// 对外暴露的函数，用于在 Power BI 中弹出参数对话框
shared WolaiConnector.Database = (database_id as text, optional debug_mode as logical) =>
    WolaiConnector.Contents(database_id, debug_mode, null);

// 获取Wolai令牌（带错误信息）
GetWolaiToken = (app_id as text, app_secret as text) =>
    let
        requestJson = "{""appId"":""" & app_id & """,""appSecret"":""" & app_secret & """}",
        
        tokenResult = try
            let
                tokenResponse = Web.Contents(
                    "https://openapi.wolai.com/v1/token",
                    [
                        Headers = [
                            #"Content-Type" = "application/json"
                        ],
                        Content = Text.ToBinary(requestJson)
                    ]
                ),
                responseJson = Json.Document(tokenResponse),
                token = responseJson[data][app_token]
            in
                token,
        
        token = 
            if tokenResult[HasError] then 
                error "获取 Wolai 令牌失败: " & tokenResult[Error][Message] &
                      "。请检查 App ID 和 App Secret 是否正确。"
            else 
                tokenResult[Value]
    in
        token;

// 辅助函数：带重试机制的 Web 请求
// 用于处理 429 (Too Many Requests) 和 5xx (Server Errors)
Web.ContentsWithRetry = (url as text, options as record) =>
    let
        // 最大的重试次数
        MaxRetries = 5,
        
        // 执行请求的内部函数
        ExecuteRequest = (retryCount as number) =>
            let
                // 增加 ManualStatusHandling 以便手动处理状态码
                newOptions = options & [ManualStatusHandling = {429, 500, 502, 503, 504}],
                
                // 如果是重试，进行延迟 (指数退避: 1s, 2s, 4s, 8s, 16s)
                _ = if retryCount > 0 then Function.InvokeAfter(() => null, #duration(0,0,0, Number.Power(2, retryCount - 1))) else null,
                
                response = Web.Contents(url, newOptions),
                meta = Value.Metadata(response),
                status = meta[Response.Status]
            in
                if List.Contains({429, 500, 502, 503, 504}, status) then
                    if retryCount < MaxRetries then
                        // 递归重试
                        ExecuteRequest(retryCount + 1)
                    else
                        // 超过重试次数，返回错误
                        error Error.Record("DataSource.Error", "Request failed after multiple retries. Status: " & Text.From(status), Text.FromBinary(response))
                else
                    // 成功或其他错误，直接返回响应（Web.Contents 会自动处理其他 4xx 错误）
                    response
    in
        ExecuteRequest(0);

// 获取所有数据库列表并生成导航表（基于用户提供的列表参数）
GetDatabases = (token as text, optional databaseListText as nullable text) as table =>
    let
        dbListText = if databaseListText = null then "" else databaseListText,
        dbEntries =
            if dbListText <> "" then
                let
                    pairs = List.Select(Text.Split(dbListText, ","), each Text.Trim(_) <> ""),
                    parsed = List.Transform(pairs, (p) =>
                        let
                            parts = Text.Split(p, ":"),
                            id = Text.Trim(parts{0}),
                            name = 
                                if List.Count(parts) > 1 and Text.Trim(parts{1}) <> "" then 
                                    Text.Trim(parts{1}) 
                                else 
                                    id
                        in
                            [Id = id, Name = name]
                    )
                in
                    parsed
            else
                {},
        
        rawTable =
            if List.IsEmpty(dbEntries) then
                #table({"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"}, {})
            else
                let
                    baseTable = Table.FromRecords(dbEntries),
                    nameExpanded = Table.AddColumn(
                        baseTable,
                        "Name2",
                        each if [Name] = [Id] then [Id] else [Name] & " (" & [Id] & ")"
                    ),
                    withDisplayName = Table.RemoveColumns(nameExpanded, {"Name"}),
                    renamedDisplay = Table.RenameColumns(withDisplayName, {{"Name2", "Name"}}),
                    withKey = Table.AddColumn(renamedDisplay, "Key", each [Id]),
                    withData = Table.AddColumn(withKey, "Data", each GetDatabaseContent(token, [Id], false)),
                    withItemKind = Table.AddColumn(withData, "ItemKind", each "Table"),
                    withItemName = Table.AddColumn(withItemKind, "ItemName", each "Table"),
                    withIsLeaf = Table.AddColumn(withItemName, "IsLeaf", each true)
                in
                    withIsLeaf,
        
        navTable = Table.ToNavigationTable(rawTable, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navTable;


// 核心解析函数：处理单个属性值
// 借鉴 Notion 连接器的处理模式
ParsePropertyValue = (val, propType) =>
    let
        actual =
            if val is record and Record.HasFields(val, "value") then val[value]
            else val,
        effectiveType =
            if val is record and Record.HasFields(val, "type") then Text.From(val[type])
            else propType,
        result = 
            if actual = null then null
            else if effectiveType = "primary" or effectiveType = "title" or effectiveType = "text" or effectiveType = "rich_text" then
                Text.From(actual)
            else if effectiveType = "url" or effectiveType = "email" or effectiveType = "phone_number" then
                Text.From(actual)
            else if effectiveType = "created_time" or effectiveType = "edited_time" then
                Text.From(actual)
            else if effectiveType = "number" then
                try Number.From(actual) otherwise null
            else if effectiveType = "checkbox" then
                try Logical.From(actual) otherwise false
            else if effectiveType = "multi_select" or effectiveType = "people" or effectiveType = "files" then
                if actual is list then
                    Text.Combine(List.Transform(actual, each Text.From(_)), ", ")
                else Text.From(actual)
            else
                if actual is record or actual is list then 
                    Text.FromBinary(Json.FromValue(actual))
                else Text.From(actual)
    in
        result;

// 获取特定数据库的内容（支持分页）
GetDatabaseContent = (token, database_id, optional debug_mode as logical) =>
    let
        // 分页获取函数
        FetchPage = (optional cursor as text) =>
            let
                query = [
                    // 恢复 page_size 为 100，利用自动重试机制处理超时
                    page_size = "100" 
                ],
                finalQuery = if cursor <> null and cursor <> "" then Record.AddField(query, "start_cursor", cursor) else query,
                
                // 使用带重试机制的请求函数
                response = Web.ContentsWithRetry(
                    "https://openapi.wolai.com/v1/databases/" & database_id,
                    [
                        Headers = [
                            Authorization = token,
                            #"Content-Type" = "application/json"
                        ],
                        Query = finalQuery,
                        // 增加超时时间设置，防止大表响应慢
                        Timeout = #duration(0, 0, 10, 0)
                    ]
                ),
                json = Json.Document(response),
                data = json[data]
            in
                data,

        // 使用 List.Generate 进行分页抓取
        // 假设分页参数为 cursor 和 next_cursor，这是 Notion 类 API 的常见模式
        // 如果 API 不支持分页参数，第一页会返回所有数据，且 next_cursor 为空，循环自然结束
        Pages = List.Generate(
            () => let firstData = FetchPage(null) in [
                Data = firstData,
                NextCursor = try firstData[next_cursor] otherwise null,
                HasMore = try firstData[has_more] otherwise false,
                Index = 0
            ],
            each [Data] <> null,
            each let 
                    nextData = if [NextCursor] <> null and [NextCursor] <> "" then FetchPage([NextCursor]) else null 
                 in [
                    Data = nextData,
                    NextCursor = if nextData <> null then (try nextData[next_cursor] otherwise null) else null,
                    HasMore = if nextData <> null then (try nextData[has_more] otherwise false) else false,
                    Index = [Index] + 1
                 ],
            each [Data]
        ),
        
        // 过滤掉空的 Data（比如最后一次迭代产生的 null）
        ValidPages = List.Select(Pages, each _ <> null),
        
        // 提取所有页的 rows
        AllRows = List.Combine(List.Transform(ValidPages, each if Record.HasFields(_, "rows") then _[rows] else {})),
        
        // 提取元数据（使用第一页的数据）
        FirstPageData = if List.IsEmpty(ValidPages) then [] else ValidPages{0},
        properties = if Record.HasFields(FirstPageData, "properties") then FirstPageData[properties] else [],
        propNames = Record.FieldNames(properties),
        columnOrder = if Record.HasFields(FirstPageData, "column_order") then FirstPageData[column_order] else propNames,

        propMap =
            if List.Count(propNames) > 0 then
                List.Transform(propNames, (id) => 
                    let 
                        p = Record.Field(properties, id)
                    in 
                        [Id = id, Name = p[name], Type = p[type]]
                )
            else
                let
                    firstRow =
                        if List.IsEmpty(AllRows) then null else AllRows{0},
                    firstData =
                        if firstRow = null then []
                        else if Record.HasFields(firstRow, "data") then firstRow[data]
                        else firstRow,
                    dataKeys = if firstData = null then {} else Record.FieldNames(firstData),
                    colNames = if columnOrder = null or List.IsEmpty(columnOrder) then dataKeys else columnOrder,
                    count = List.Min({List.Count(dataKeys), List.Count(colNames)}),
                    indices = if count = null or count <= 0 then {} else {0..count - 1},
                    map = List.Transform(indices, (i) =>
                        let
                            key = dataKeys{i},
                            name = colNames{i},
                            fieldVal = Record.Field(firstData, key),
                            fieldType = 
                                if fieldVal is record and Record.HasFields(fieldVal, "type")
                                then Text.From(fieldVal[type])
                                else "unknown"
                        in
                            [Id = key, Name = name, Type = fieldType]
                    )
                in
                    map,
        
        processedRows = List.Transform(AllRows, (row) =>
            let
                // 基础字段：仅保留 page_id，时间字段由属性列提供
                base = [
                    page_id =
                        if Record.HasFields(row, "page_id") then row[page_id]
                        else if Record.HasFields(row, "id") then row[id]
                        else if Record.HasFields(row, "pageId") then row[pageId]
                        else null
                ],
                // 数据字段解析
                rowData =
                    if Record.HasFields(row, "data") then row[data]
                    else if Record.HasFields(row, "properties") then row[properties]
                    else row,
                customFields = List.Transform(propMap, (p) =>
                    let
                        rawVal =
                            if Record.HasFields(rowData, p[Id]) then
                                Record.Field(rowData, p[Id])
                            else if Record.HasFields(rowData, p[Name]) then
                                Record.Field(rowData, p[Name])
                            else if p[Type] = "created_time" and Record.HasFields(row, "created_time") then
                                row[created_time]
                            else if p[Type] = "created_time" and Record.HasFields(row, "createdTime") then
                                row[createdTime]
                            else if p[Type] = "created_time" and Record.HasFields(row, "created_at") then
                                row[created_at]
                            else if p[Type] = "created_time" and Record.HasFields(row, "createdAt") then
                                row[createdAt]
                            else if p[Type] = "last_edited_time" and Record.HasFields(row, "last_edited_time") then
                                row[last_edited_time]
                            else if p[Type] = "last_edited_time" and Record.HasFields(row, "lastEditedTime") then
                                row[lastEditedTime]
                            else if p[Type] = "last_edited_time" and Record.HasFields(row, "updated_time") then
                                row[updated_time]
                            else if p[Type] = "last_edited_time" and Record.HasFields(row, "updatedAt") then
                                row[updatedAt]
                            else
                                null,
                        parsedVal = ParsePropertyValue(rawVal, p[Type])
                    in
                        [Name = p[Name], Value = parsedVal]
                ),
                // 将自定义字段转为记录
                customRecord = Record.FromList(
                    List.Transform(customFields, each _[Value]),
                    List.Transform(customFields, each _[Name])
                ),
                // 合并
                final = Record.Combine({base, customRecord})
            in
                final
        ),

        // 4. 转换为表格
        table = if List.IsEmpty(processedRows) then 
                    #table({"Message"}, {{"No data found"}}) 
                else 
                    Table.FromRecords(processedRows)
    in
        if debug_mode then 
            Table.AddColumn(table, "Debug", each Text.FromBinary(Json.FromValue(FirstPageData)))
        else 
            table;

// 导航表辅助函数
Table.ToNavigationTable = (
    table as table,
    keyColumns as list,
    nameColumn as text,
    dataColumn as text,
    itemKindColumn as text,
    itemNameColumn as text,
    isLeafColumn as text
) as table =>
    let
        tableType = Value.Type(table),
        newTableType = Type.AddTableKey(tableType, keyColumns, true) meta 
        [
            NavigationTable.NameColumn = nameColumn, 
            NavigationTable.DataColumn = dataColumn,
            NavigationTable.ItemKindColumn = itemKindColumn, 
            Preview.DelayColumn = itemNameColumn, 
            NavigationTable.IsLeafColumn = isLeafColumn
        ],
        navigationTable = Value.ReplaceType(table, newTableType)
    in
        navigationTable;

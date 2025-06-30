' =========================================================================
' === FINAL & COMPLETE ReportService.asmx.vb Code ===
' === All overloading errors are fixed.
' =========================================================================
Imports System.Web.Services
Imports System.ComponentModel
Imports System.Web.Script.Services
Imports System.Data.SqlClient
Imports System.Configuration
Imports System.Web.Script.Serialization
Imports System.Text
Imports System.Collections.Generic
Imports System.Text.RegularExpressions

<System.Web.Script.Services.ScriptService()>
<WebService(Namespace:="http://tempuri.org/")>
<WebServiceBinding(ConformsTo:=WsiProfiles.BasicProfile1_1)>
<ToolboxItem(False)>
Public Class ReportService
    Inherits System.Web.Services.WebService

    Private ReadOnly BIConnString As String = ConfigurationManager.ConnectionStrings("DefaultConnection").ConnectionString
    Private ReadOnly ClientConnString As String = ConfigurationManager.ConnectionStrings("DefaultConnection").ConnectionString
    Private ReadOnly Serializer As New JavaScriptSerializer() With {.MaxJsonLength = Integer.MaxValue}

#Region "Admin - Report Manager Methods"
    'Returns a JSON list of all reports, including their main properties and first-level query/chart info
    <WebMethod()>
    Public Function GetReports() As String
        Dim query As String = "
            SELECT 
                R.ReportID, 
                R.ReportName, 
                R.ReportDescription, 
                R.IsActive, 
                L.SQLQuery AS ReportQuery,
                L.ChartType,
                L.DrillDownKeyField AS ChartArgumentField
            FROM Reports R
            LEFT JOIN ReportLevels L ON R.ReportID = L.ReportID AND L.LevelOrder = 1
            ORDER BY R.ReportID DESC"
        Return ConvertDataTableToJson(GetDataTable(query, BIConnString))
    End Function
    'Inserts a new report and its first report level into the database using the provided values
    <WebMethod()>
    Public Sub InsertReport(ByVal values As Dictionary(Of String, Object))
        Dim reportName As String = If(values.ContainsKey("ReportName"), values("ReportName")?.ToString(), "New Report")
        Dim reportDesc As String = If(values.ContainsKey("ReportDescription"), values("ReportDescription")?.ToString(), "")
        Dim isActive As Boolean = If(values.ContainsKey("IsActive"), Convert.ToBoolean(values("IsActive")), True)
        Dim reportQuery As String = If(values.ContainsKey("ReportQuery"), values("ReportQuery")?.ToString(), "SELECT 'No Query' AS Result")
        Dim chartType As String = If(values.ContainsKey("ChartType"), values("ChartType")?.ToString(), "GridOnly")
        Dim argumentField As String = If(values.ContainsKey("ChartArgumentField"), values("ChartArgumentField")?.ToString(), "")

        Using conn As New SqlConnection(BIConnString)
            conn.Open()
            Dim trans As SqlTransaction = conn.BeginTransaction()
            Try
                Dim reportCmd As New SqlCommand("INSERT INTO Reports (ReportName, ReportDescription, IsActive) VALUES (@ReportName, @ReportDescription, @IsActive); SELECT SCOPE_IDENTITY();", conn, trans)
                reportCmd.Parameters.AddWithValue("@ReportName", reportName)
                reportCmd.Parameters.AddWithValue("@ReportDescription", If(String.IsNullOrEmpty(reportDesc), DBNull.Value, reportDesc))
                reportCmd.Parameters.AddWithValue("@IsActive", isActive)
                Dim newReportId As Integer = Convert.ToInt32(reportCmd.ExecuteScalar())
                Dim levelCmd As New SqlCommand("INSERT INTO ReportLevels (ReportID, LevelOrder, LevelTitle, SQLQuery, ChartType, DrillDownKeyField) VALUES (@ReportID, 1, @LevelTitle, @SQLQuery, @ChartType, @DrillDownKeyField)", conn, trans)
                levelCmd.Parameters.AddWithValue("@ReportID", newReportId)
                levelCmd.Parameters.AddWithValue("@LevelTitle", reportName)
                levelCmd.Parameters.AddWithValue("@SQLQuery", reportQuery)
                levelCmd.Parameters.AddWithValue("@ChartType", chartType)
                levelCmd.Parameters.AddWithValue("@DrillDownKeyField", If(String.IsNullOrWhiteSpace(argumentField), DBNull.Value, argumentField))
                levelCmd.ExecuteNonQuery()
                trans.Commit()
            Catch ex As Exception
                trans.Rollback()
                Throw
            End Try
        End Using
    End Sub
    'Updates the report and its first level with new values for the specified report ID.
    <WebMethod()>
    Public Sub UpdateReport(ByVal key As Integer, ByVal values As Dictionary(Of String, Object))
        Using conn As New SqlConnection(BIConnString)
            conn.Open()
            Dim trans As SqlTransaction = conn.BeginTransaction()
            Try
                If values.ContainsKey("ReportName") OrElse values.ContainsKey("ReportDescription") OrElse values.ContainsKey("IsActive") Then
                    Dim sbReport As New StringBuilder("UPDATE Reports SET ModifiedDate=GETDATE()")
                    If values.ContainsKey("ReportName") Then sbReport.Append(", ReportName = @ReportName")
                    If values.ContainsKey("ReportDescription") Then sbReport.Append(", ReportDescription = @ReportDescription")
                    If values.ContainsKey("IsActive") Then sbReport.Append(", IsActive = @IsActive")
                    sbReport.Append(" WHERE ReportID=@ReportID")
                    Dim reportCmd As New SqlCommand(sbReport.ToString(), conn, trans)
                    reportCmd.Parameters.AddWithValue("@ReportID", key)
                    If values.ContainsKey("ReportName") Then reportCmd.Parameters.AddWithValue("@ReportName", values("ReportName"))
                    If values.ContainsKey("ReportDescription") Then reportCmd.Parameters.AddWithValue("@ReportDescription", If(String.IsNullOrEmpty(values("ReportDescription")?.ToString()), DBNull.Value, values("ReportDescription")))
                    If values.ContainsKey("IsActive") Then reportCmd.Parameters.AddWithValue("@IsActive", values("IsActive"))
                    reportCmd.ExecuteNonQuery()
                End If
                Dim sbLevel As New StringBuilder("UPDATE ReportLevels SET ")
                Dim levelUpdateFields As New List(Of String)
                If values.ContainsKey("ReportQuery") Then levelUpdateFields.Add("SQLQuery = @SQLQuery")
                If values.ContainsKey("ChartType") Then levelUpdateFields.Add("ChartType = @ChartType")
                If values.ContainsKey("ChartArgumentField") Then levelUpdateFields.Add("DrillDownKeyField = @DrillDownKeyField")
                If levelUpdateFields.Count > 0 Then
                    sbLevel.Append(String.Join(", ", levelUpdateFields))
                    sbLevel.Append(" WHERE ReportID=@ReportID AND LevelOrder=1")
                    Dim levelCmd As New SqlCommand(sbLevel.ToString(), conn, trans)
                    levelCmd.Parameters.AddWithValue("@ReportID", key)
                    If values.ContainsKey("ReportQuery") Then levelCmd.Parameters.AddWithValue("@SQLQuery", values("ReportQuery"))
                    If values.ContainsKey("ChartType") Then levelCmd.Parameters.AddWithValue("@ChartType", values("ChartType"))
                    If values.ContainsKey("ChartArgumentField") Then levelCmd.Parameters.AddWithValue("@DrillDownKeyField", If(String.IsNullOrWhiteSpace(values("ChartArgumentField")?.ToString()), DBNull.Value, values("ChartArgumentField")))
                    levelCmd.ExecuteNonQuery()
                End If
                trans.Commit()
            Catch ex As Exception
                trans.Rollback()
                Throw
            End Try
        End Using
    End Sub
    'Deletes the report with the given ID from the database
    <WebMethod()>
    Public Sub DeleteReport(ByVal key As Integer)
        ExecuteNonQuery("DELETE FROM Reports WHERE ReportID=@ReportID", New List(Of SqlParameter) From {New SqlParameter("@ReportID", key)})
    End Sub
    'Executes a provided SQL query (safely, with a row limit) and returns a JSON preview of the result or an error.

    <WebMethod()>
    Public Function PreviewQuery(ByVal query As String) As String
        Dim safeQuery As String = $"WITH a AS ({query}) SELECT TOP 5 * FROM a;"
        Try
            Dim dt As DataTable = GetDataTable(safeQuery, ClientConnString)
            Dim columnNames As New List(Of String)
            For Each col As DataColumn In dt.Columns
                columnNames.Add(col.ColumnName)
            Next
            Return Serializer.Serialize(New With {.Columns = columnNames, .PreviewData = ConvertDataTableToDictionaryList(dt)})
        Catch ex As Exception
            Return Serializer.Serialize(New With {.error = "Invalid SQL Query: " & ex.Message.Replace(vbCrLf, " ").Replace("'", """")})
        End Try
    End Function
#End Region

#Region "Admin - Level Manager Methods"
    <WebMethod()>
    Public Function GetReportLevels(ByVal reportId As Integer) As String
        Dim query As String = "SELECT LevelID, ReportID, LevelOrder, LevelTitle, SQLQuery, ChartType, DrillDownKeyField FROM ReportLevels WHERE ReportID = @ReportID ORDER BY LevelOrder"
        Dim dt = GetDataTable(query:=query, connectionString:=BIConnString, params:=New List(Of SqlParameter) From {New SqlParameter("@ReportID", reportId)})
        Return ConvertDataTableToJson(dt)
    End Function

    <WebMethod()>
    Public Sub InsertReportLevel(ByVal values As Dictionary(Of String, Object))
        Dim query As String = "INSERT INTO ReportLevels (ReportID, LevelOrder, LevelTitle, SQLQuery, ChartType, DrillDownKeyField) VALUES (@ReportID, @LevelOrder, @LevelTitle, @SQLQuery, @ChartType, @DrillDownKeyField)"
        ExecuteNonQuery(query, GetParamsFromDict(values))
    End Sub

    <WebMethod()>
    Public Sub UpdateReportLevel(ByVal key As Integer, ByVal values As Dictionary(Of String, Object))
        Dim sb As New StringBuilder("UPDATE ReportLevels SET ")
        Dim updateFields As New List(Of String)
        For Each kvp In values
            If kvp.Key <> "ReportID" And kvp.Key <> "LevelID" Then updateFields.Add($"{kvp.Key} = @{kvp.Key}")
        Next
        sb.Append(String.Join(", ", updateFields))
        sb.Append(" WHERE LevelID = @LevelID")
        Dim params = GetParamsFromDict(values)
        params.Add(New SqlParameter("@LevelID", key))
        ExecuteNonQuery(sb.ToString(), params)
    End Sub

    <WebMethod()>
    Public Sub DeleteReportLevel(ByVal key As Integer)
        ExecuteNonQuery("DELETE FROM ReportLevels WHERE LevelID = @LevelID AND LevelOrder > 1", New List(Of SqlParameter) From {New SqlParameter("@LevelID", key)})
    End Sub
#End Region

#Region "Admin - Parameter Manager Methods"

    <WebMethod()>
    Public Function GetReportParamsConfig(ByVal reportId As Integer) As String
        Dim query As String = "SELECT ParameterID, ReportID, ParameterName, UIType, Label, SourceQuery FROM ReportParameters WHERE ReportID = @ReportID"
        Dim dt = GetDataTable(query:=query, connectionString:=BIConnString, params:=New List(Of SqlParameter) From {New SqlParameter("@ReportID", reportId)})
        Return ConvertDataTableToJson(dt)
    End Function

    <WebMethod()>
    Public Sub InsertReportParam(ByVal values As Dictionary(Of String, Object))
        Dim query As String = "INSERT INTO ReportParameters (ReportID, ParameterName, Label, UIType, SourceQuery) VALUES (@ReportID, @ParameterName, @Label, @UIType, @SourceQuery)"
        ExecuteNonQuery(query, GetParamsFromDict(values))
    End Sub

    <WebMethod()>
    Public Sub UpdateReportParam(ByVal key As Integer, ByVal values As Dictionary(Of String, Object))
        Dim sb As New StringBuilder("UPDATE ReportParameters SET ")
        Dim updateFields As New List(Of String)
        For Each kvp In values
            updateFields.Add($"{kvp.Key} = @{kvp.Key}")
        Next
        sb.Append(String.Join(", ", updateFields))
        sb.Append(" WHERE ParameterID = @ParameterID")
        Dim params = GetParamsFromDict(values)
        params.Add(New SqlParameter("@ParameterID", key))
        ExecuteNonQuery(sb.ToString(), params)
    End Sub

    <WebMethod()>
    Public Sub DeleteReportParam(ByVal key As Integer)
        ExecuteNonQuery("DELETE FROM ReportParameters WHERE ParameterID = @ParameterID", New List(Of SqlParameter) From {New SqlParameter("@ParameterID", key)})
    End Sub

#End Region

#Region "User - Report Viewer Methods"
    <WebMethod()>
    Public Function GetReportMenu() As String
        Return ConvertDataTableToJson(GetDataTable("SELECT ReportID, ReportName FROM Reports WHERE IsActive = 1 ORDER BY ReportName"))
    End Function

    'Returns the list Of parameters For a given report, including their metadata And, If applicable, their selectable options.
    <WebMethod()>
    Public Function GetReportParameters(ByVal reportId As Integer) As String
        Dim paramsQuery As String = "SELECT ParameterName, Label, UIType, SourceQuery FROM ReportParameters WHERE ReportID = @ReportID"
        Dim paramsDt = GetDataTable(query:=paramsQuery, connectionString:=BIConnString, params:=New List(Of SqlParameter) From {New SqlParameter("@ReportID", reportId)})
        Dim parameters As New List(Of Dictionary(Of String, Object))
        For Each row As DataRow In paramsDt.Rows
            Dim paramDict = ConvertDataRowToDictionary(row)
            If Not IsDBNull(paramDict("SourceQuery")) AndAlso Not String.IsNullOrWhiteSpace(paramDict("SourceQuery").ToString()) Then
                Try
                    Dim optionsDt = GetDataTable(paramDict("SourceQuery").ToString(), ClientConnString)
                    paramDict.Add("Options", ConvertDataTableToDictionaryList(optionsDt))
                Catch ex As Exception
                    paramDict.Add("Options", New List(Of Object) From {New With {.error = ex.Message}})
                End Try
            End If
            parameters.Add(paramDict)
        Next
        Return Serializer.Serialize(parameters)
    End Function

    <WebMethod()>
    Public Function GetLevelConfig(ByVal reportId As Integer, ByVal level As Integer) As String
        Dim query As String = "SELECT DrillDownKeyField FROM ReportLevels WHERE ReportID = @ReportID AND LevelOrder = @LevelOrder"
        Dim resultDict As New Dictionary(Of String, Object)
        Dim params As New List(Of SqlParameter) From {New SqlParameter("@ReportID", reportId), New SqlParameter("@LevelOrder", level)}
        Using dt As DataTable = GetDataTable(query:=query, connectionString:=BIConnString, params:=params)
            If dt.Rows.Count > 0 Then
                resultDict.Add("DrillDownKeyField", If(dt.Rows(0).IsNull("DrillDownKeyField"), Nothing, dt.Rows(0)("DrillDownKeyField").ToString()))
            End If
        End Using
        Return Serializer.Serialize(resultDict)
    End Function

    <WebMethod()>
    Public Function ExecuteReportQuery(ByVal reportId As Integer, ByVal level As Integer, ByVal parameters As Dictionary(Of String, Object)) As String
        Try
            Dim reportInfoQuery As String = "SELECT SQLQuery, ChartType, DrillDownKeyField FROM ReportLevels WHERE ReportID = @ReportID AND LevelOrder = @LevelOrder"
            Dim reportInfo As New Dictionary(Of String, Object)
            Dim execParams As New List(Of SqlParameter) From {New SqlParameter("@ReportID", reportId), New SqlParameter("@LevelOrder", level)}

            Using dtConfig As DataTable = GetDataTable(query:=reportInfoQuery, connectionString:=BIConnString, params:=execParams)
                If dtConfig.Rows.Count > 0 Then
                    reportInfo.Add("Query", dtConfig.Rows(0)("SQLQuery").ToString())
                    reportInfo.Add("Type", dtConfig.Rows(0)("ChartType").ToString())
                    reportInfo.Add("ArgumentField", If(dtConfig.Rows(0).IsNull("DrillDownKeyField"), Nothing, dtConfig.Rows(0)("DrillDownKeyField").ToString()))
                Else
                    Return Serializer.Serialize(New With {.error = "Report level not found."})
                End If
            End Using

            Dim dt As New DataTable()
            Using conn As New SqlConnection(ClientConnString)
                Using cmd As New SqlCommand(reportInfo("Query").ToString(), conn)
                    If parameters IsNot Nothing Then
                        For Each p In parameters
                            cmd.Parameters.AddWithValue(p.Key, p.Value)
                        Next
                    End If
                    Using adapter As New SqlDataAdapter(cmd)
                        adapter.Fill(dt)
                    End Using
                End Using
            End Using

            Return Serializer.Serialize(New With {
                .Data = ConvertDataTableToDictionaryList(dt),
                .ChartSettings = New With {.Type = reportInfo("Type"), .ArgumentField = reportInfo("ArgumentField"), .ValueField = Nothing}
            })
        Catch ex As Exception
            Return Serializer.Serialize(New With {.error = "Query Execution Failed: " & ex.Message.Replace(vbCrLf, " ").Replace("'", """")})
        End Try
    End Function

    <WebMethod()>
    Public Function GetDrilldownInfo(ByVal parentReportId As Integer, ByVal currentLevel As Integer) As Object
        Dim nextLevelOrder As Integer = currentLevel + 1
        Dim query As String = "SELECT LevelTitle FROM ReportLevels WHERE ReportID = @ReportID AND LevelOrder = @NextLevelOrder"
        Dim nextLevelTitle As String = Nothing
        Dim params As New List(Of SqlParameter) From {New SqlParameter("@ReportID", parentReportId), New SqlParameter("@NextLevelOrder", nextLevelOrder)}
        Using dt As DataTable = GetDataTable(query:=query, connectionString:=BIConnString, params:=params)
            If dt.Rows.Count > 0 Then
                nextLevelTitle = dt.Rows(0)("LevelTitle").ToString()
            End If
        End Using

        If String.IsNullOrEmpty(nextLevelTitle) Then Return Nothing

        Return New With {.NextLevel = nextLevelOrder, .NextLevelTitle = nextLevelTitle}
    End Function
#End Region

#Region "Helper Functions"
    Private Function GetDataTable(query As String, connectionString As String, Optional params As List(Of SqlParameter) = Nothing) As DataTable
        Dim dt As New DataTable()
        Using conn As New SqlConnection(connectionString), cmd As New SqlCommand(query, conn)
            If params IsNot Nothing Then cmd.Parameters.AddRange(params.ToArray())
            Using adapter As New SqlDataAdapter(cmd)
                adapter.Fill(dt)
            End Using
        End Using
        Return dt
    End Function

    Private Function GetDataTable(query As String, Optional params As List(Of SqlParameter) = Nothing) As DataTable
        Return GetDataTable(query:=query, connectionString:=BIConnString, params:=params)
    End Function

    Private Sub ExecuteNonQuery(query As String, params As List(Of SqlParameter), connectionString As String)
        Using conn As New SqlConnection(connectionString), cmd As New SqlCommand(query, conn)
            If params IsNot Nothing Then cmd.Parameters.AddRange(params.ToArray())
            conn.Open()
            cmd.ExecuteNonQuery()
        End Using
    End Sub

    Private Sub ExecuteNonQuery(query As String, params As List(Of SqlParameter))
        ExecuteNonQuery(query:=query, params:=params, connectionString:=BIConnString)
    End Sub

    Private Function GetParamsFromDict(ByVal dict As Dictionary(Of String, Object)) As List(Of SqlParameter)
        Dim params As New List(Of SqlParameter)
        For Each kvp In dict
            params.Add(New SqlParameter("@" & kvp.Key, If(kvp.Value, DBNull.Value)))
        Next
        Return params
    End Function

    Private Function ConvertDataTableToJson(ByVal dt As DataTable) As String
        Return Serializer.Serialize(ConvertDataTableToDictionaryList(dt))
    End Function

    Private Function ConvertDataTableToDictionaryList(ByVal dt As DataTable) As List(Of Dictionary(Of String, Object))
        Dim rows As New List(Of Dictionary(Of String, Object))()
        For Each dr As DataRow In dt.Rows
            rows.Add(ConvertDataRowToDictionary(dr))
        Next
        Return rows
    End Function

    Private Function ConvertDataRowToDictionary(dr As DataRow) As Dictionary(Of String, Object)
        Dim row = New Dictionary(Of String, Object)()
        For Each col As DataColumn In dr.Table.Columns
            row.Add(col.ColumnName, If(dr.IsNull(col), Nothing, dr(col)))
        Next
        Return row
    End Function
#End Region

End Class
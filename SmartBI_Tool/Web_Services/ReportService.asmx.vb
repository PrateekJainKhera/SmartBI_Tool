Imports System.Web.Services
Imports System.ComponentModel
Imports System.Web.Script.Services
Imports System.Data.SqlClient
Imports System.Configuration
Imports System.Web.Script.Serialization
Imports System.Text
Imports System.Collections.Generic

<System.Web.Script.Services.ScriptService()>
<WebService(Namespace:="http://tempuri.org/")>
<WebServiceBinding(ConformsTo:=WsiProfiles.BasicProfile1_1)>
<ToolboxItem(False)>
Public Class ReportService
    Inherits System.Web.Services.WebService

    Private ReadOnly ConnString As String = ConfigurationManager.ConnectionStrings("DefaultConnection").ConnectionString
    Private ReadOnly Serializer As New JavaScriptSerializer() With {.MaxJsonLength = Integer.MaxValue}

#Region "Admin - Report Manager Methods"
    <WebMethod()>
    Public Function GetReports() As String
        Return ConvertDataTableToJson(GetDataTable("SELECT ReportID, ReportName, ReportDescription, MenuCategory, ChartType, ReportQuery, IsActive, ChartArgumentField, ChartValueField FROM Report_Master ORDER BY ReportID DESC"))
    End Function

    <WebMethod()>
    Public Sub InsertReport(ByVal values As Dictionary(Of String, Object))
        Dim query As String = "INSERT INTO Report_Master (ReportName, ReportDescription, MenuCategory, ChartType, ReportQuery, IsActive, ChartArgumentField, ChartValueField) VALUES (@ReportName, @ReportDescription, @MenuCategory, @ChartType, @ReportQuery, @IsActive, @ChartArgumentField, @ChartValueField)"
        ExecuteNonQuery(query, GetAdminParameters(values))
    End Sub

    <WebMethod()>
    Public Sub UpdateReport(ByVal key As Integer, ByVal values As Dictionary(Of String, Object))
        Dim sb As New StringBuilder("UPDATE Report_Master SET ModifiedDate=GETDATE()")
        For Each kvp As KeyValuePair(Of String, Object) In values
            sb.Append($", {kvp.Key} = @{kvp.Key}")
        Next
        sb.Append(" WHERE ReportID=@ReportID")
        Dim parameters = GetAdminParameters(values)
        parameters.Add(New SqlParameter("@ReportID", key))
        ExecuteNonQuery(sb.ToString(), parameters)
    End Sub

    <WebMethod()>
    Public Sub DeleteReport(ByVal key As Integer)
        ExecuteNonQuery("DELETE FROM Report_Master WHERE ReportID=@ReportID", New List(Of SqlParameter) From {New SqlParameter("@ReportID", key)})
    End Sub

    ' --- NEWLY ADDED METHOD ---
    <WebMethod()>
    Public Function PreviewQuery(ByVal query As String) As String
        ' A safe, read-only query to get the first 5 rows.
        ' Using "WITH a as (...)" helps prevent this from executing any malicious INSERT/UPDATE/DELETE statements.
        Dim safeQuery As String = $"WITH a AS ({query}) SELECT TOP 5 * FROM a;"

        Try
            Dim dt As DataTable = GetDataTable(safeQuery)

            ' Get the column names from the resulting DataTable
            Dim columnNames As New List(Of String)
            For Each col As DataColumn In dt.Columns
                columnNames.Add(col.ColumnName)
            Next

            ' Package everything for the client
            Dim result As Object = New With {
                .Columns = columnNames,
                .PreviewData = ConvertDataTableToDictionaryList(dt)
            }

            Return Serializer.Serialize(result)

        Catch ex As Exception
            ' Return a structured error if the query is invalid
            Return Serializer.Serialize(New With {
                .error = "Invalid SQL Query: " & ex.Message.Replace(vbCrLf, " ").Replace("'", """")
            })
        End Try
    End Function

#End Region

#Region "Admin - Drilldown Link Methods"
    <WebMethod()>
    Public Function GetDrilldownLinks(ByVal parentReportId As Integer) As String
        Dim query As String = "SELECT L.LinkID, L.Parent_ReportID, L.Trigger_Column_Name, L.Child_ReportID, R.ReportName AS ChildReportName, L.Parameter_Target_Name FROM Report_Drilldown_Links L JOIN Report_Master R ON L.Child_ReportID = R.ReportID WHERE L.Parent_ReportID = @ParentReportID"
        Dim dt = GetDataTable(query, New List(Of SqlParameter) From {New SqlParameter("@ParentReportID", parentReportId)})
        Return ConvertDataTableToJson(dt)
    End Function

    <WebMethod()>
    Public Sub AddDrilldownLink(ByVal values As Dictionary(Of String, Object))
        Dim query As String = "INSERT INTO Report_Drilldown_Links (Parent_ReportID, Child_ReportID, Trigger_Column_Name, Parameter_Target_Name) VALUES (@Parent_ReportID, @Child_ReportID, @Trigger_Column_Name, @Parameter_Target_Name)"
        Dim params As New List(Of SqlParameter) From {New SqlParameter("@Parent_ReportID", values("Parent_ReportID")), New SqlParameter("@Child_ReportID", values("Child_ReportID")), New SqlParameter("@Trigger_Column_Name", values("Trigger_Column_Name")), New SqlParameter("@Parameter_Target_Name", values("Parameter_Target_Name"))}
        ExecuteNonQuery(query, params)
    End Sub

    <WebMethod()>
    Public Sub DeleteDrilldownLink(ByVal linkId As Integer)
        Dim query As String = "DELETE FROM Report_Drilldown_Links WHERE LinkID = @LinkID"
        ExecuteNonQuery(query, New List(Of SqlParameter) From {New SqlParameter("@LinkID", linkId)})
    End Sub
#End Region

#Region "User - Report Viewer Methods"
    <WebMethod()>
    Public Function GetReportMenu() As String
        Dim dt = GetDataTable("SELECT ReportID, ReportName FROM Report_Master WHERE IsActive = 1 ORDER BY ReportName")
        Return ConvertDataTableToJson(dt)
    End Function

    <WebMethod()>
    Public Function GetReportParameters(ByVal reportId As Integer) As String
        Dim paramsQuery As String = "SELECT ParameterName, Label, UIType, SourceQuery FROM Report_Parameters WHERE ReportID = @ReportID ORDER BY ParameterID"
        Dim paramsDt = GetDataTable(paramsQuery, New List(Of SqlParameter) From {New SqlParameter("@ReportID", reportId)})
        Dim parameters As New List(Of Dictionary(Of String, Object))
        For Each row As DataRow In paramsDt.Rows
            Dim paramDict = ConvertDataRowToDictionary(row)
            If Not IsDBNull(paramDict("SourceQuery")) AndAlso Not String.IsNullOrWhiteSpace(paramDict("SourceQuery").ToString()) Then
                Dim optionsDt = GetDataTable(paramDict("SourceQuery").ToString())
                paramDict.Add("Options", ConvertDataTableToDictionaryList(optionsDt))
            End If
            parameters.Add(paramDict)
        Next
        Return Serializer.Serialize(parameters)
    End Function

    <WebMethod()>
    Public Function ExecuteReportQuery(ByVal reportId As Integer, ByVal parameters As Dictionary(Of String, Object)) As String
        Try
            Dim reportInfoQuery As String = "SELECT ReportQuery, ChartType, ChartArgumentField, ChartValueField FROM Report_Master WHERE ReportID = @ReportID"
            Dim reportInfo As New Dictionary(Of String, Object)

            Using conn As New SqlConnection(ConnString)
                Using cmd As New SqlCommand(reportInfoQuery, conn)
                    cmd.Parameters.AddWithValue("@ReportID", reportId)
                    conn.Open()
                    Using reader As SqlDataReader = cmd.ExecuteReader()
                        If reader.Read() Then
                            reportInfo.Add("Query", reader("ReportQuery").ToString())
                            reportInfo.Add("Type", reader("ChartType").ToString())
                            reportInfo.Add("ArgumentField", If(reader.IsDBNull(reader.GetOrdinal("ChartArgumentField")), Nothing, reader("ChartArgumentField").ToString()))
                            reportInfo.Add("ValueField", If(reader.IsDBNull(reader.GetOrdinal("ChartValueField")), Nothing, reader("ChartValueField").ToString()))
                        Else
                            Return Serializer.Serialize(New With {.error = "Report ID not found."})
                        End If
                    End Using
                End Using

                Dim dt As New DataTable()
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

                Dim result As Object = New With {
                    .Data = ConvertDataTableToDictionaryList(dt),
                    .ChartSettings = New With {
                        .Type = reportInfo("Type"),
                        .ArgumentField = reportInfo("ArgumentField"),
                        .ValueField = reportInfo("ValueField")
                    }
                }
                Return Serializer.Serialize(result)
            End Using

        Catch ex As Exception
            Return Serializer.Serialize(New With {.error = "Query Execution Failed: " & ex.Message.Replace(vbCrLf, " ").Replace("'", """")})
        End Try
    End Function

    <WebMethod()>
    Public Function GetDrilldownInfo(ByVal parentReportId As Integer, ByVal triggerColumn As String) As Object
        Dim query As String = "SELECT L.Child_ReportID, R.ReportName AS ChildReportName, L.Parameter_Target_Name AS ParameterTargetName FROM Report_Drilldown_Links L JOIN Report_Master R ON L.Child_ReportID = R.ReportID WHERE L.Parent_ReportID = @ParentReportID AND L.Trigger_Column_Name = @TriggerColumn"
        Using con As New SqlConnection(ConnString)
            Using cmd As New SqlCommand(query, con)
                cmd.Parameters.AddWithValue("@ParentReportID", parentReportId)
                cmd.Parameters.AddWithValue("@TriggerColumn", triggerColumn)
                con.Open()
                Using reader As SqlDataReader = cmd.ExecuteReader()
                    If reader.Read() Then
                        Return New With {.ChildReportID = Convert.ToInt32(reader("Child_ReportID")), .ChildReportName = reader("ChildReportName").ToString(), .ParameterTargetName = reader("ParameterTargetName").ToString()}
                    Else
                        Return Nothing
                    End If
                End Using
            End Using
        End Using
    End Function
#End Region

#Region "Helper Functions"
    Private Function GetDataTable(query As String, Optional params As List(Of SqlParameter) = Nothing) As DataTable
        Dim dt As New DataTable()
        Using conn As New SqlConnection(ConnString), cmd As New SqlCommand(query, conn)
            If params IsNot Nothing Then cmd.Parameters.AddRange(params.ToArray())
            Dim adapter As New SqlDataAdapter(cmd)
            adapter.Fill(dt)
        End Using
        Return dt
    End Function
    Private Sub ExecuteNonQuery(query As String, params As List(Of SqlParameter))
        Using conn As New SqlConnection(ConnString), cmd As New SqlCommand(query, conn)
            If params IsNot Nothing Then cmd.Parameters.AddRange(params.ToArray())
            conn.Open()
            cmd.ExecuteNonQuery()
        End Using
    End Sub
    Private Function GetAdminParameters(ByVal dict As Dictionary(Of String, Object)) As List(Of SqlParameter)
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
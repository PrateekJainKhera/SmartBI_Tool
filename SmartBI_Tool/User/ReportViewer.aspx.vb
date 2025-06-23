' File: User/ReportViewer.aspx.vb
Imports System.Web.Services
Imports System.Data
Imports System.Data.SqlClient
Imports System.Configuration
Imports System.Web.Script.Serialization

Public Class ReportViewer
    Inherits System.Web.UI.Page

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As EventArgs) Handles Me.Load
        ' No server-side logic needed on page load.
    End Sub

    ' --- Connection String ---
    Private Shared ReadOnly ConnString As String = ConfigurationManager.ConnectionStrings("DefaultConnection").ConnectionString

    ' --- JSON Serializer ---
    Private Shared ReadOnly Serializer As New JavaScriptSerializer()

    ' --- 1. Get all report menu items ---
    <WebMethod()>
    Public Shared Function GetReportMenu() As String
        Dim dt As New DataTable()
        Using conn As New SqlConnection(ConnString)
            Dim query As String = "SELECT ReportID, ReportName FROM Report_Master WHERE IsActive = 1 ORDER BY ReportName"
            Dim adapter As New SqlDataAdapter(query, conn)
            adapter.Fill(dt)
        End Using

        ' Build HTML buttons for menu
        Dim html As New Text.StringBuilder()
        For Each row As DataRow In dt.Rows
            html.AppendFormat("<a href='#' class='menu-item' data-report-id='{0}'>{1}</a>", row("ReportID"), row("ReportName"))
        Next
        Return html.ToString()
    End Function

    ' --- 2. Get chart type and metadata (if needed) ---
    <WebMethod()>
    Public Shared Function GetReportDefinition(ByVal reportId As Integer) As String
        Dim dt As New DataTable()
        Using conn As New SqlConnection(ConnString)
            Dim query As String = "SELECT ReportID, ReportName, ChartType FROM Report_Master WHERE ReportID = @ReportID"
            Using cmd As New SqlCommand(query, conn)
                cmd.Parameters.AddWithValue("@ReportID", reportId)
                Dim adapter As New SqlDataAdapter(cmd)
                adapter.Fill(dt)
            End Using
        End Using

        If dt.Rows.Count = 0 Then
            Return "{""error"":""No report definition found for the selected report ID.""}"
        End If

        Return DataTableToJson(dt.Rows(0))
    End Function

    ' --- 3. Run the report query ---
    <WebMethod()>
    Public Shared Function ExecuteReportQuery(ByVal reportId As Integer, ByVal parameters As Dictionary(Of String, Object)) As String
        Dim reportQuery As String = ""

        ' 1. Get the SQL query from database
        Using conn As New SqlConnection(ConnString)
            Using cmd As New SqlCommand("SELECT ReportQuery FROM Report_Master WHERE ReportID = @ReportID", conn)
                cmd.Parameters.AddWithValue("@ReportID", reportId)
                conn.Open()
                reportQuery = Convert.ToString(cmd.ExecuteScalar())
            End Using
        End Using

        If String.IsNullOrWhiteSpace(reportQuery) Then
            Return "{""error"":""Report query not found or is empty.""}"
        End If

        ' 2. Execute report SQL query
        Dim dt As New DataTable()
        Try
            Using conn As New SqlConnection(ConnString)
                Using cmd As New SqlCommand(reportQuery, conn)
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
        Catch ex As Exception
            Return Serializer.Serialize(New With {.error = ex.Message.Replace("""", "'").Replace(vbCrLf, " ")})
        End Try

        Return DataTableToJson(dt)
    End Function

    ' --- 4. Drilldown helper (optional) ---
    <WebMethod()>
    Public Shared Function GetDrilldownChild(ByVal parentReportId As Integer, ByVal triggerColumn As String) As String
        Dim dt As New DataTable()
        Using conn As New SqlConnection(ConnString)
            Dim query As String = "
                SELECT 
                    l.Child_ReportID, 
                    r.ReportName, 
                    r.ChartType, 
                    l.Parameter_Target_Name
                FROM Report_Drilldown_Links l
                JOIN Report_Master r ON l.Child_ReportID = r.ReportID
                WHERE l.Parent_ReportID = @ParentReportID AND l.Trigger_Column_Name = @TriggerColumn"

            Using cmd As New SqlCommand(query, conn)
                cmd.Parameters.AddWithValue("@ParentReportID", parentReportId)
                cmd.Parameters.AddWithValue("@TriggerColumn", triggerColumn)
                Dim adapter As New SqlDataAdapter(cmd)
                adapter.Fill(dt)
            End Using
        End Using

        If dt.Rows.Count > 0 Then
            Return DataTableToJson(dt.Rows(0))
        Else
            Return "null"
        End If
    End Function

    ' --- JSON Helpers ---
    Private Shared Function DataTableToJson(ByVal dt As DataTable) As String
        Dim rows As New List(Of Dictionary(Of String, Object))()
        For Each dr As DataRow In dt.Rows
            Dim row As New Dictionary(Of String, Object)()
            For Each col As DataColumn In dt.Columns
                row.Add(col.ColumnName, If(dr.IsNull(col), Nothing, dr(col)))
            Next
            rows.Add(row)
        Next
        Return Serializer.Serialize(rows)
    End Function

    Private Shared Function DataTableToJson(ByVal dr As DataRow) As String
        Dim row As New Dictionary(Of String, Object)()
        For Each col As DataColumn In dr.Table.Columns
            row.Add(col.ColumnName, If(dr.IsNull(col), Nothing, dr(col)))
        Next
        Return Serializer.Serialize(row)
    End Function
End Class

' File: Admin/ReportManager.aspx.vb (CORRECTED AND SIMPLIFIED)

' We no longer need all the extra Imports for SQL and Serialization here.
Public Class ReportManager
	Inherits System.Web.UI.Page

	Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
		' This method still runs when the page is first requested from the server.
		' However, all the dynamic grid logic (loading, saving, deleting)
		' is now handled by the JavaScript calls to our new ReportService.asmx file.
		' Therefore, this code-behind file can be empty.
	End Sub

End Class
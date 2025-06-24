<%@ Page Title="Report Manager" Language="vb" MasterPageFile="~/Site.Master" AutoEventWireup="false" CodeBehind="ReportManager.aspx.vb" Inherits="SmartBI_Tool.ReportManager" %>

<asp:Content ID="BodyContent" ContentPlaceHolderID="MainContent" runat="server">
    <style>
        .page-header { margin-bottom: 2.5rem; }
        .page-header h2 { font-family: 'Poppins', sans-serif; font-weight: 700; color: #1a202c; }
        .dx-datagrid { border: none; }
        .dx-datagrid-headers { background-color: #f9fafb; border-bottom: 1px solid var(--border-color); }
        .dx-datagrid-headers .dx-datagrid-text-content { font-weight: 600; color: var(--text-secondary); text-transform: uppercase; font-size: .8rem; letter-spacing: .05em; }
        .status-badge { padding: 5px 12px; border-radius: 15px; color: white; font-weight: 500; font-size: 0.85em; text-align: center; display: inline-block; }
        .status-active { background-color: #10b981; }
        .status-inactive { background-color: #6b7280; }
        .master-detail-view { padding: 20px; background-color: #f9fafb; border-top: 1px solid var(--border-color); }
        .master-detail-view h5 { font-family: 'Poppins', sans-serif; font-weight: 600; color: #4a5568; }
        .master-detail-view p { color: #718096; }
        .master-detail-view pre { white-space: pre-wrap; word-break: break-all; background-color: #1e293b; color: #e5e7eb; border: 1px solid #374151; padding: 15px; border-radius: 6px; font-family: 'Courier New', Courier, monospace; }
    </style>

    <div class="page-header">
        <h2>Report & Level Management</h2>
        <p class="text-secondary">Create master reports, configure their drilldown levels, and define dynamic parameters.</p>
    </div>
    
    <div class="content-card">
        <div id="gridContainer"></div>
    </div>

    <div id="levelsPopup"><div id="levelsGrid"></div></div>
    <div id="parametersPopup"><div id="parametersGrid"></div></div>

    <script>
        $(function () {
            const reportsDataSource = new DevExpress.data.CustomStore({
                key: "ReportID",
                load: () => $.ajax({ type: "POST", url: "/Web_Services/ReportService.asmx/GetReports", contentType: "application/json", dataType: "json" }).then(r => JSON.parse(r.d)),
                insert: (values) => $.ajax({ type: "POST", url: "/Web_Services/ReportService.asmx/InsertReport", data: JSON.stringify({ values }), contentType: "application/json" }).done(() => DevExpress.ui.notify("Report created successfully!", "success", 2000)),
                update: (key, values) => $.ajax({ type: "POST", url: "/Web_Services/ReportService.asmx/UpdateReport", data: JSON.stringify({ key, values }), contentType: "application/json" }).done(() => DevExpress.ui.notify("Report updated successfully!", "success", 2000)),
                remove: (key) => $.ajax({ type: "POST", url: "/Web_Services/ReportService.asmx/DeleteReport", data: JSON.stringify({ key }), contentType: "application/json" }).done(() => DevExpress.ui.notify("Report deleted successfully!", "success", 2000))
            });

            const levelsPopup = $("#levelsPopup").dxPopup({ width: '90%', maxWidth: 1200, height: '80vh', showTitle: true, title: "Manage Report Levels", visible: false, dragEnabled: false, closeOnOutsideClick: true }).dxPopup("instance");
            const parametersPopup = $("#parametersPopup").dxPopup({ width: '80%', maxWidth: 1000, height: '70vh', showTitle: true, title: "Manage Report Parameters", visible: false, dragEnabled: false, closeOnOutsideClick: true }).dxPopup("instance");

            $("#gridContainer").dxDataGrid({
                dataSource: reportsDataSource,
                columns: [
                    { dataField: "ReportID", caption: "ID", width: 70, allowEditing: false },
                    "ReportName",
                    {
                        dataField: "IsActive", caption: "Status", dataType: "boolean", width: 120, alignment: 'center',
                        cellTemplate: (container, options) => $('<div>').addClass('status-badge').addClass(options.value ? 'status-active' : 'status-inactive').text(options.value ? 'Active' : 'Inactive').appendTo(container)
                    },
                    { dataField: "ReportDescription", visible: false }, { dataField: "ReportQuery", visible: false }, { dataField: "ChartType", visible: false }, { dataField: "ChartArgumentField", visible: false },
                    {
                        type: "buttons", width: 150,
                        buttons: [
                            { name: "edit", icon: "edit", hint: "Edit Report (Level 1)" },
                            { name: "delete", icon: "trash", hint: "Delete Report" },
                            { hint: "Manage Levels", icon: "hierarchy", onClick: (e) => openLevelsManager(e.row.data.ReportID, e.row.data.ReportName) },
                            { hint: "Manage Parameters", icon: "preferences", onClick: (e) => openParametersManager(e.row.data.ReportID, e.row.data.ReportName) }
                        ]
                    }
                ],
                masterDetail: {
                    enabled: true,
                    template: (container, options) => {
                        $('<div>').addClass('master-detail-view').append(
                            $('<h5>').text('Description'),
                            $('<p>').text(options.data.ReportDescription || 'No description provided.'),
                            $('<h5 class="mt-3">').text('Level 1 Query'),
                            $('<pre>').text(options.data.ReportQuery)
                        ).appendTo(container);
                    }
                },
                showBorders: true, filterRow: { visible: true }, paging: { pageSize: 10 },
                editing: {
                    mode: "popup", allowAdding: true, allowUpdating: true, allowDeleting: true,
                    popup: { title: "Report Editor (Level 1)", showTitle: true, width: '80%', maxWidth: 1000, height: 'auto' },
                    form: {
                        colCount: 2,
                        items: [
                            { itemType: "group", caption: "1. Basic Info", colSpan: 1, items: ["ReportName", { dataField: "ChartType", editorType: "dxSelectBox", editorOptions: { items: ["Bar", "Line", "Pie", "Doughnut", "Spline", "Area", "GridOnly"], value: "Bar" } }, "IsActive", { dataField: "ReportDescription", editorType: "dxTextArea", editorOptions: { height: 180 }, colSpan: 2 }] },
                            { itemType: "group", caption: "2. Query & Preview", colSpan: 1, items: [{ dataField: "ReportQuery", editorType: "dxTextArea", editorOptions: { height: 300 }, helpText: "Write your SELECT query for Level 1 here." }, { itemType: "button", horizontalAlignment: "right", buttonOptions: { text: "Preview Data", icon: "find", type: "default", onClick: (e) => { previewQueryData(e.component.getForm()); } } }] },
                            { dataField: "ChartArgumentField", helpText: "Enter column name that will trigger the next level's drilldown.", colSpan: 2 },
                            { itemType: "group", caption: "Data Preview", colSpan: 2, visible: false, name: "previewGroup", items: [{ name: "previewGrid", itemType: "simple", template: "<div id='previewGrid'></div>" }] }
                        ]
                    }
                }
            });

            function openLevelsManager(reportId, reportName) {
                levelsPopup.option("title", `Manage Drilldown Levels for: ${reportName}`);
                const levelsDataSource = new DevExpress.data.CustomStore({
                    key: "LevelID",
                    load: () => $.ajax({ type: "POST", url: "/Web_Services/ReportService.asmx/GetReportLevels", data: JSON.stringify({ reportId }), contentType: "application/json", dataType: "json" }).then(r => JSON.parse(r.d)),
                    insert: (values) => { values.ReportID = reportId; return $.ajax({ type: "POST", url: "/Web_Services/ReportService.asmx/InsertReportLevel", data: JSON.stringify({ values }), contentType: "application/json" }); },
                    update: (key, values) => $.ajax({ type: "POST", url: "/Web_Services/ReportService.asmx/UpdateReportLevel", data: JSON.stringify({ key, values }), contentType: "application/json" }),
                    remove: (key) => $.ajax({ type: "POST", url: "/Web_Services/ReportService.asmx/DeleteReportLevel", data: JSON.stringify({ key }), contentType: "application/json" })
                });
                $("#levelsGrid").dxDataGrid({
                    dataSource: levelsDataSource,
                    columns: [
                        { dataField: "LevelOrder", caption: "Level", dataType: "number", width: 80, allowEditing: false, validationRules: [{ type: "required" }] },
                        { dataField: "LevelTitle", caption: "Title", validationRules: [{ type: "required" }] },
                        { dataField: "ChartType", editorType: "dxSelectBox", editorOptions: { items: ["Bar", "Line", "Pie", "Doughnut", "Spline", "Area", "GridOnly"] } },
                        { dataField: "DrillDownKeyField", caption: "Drilldown Key" },
                        { dataField: "SQLQuery", visible: false }
                    ],
                    masterDetail: {
                        enabled: true,
                        template: (container, options) => {
                            $('<div>').addClass('master-detail-view').append(
                                $('<h5 class="mt-3">').text('SQL Query for Level ' + options.data.LevelOrder + ':'),
                                $('<pre>').text(options.data.SQLQuery)
                            ).appendTo(container);
                        }
                    },
                    editing: {
                        mode: "popup", allowAdding: true, allowUpdating: true, allowDeleting: true,
                        popup: { title: "Level Editor", width: '80%', maxWidth: 900, height: 'auto' },
                        form: { items: [{ itemType: "group", colCount: 2, items: ["LevelOrder", "LevelTitle"] }, { itemType: "group", colCount: 2, items: ["ChartType", "DrillDownKeyField"] }, { dataField: "SQLQuery", editorType: "dxTextArea", colSpan: 2, label: { text: "SQL Query for this Level" }, editorOptions: { height: 250 }, helpText: "Use @ParameterName from the parent level. E.g., WHERE Country = @COUNTRY" }] }
                    },
                    onInitNewRow: (e) => { e.data.LevelOrder = e.component.totalCount() + 1; },
                    onEditingStart: (e) => { if (e.data.LevelOrder === 1) { DevExpress.ui.notify("Level 1 is tied to the master report and cannot be edited here.", "info", 4000); e.cancel = true; } },
                    onRowRemoving: (e) => { if (e.data.LevelOrder === 1) { DevExpress.ui.notify("Level 1 cannot be deleted.", "error", 3000); e.cancel = true; } },
                    showBorders: true
                });
                levelsPopup.show();
            }

            function openParametersManager(reportId, reportName) {
                parametersPopup.option("title", `Parameters for: ${reportName}`);
                const paramsDataSource = new DevExpress.data.CustomStore({
                    key: "ParameterID",
                    load: () => $.ajax({ type: "POST", url: "/Web_Services/ReportService.asmx/GetReportParamsConfig", data: JSON.stringify({ reportId }), contentType: "application/json", dataType: "json" }).then(r => JSON.parse(r.d)),
                    insert: (values) => { values.ReportID = reportId; return $.ajax({ type: "POST", url: "/Web_Services/ReportService.asmx/InsertReportParam", data: JSON.stringify({ values }), contentType: "application/json" }); },
                    update: (key, values) => $.ajax({ type: "POST", url: "/Web_Services/ReportService.asmx/UpdateReportParam", data: JSON.stringify({ key, values }), contentType: "application/json" }),
                    remove: (key) => $.ajax({ type: "POST", url: "/Web_Services/ReportService.asmx/DeleteReportParam", data: JSON.stringify({ key }), contentType: "application/json" })
                });
                $("#parametersGrid").dxDataGrid({
                    dataSource: paramsDataSource,
                    columns: [
                        { dataField: "ParameterName", validationRules: [{ type: "required" }], helpText: "e.g., @CountryName" },
                        { dataField: "Label", validationRules: [{ type: "required" }], helpText: "e.g., Select a Country" },
                        { dataField: "UIType", editorType: "dxSelectBox", editorOptions: { items: ["TextBox", "DropDown", "DatePicker"] } },
                        { dataField: "SourceQuery", caption: "Dropdown Source Query", helpText: "e.g., SELECT DISTINCT COUNTRY FROM sales_data" }
                    ],
                    editing: { mode: "row", allowAdding: true, allowUpdating: true, allowDeleting: true },
                    showBorders: true
                });
                parametersPopup.show();
            }

            function previewQueryData(form) {
                if (!form) { return; }
                const query = form.getEditor("ReportQuery").option("value");
                if (!query) { DevExpress.ui.notify("Please enter a SQL query first.", "warning", 2000); return; }
                $.ajax({
                    type: "POST", url: "/Web_Services/ReportService.asmx/PreviewQuery", data: JSON.stringify({ query }),
                    contentType: "application/json", dataType: "json"
                }).done(function (response) {
                    const result = JSON.parse(response.d);
                    if (result.error) { DevExpress.ui.notify(result.error, "error", 5000); form.itemOption("previewGroup", "visible", false); return; }
                    DevExpress.ui.notify("Query Preview Successful!", "success", 2000);
                    form.itemOption("previewGroup", "visible", true);
                    const previewGrid = $('#previewGrid');
                    if (!previewGrid.data('dxDataGrid')) { previewGrid.dxDataGrid({ showBorders: true, columnAutoWidth: true, height: 200 }); }
                    previewGrid.dxDataGrid('instance').option('dataSource', result.PreviewData);
                }).fail(() => { DevExpress.ui.notify("A critical server error occurred.", "error", 3000); });
            }
        });
    </script>
</asp:Content>
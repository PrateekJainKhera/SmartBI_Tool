<%@ Page Title="Report Manager" Language="vb" MasterPageFile="~/Site.Master" AutoEventWireup="false" CodeBehind="ReportManager.aspx.vb" Inherits="SmartBI_Tool.ReportManager" %>

<asp:Content ID="BodyContent" ContentPlaceHolderID="MainContent" runat="server">
    <style>
        #previewGrid { margin-top: 15px; }
        .dx-form-group-caption { font-size: 1.2em !important; font-weight: bold !important; }
    </style>

    <h2>Report Creator</h2>
    <p>Use this grid to create, edit, and delete report templates. Use the 'Preview' button in the editor to test your query and get column names.</p>

    <div id="gridContainer"></div>
    <div id="drilldownPopup"> <div id="drilldownGrid"></div> </div>

    <script>
        $(function () {
            // Data sources remain the same as before...
            const reportsDataSource = new DevExpress.data.CustomStore({ /* ... no changes here ... */
                key: "ReportID",
                load: () => $.ajax({ type: "POST", url: "/Web_Services/ReportService.asmx/GetReports", contentType: "application/json; charset=utf-8", dataType: "json" }).then(r => JSON.parse(r.d)),
                insert: (values) => $.ajax({ type: "POST", url: "/Web_Services/ReportService.asmx/InsertReport", data: JSON.stringify({ values: values }), contentType: "application/json; charset=utf-8" }),
                update: (key, values) => $.ajax({ type: "POST", url: "/Web_Services/ReportService.asmx/UpdateReport", data: JSON.stringify({ key: key, values: values }), contentType: "application/json; charset=utf-8" }),
                remove: (key) => $.ajax({ type: "POST", url: "/Web_Services/ReportService.asmx/DeleteReport", data: JSON.stringify({ key: key }), contentType: "application/json; charset=utf-8" })
            });
            const childReportsLookupSource = new DevExpress.data.DataSource({ store: reportsDataSource, sort: "ReportName" });


            $("#gridContainer").dxDataGrid({
                dataSource: reportsDataSource,
                columns: [
                    { dataField: "ReportID", caption: "ID", width: 70, allowEditing: false },
                    "ReportName", "MenuCategory", { dataField: "IsActive", dataType: "boolean", width: 100 },
                    { type: "buttons", width: 110, buttons: ["edit", "delete", { hint: "Manage Drilldowns", icon: "link", onClick: function (e) { openDrilldownPopup(e.row.data.ReportID, e.row.data.ReportName); } }] }
                ],
                showBorders: true, filterRow: { visible: true }, paging: { pageSize: 10 },
                editing: {
                    mode: "popup", allowAdding: true, allowUpdating: true, allowDeleting: true,
                    popup: { title: "Report Template", showTitle: true, width: 900, height: 'auto' },
                    // --- START: ENHANCED FORM DEFINITION ---
                    form: {
                        onInitialized: function (e) {
                            // Store the form instance to access it later
                            window.reportFormInstance = e.component;
                        },
                        items: [
                            { itemType: "group", caption: "1. Basic Info", colCount: 2, items: ["ReportName", "MenuCategory", "ChartType", "IsActive", { dataField: "ReportDescription", colSpan: 2 }] },
                            {
                                itemType: "group", caption: "2. Query & Preview", items: [
                                    { dataField: "ReportQuery", editorType: "dxTextArea", editorOptions: { height: 150 } },
                                    { itemType: "button", horizontalAlignment: "right", buttonOptions: { text: "Preview Data & Get Columns", icon: "find", onClick: function (e) { previewQueryData(); } } }
                                ]
                            },
                            {
                                itemType: "group", caption: "3. Chart Configuration", colCount: 2, items: [
                                    { dataField: "ChartArgumentField", editorType: "dxSelectBox", label: { text: "Argument/Label Field (X-axis)" }, editorOptions: { items: [], placeholder: "Run preview to populate..." } },
                                    { dataField: "ChartValueField", editorType: "dxSelectBox", label: { text: "Value Field (Y-axis)" }, editorOptions: { items: [], placeholder: "Run preview to populate..." } }
                                ]
                            },
                            { itemType: "group", caption: "Data Preview (First 5 Rows)", items: [{ name: "previewGrid", itemType: "simple", template: "<div id='previewGrid'></div>" }] }
                        ]
                    }
                    // --- END: ENHANCED FORM DEFINITION ---
                }
            });

            // =================================================================
            // NEW FUNCTION TO HANDLE THE PREVIEW
            // =================================================================
            function previewQueryData() {
                const form = window.reportFormInstance;
                const query = form.getEditor("ReportQuery").option("value");

                if (!query) {
                    DevExpress.ui.notify("Please enter a SQL query first.", "warning", 2000);
                    return;
                }

                // Call the new backend method
                $.ajax({
                    type: "POST",
                    url: "/Web_Services/ReportService.asmx/PreviewQuery",
                    data: JSON.stringify({ query: query }),
                    contentType: "application/json; charset=utf-8",
                    dataType: "json",
                }).done(function (response) {
                    const result = JSON.parse(response.d);

                    if (result.error) {
                        DevExpress.ui.notify(result.error, "error", 5000);
                        // Clear previous successful results
                        $("#previewGrid").dxDataGrid({ dataSource: [] });
                        form.getEditor("ChartArgumentField").option("items", []);
                        form.getEditor("ChartValueField").option("items", []);
                        return;
                    }

                    DevExpress.ui.notify("Query successful! Column lists updated.", "success", 2000);

                    // Populate the column dropdowns
                    const argumentFieldEditor = form.getEditor("ChartArgumentField");
                    argumentFieldEditor.option("items", result.Columns);

                    const valueFieldEditor = form.getEditor("ChartValueField");
                    valueFieldEditor.option("items", result.Columns);

                    // Show the preview data in the small grid
                    $("#previewGrid").dxDataGrid({
                        dataSource: result.PreviewData,
                        showBorders: true,
                        columnAutoWidth: true
                    });
                }).fail(function () {
                    DevExpress.ui.notify("A critical error occurred while contacting the server.", "error", 3000);
                });
            }

            // Drilldown management logic remains the same
            const drilldownPopup = $("#drilldownPopup").dxPopup({ /* ... no changes here ... */
                width: 900, height: 600, showTitle: true, title: "Manage Drilldowns", visible: false, dragEnabled: false, closeOnOutsideClick: true
            }).dxPopup("instance");
            function openDrilldownPopup(parentReportId, parentReportName) { /* ... no changes here ... */
                drilldownPopup.option("title", `Drilldowns for: ${parentReportName}`);
                const drilldownLinksDataSource = new DevExpress.data.CustomStore({
                    key: "LinkID",
                    load: () => $.ajax({ type: "POST", url: "/Web_Services/ReportService.asmx/GetDrilldownLinks", data: JSON.stringify({ parentReportId: parentReportId }), contentType: "application/json; charset=utf-8", dataType: "json" }).then(r => JSON.parse(r.d)),
                    insert: (values) => { values.Parent_ReportID = parentReportId; return $.ajax({ type: "POST", url: "/Web_Services/ReportService.asmx/AddDrilldownLink", data: JSON.stringify({ values: values }), contentType: "application/json; charset=utf-8" }); },
                    remove: (key) => $.ajax({ type: "POST", url: "/Web_Services/ReportService.asmx/DeleteDrilldownLink", data: JSON.stringify({ linkId: key }), contentType: "application/json; charset=utf-8" })
                });
                $("#drilldownGrid").dxDataGrid({
                    dataSource: drilldownLinksDataSource,
                    editing: { mode: "row", allowAdding: true, allowDeleting: true },
                    columns: [
                        { dataField: "Trigger_Column_Name", caption: "Parent Trigger Column", validationRules: [{ type: "required" }] },
                        { dataField: "Child_ReportID", caption: "Child Report To Open", lookup: { dataSource: { store: childReportsLookupSource.store(), filter: ["ReportID", "<>", parentReportId] }, valueExpr: "ReportID", displayExpr: "ReportName" }, validationRules: [{ type: "required" }] },
                        { dataField: "Parameter_Target_Name", caption: "Child's Parameter Name", validationRules: [{ type: "required" }], cellTemplate: function (container, options) { container.attr("title", "Remember to include the '@' symbol, e.g., @CategoryName"); container.text(options.value); } }
                    ],
                    showBorders: true, wordWrapEnabled: true
                });
                drilldownPopup.show();
            }
        });
    </script>
</asp:Content>
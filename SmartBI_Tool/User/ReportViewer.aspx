<%@ Page Title="Report Viewer" Language="vb" MasterPageFile="~/Site.Master" AutoEventWireup="false" CodeBehind="ReportViewer.aspx.vb" Inherits="SmartBI_Tool.ReportViewer" %>

<asp:Content ID="BodyContent" ContentPlaceHolderID="MainContent" runat="server">
    <style>
        .menu-item { display: inline-block; padding: 8px 15px; margin: 5px; border: 1px solid #ddd; background-color: #f7f7f7; cursor: pointer; border-radius: 4px; font-weight: 500; }
        .menu-item:hover { background-color: #e9e9e9; border-color: #ccc; }
        #parameterContainer { display:none; margin-top: 20px; padding: 20px; border: 1px solid #ddd; background-color: #f9f9f9; border-radius: 5px; }
        .report-level-container { margin-top: 25px; padding: 20px; border: 1px solid #ddd; border-radius: 5px; background-color: #fff; box-shadow: 0 2px 4px rgba(0,0,0,0.05); }
        .report-level-header { display: flex; flex-wrap: wrap; justify-content: space-between; align-items: center; border-bottom: 2px solid #eee; padding-bottom: 10px; margin-bottom: 20px; gap: 15px; }
        .chart-container { height: 400px; margin-bottom: 30px; }
        #loadingSpinner { display: none; margin-top: 20px; text-align: center; padding: 40px; font-size: 1.2em; }
        .report-actions { display: flex; align-items: center; gap: 10px; }
    </style>

    <h2>Report Viewer</h2>
    <p>Select a report to begin.</p>

    <div id="reportMenu"></div>
    <div id="parameterContainer"></div>
    <div id="reportLevelsContainer"></div>
    <div id="loadingSpinner"><strong>Loading...</strong></div>

    <script>
        $(function () {
            // =================================================================
            // 1. INITIAL MENU LOADING
            // =================================================================
            $.ajax({
                type: "POST", url: "/Web_Services/ReportService.asmx/GetReportMenu", contentType: "application/json; charset=utf-8", dataType: "json"
            }).done(function (response) {
                const menuData = JSON.parse(response.d);
                $("#reportMenu").empty();
                menuData.forEach(item => $("#reportMenu").append(`<a href="#" class="menu-item" data-report-id="${item.ReportID}">${item.ReportName}</a>`));
            });

            // =================================================================
            // 2. HANDLE MENU CLICKS (CHECKS FOR PARAMETERS)
            // =================================================================
            $("#reportMenu").on("click", ".menu-item", function (e) {
                e.preventDefault();
                const reportId = $(this).data("report-id");
                const reportName = $(this).text();
                $("#reportLevelsContainer").empty();
                $("#parameterContainer").empty().hide();
                $.ajax({
                    type: "POST", url: "/Web_Services/ReportService.asmx/GetReportParameters", data: JSON.stringify({ reportId: reportId }), contentType: "application/json; charset=utf-8", dataType: "json",
                    beforeSend: () => $("#loadingSpinner").show(),
                    complete: () => $("#loadingSpinner").hide()
                }).done(function (response) {
                    const parameters = JSON.parse(response.d);
                    if (parameters && parameters.length > 0) {
                        buildParameterForm(reportId, reportName, parameters);
                    } else {
                        loadReport(reportId, reportName, null, 0);
                    }
                });
            });

            // =================================================================
            // 3. BUILD THE PARAMETER INPUT FORM
            // =================================================================
            function buildParameterForm(reportId, reportName, parameters) {
                const formContainer = $("#parameterContainer");
                let formItems = [];
                parameters.forEach(p => {
                    let item = { dataField: p.ParameterName, label: { text: p.Label }, editorType: "dxTextBox" };
                    if (p.UIType === 'dropdown' && p.Options && p.Options.length > 0) {
                        item.editorType = "dxSelectBox";
                        item.editorOptions = { dataSource: p.Options, displayExpr: Object.keys(p.Options[0])[1], valueExpr: Object.keys(p.Options[0])[0] };
                        item.validationRules = [{ type: "required", message: `${p.Label} is required.` }];
                    }
                    formItems.push(item);
                });
                formItems.push({ itemType: "button", horizontalAlignment: "left", buttonOptions: { text: "Run Report", type: "default", useSubmitBehavior: true } });
                const form = formContainer.dxForm({ formData: {}, items: formItems, validationGroup: "reportParams" }).dxForm("instance");
                formContainer.on("submit", function (e) {
                    e.preventDefault();
                    if (form.validate().isValid) {
                        loadReport(reportId, reportName, form.option("formData"), 0);
                        formContainer.empty().hide();
                    }
                });
                formContainer.show();
            }

            // =================================================================
            // 4. CORE REPORT & DRILLDOWN LOADING FUNCTION
            // =================================================================
            function loadReport(reportId, reportName, parameters, level) {
                $('.report-level-container').filter(function () { return $(this).data('level') >= level; }).remove();
                $("#loadingSpinner").show();
                $.ajax({
                    type: "POST", url: "/Web_Services/ReportService.asmx/ExecuteReportQuery", data: JSON.stringify({ reportId: reportId, parameters: parameters }), contentType: "application/json; charset=utf-8", dataType: "json"
                }).done(function (response) {
                    const result = JSON.parse(response.d);
                    if (result.error) {
                        alert("Error executing report: " + result.error);
                        $("#loadingSpinner").hide(); return;
                    }
                    const levelId = "report-level-" + level;
                    let headerHtml = `<div class="report-level-header"><h3>${reportName}</h3><div class="report-actions"><div id="chartTypeSelector-${level}"></div><div id="exportExcelBtn-${level}"></div><div id="exportPdfBtn-${level}"></div>${level > 0 ? `<div id="backBtn-${level}"></div>` : ''}</div></div>`;
                    const reportHtml = `<div id="${levelId}" class="report-level-container" data-level="${level}">${headerHtml}<div class="chart-container"></div><div class="grid-container"></div></div>`;
                    $("#reportLevelsContainer").append(reportHtml);
                    const $currentLevel = $("#" + levelId);

                    const chart = $currentLevel.find(".chart-container").dxChart(
                        buildChartOptions(result.Data, reportName, result.ChartSettings, reportId, level)
                    ).dxChart("instance");

                    const grid = $currentLevel.find(".grid-container").dxDataGrid({
                        dataSource: { store: new DevExpress.data.ArrayStore({ data: result.Data, key: result.ChartSettings.ArgumentField || 'ID' }) },
                        showBorders: true, columnAutoWidth: true, hoverStateEnabled: true,
                        onRowClick: function (e) {
                            if (!e.data || e.rowType !== 'data' || !e.column) return;
                            handleDrilldown(reportId, e.column.dataField, e.data, level);
                        },
                        onContentReady: function (e) { e.component.getColumns().forEach(function (column) { if (column.dataField && column.dataField.toLowerCase().includes('date')) { e.component.columnOption(column.dataField, "dataType", "date"); } }); }
                    }).dxDataGrid("instance");

                    if (level > 0) { $(`#backBtn-${level}`).dxButton({ text: "Back", icon: "back", onClick: function () { $currentLevel.remove(); } }); }
                    $(`#exportExcelBtn-${level}`).dxButton({ text: "Excel", icon: "exportxlsx", hint: "Export to Excel", onClick: function () { DevExpress.excelExporter.exportDataGrid({ component: grid, fileName: `${reportName}` }); } });
                    $(`#exportPdfBtn-${level}`).dxButton({ text: "PDF", icon: "exportpdf", hint: "Export to PDF", onClick: function () { const { jsPDF } = window.jspdf; const doc = new jsPDF(); DevExpress.pdfExporter.exportChart({ component: chart, doc, rect: [10, 15, 190, 90] }).then(() => DevExpress.pdfExporter.exportDataGrid({ component: grid, doc, y: 115 })).then(() => doc.save(`${reportName}.pdf`)); } });
                    if (result.ChartSettings.Type !== 'treemap') {
                        $(`#chartTypeSelector-${level}`).dxSelectBox({
                            dataSource: ['bar', 'line', 'spline', 'area', 'pie', 'donut'],
                            value: result.ChartSettings.Type, width: 120,
                            onValueChanged: function (e) {
                                result.ChartSettings.Type = e.value;
                                chart.option(buildChartOptions(result.Data, reportName, result.ChartSettings, reportId, level));
                            }
                        });
                    } else { $(`#chartTypeSelector-${level}`).hide(); }

                }).always(() => $("#loadingSpinner").hide());
            }

            // =================================================================
            // 5. HELPER FUNCTION TO BUILD CHART OPTIONS (DEFINITIVE VERSION)
            // =================================================================
            function buildChartOptions(data, reportName, settings, reportId, level) {
                const argumentField = settings.ArgumentField || (data.length > 0 ? Object.keys(data[0])[0] : '');
                const valueField = settings.ValueField || (data.length > 0 ? Object.keys(data[0])[1] : '');

                let options = { dataSource: data, title: reportName, tooltip: { enabled: true }, legend: { visible: true, horizontalAlignment: 'center', verticalAlignment: 'bottom' } };
                const pointClickHandler = (e) => handleDrilldown(reportId, argumentField, e.target.data, level);

                if (settings.Type === 'treemap') {
                    options.type = 'treemap';
                    options.labelField = 'CustomerName';
                    options.valueField = 'TotalAmount';
                    options.colorField = 'CustomerName';
                    options.onClick = (e) => handleDrilldown(reportId, 'CustomerName', e.node.data, level);
                } else if (['pie', 'donut'].includes(settings.Type)) {
                    options.type = settings.Type;
                    options.series = [{ argumentField: argumentField, valueField: valueField, label: { visible: true, connector: { visible: true }, format: 'percent', customizeText: (arg) => `${arg.argumentText}: ${arg.percentText}` } }];
                    options.onPointClick = pointClickHandler;
                } else {
                    options.legend.visible = false;
                    options.commonSeriesSettings = { argumentField: argumentField, type: settings.Type || 'bar' };
                    options.series = [{ valueField: valueField, name: reportName }];
                    options.onPointClick = pointClickHandler;
                }
                return options;
            }

            // =================================================================
            // 6. DRILLDOWN HANDLER (DEFINITIVE VERSION)
            // =================================================================
            function handleDrilldown(parentReportId, triggerColumn, selectedDataRow, currentLevel) {
                if (!triggerColumn || !selectedDataRow) return;

                $.ajax({
                    type: "POST", url: "/Web_Services/ReportService.asmx/GetDrilldownInfo", data: JSON.stringify({ parentReportId: parentReportId, triggerColumn: triggerColumn }), contentType: "application/json; charset=utf-8", dataType: "json"
                }).done(function (response) {
                    const drillInfo = response.d;
                    if (drillInfo && drillInfo.ChildReportID > 0) {
                        // Build a parameter object using ALL available data from the clicked row.
                        // The backend will pick only the parameters it needs.
                        let parameters = {};
                        for (const key in selectedDataRow) {
                            parameters['@' + key] = selectedDataRow[key];
                        }

                        loadReport(drillInfo.ChildReportID, drillInfo.ChildReportName, parameters, currentLevel + 1);
                    }
                });
            }
        });
    </script>
</asp:Content>
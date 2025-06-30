<%@ Page Title="Dashboard" Language="vb" MasterPageFile="~/Site.Master" AutoEventWireup="false" CodeBehind="ReportViewer.aspx.vb" Inherits="SmartBI_Tool.ReportViewer" %>

<asp:Content ID="BodyContent" ContentPlaceHolderID="MainContent" runat="server">
    <style>
        .page-header { margin-bottom: 2.5rem; }
        .page-header h2 { font-family: 'Poppins', sans-serif; font-weight: 700; color: #1a202c; }
        .viewer-container { display: flex; gap: 2.5rem; align-items: flex-start; }
        .report-sidebar { flex: 0 0 300px; }
        .report-content-area { flex-grow: 1; min-width: 0; }
        .report-library-card, #parameterContainer, .report-level-container { background-color: var(--card-bg); padding: 25px; border-radius: 12px; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.1), 0 2px 4px -1px rgba(0,0,0,0.06); border: 1px solid var(--border-color); }
        .report-library-card h4, .report-level-header h3 { font-family: 'Poppins', sans-serif; font-weight: 600; color: #1e293b; }
        .report-library-card h4 { display: flex; align-items: center; gap: 10px; padding-bottom: 15px; border-bottom: 1px solid var(--border-color); margin-bottom: 15px; }
        #reportMenu { display: flex; flex-direction: column; gap: 8px; }
        .menu-item { padding: 12px 16px; cursor: pointer; border-radius: 8px; font-weight: 500; color: #475569; background-color: transparent; border: 1px solid transparent; transition: all 0.2s; display: flex; align-items: center; gap: 12px; text-decoration: none; }
        .menu-item:hover { background-color: #f1f5f9; color: var(--brand-color, #4f46e5); }
        .menu-item.active { background-color: var(--brand-color, #4f46e5); color: white; font-weight: 600; border-color: var(--brand-color, #4f46e5); box-shadow: 0 4px 14px 0 rgba(79, 70, 229, 0.3); transform: translateY(-2px); }
        .menu-item .fa-fw { width: 20px; text-align: center; }
        #breadcrumb-container { margin-bottom: 1.5rem; }
        .breadcrumb { background-color: transparent; padding: 0; font-size: 0.9em; }
        .breadcrumb-item a { text-decoration: none; color: var(--brand-color, #4f46e5); font-weight: 500; }
        .breadcrumb-item.active { color: var(--text-secondary); }
        #parameterContainer { margin-bottom: 25px; }
        .report-level-container { margin-top: 25px; }
        #loadingSpinner { text-align: center; padding: 50px; }
    </style>

    <div class="page-header">
        <h2>Analytics Dashboard</h2>
        <p class="text-secondary">Select a report from the library to visualize data and gain insights.</p>
    </div>

    <div class="viewer-container">
        <aside class="report-sidebar">
            <div class="report-library-card">
                <h4><i class="fas fa-book-open text-primary"></i> Report Library</h4>
                <div id="reportMenu"><div class="text-center p-4"><div class="spinner-border text-secondary" role="status"></div></div></div>
            </div>
        </aside>

        <main class="report-content-area">
            <div id="welcomeMessage">
                <div class="alert alert-primary border-0" style="background-color: #eef2ff; color: #3730a3;">
                    <h4 class="alert-heading"><i class="fas fa-info-circle"></i> Welcome to Insightify!</h4>
                    <p>Your journey into data begins here. Please select a report from the library on the left to get started.</p>
                </div>
            </div>
            
            <div id="breadcrumb-container"></div>
            <div id="parameterContainer" class="mb-4" style="display:none;"></div>
            <div id="reportLevelsContainer"></div>
            <div id="loadingSpinner" style="display:none;">
                <div class="spinner-border text-primary" style="width: 3rem; height: 3rem;" role="status"></div>
                <h5 class="mt-3 text-secondary">Loading Report...</h5>
            </div>
        </main>
    </div>
    
    <script>
        $(function () {
            let breadcrumbTrail = [];

            function renderBreadcrumbs() {
                const $container = $('#breadcrumb-container').empty();
                if (breadcrumbTrail.length === 0) return;
                const nav = $('<nav aria-label="breadcrumb"><ol class="breadcrumb bg-light p-2 rounded"></ol></nav>');
                breadcrumbTrail.forEach((crumb, index) => {
                    const li = $('<li class="breadcrumb-item"></li>');
                    if (index === breadcrumbTrail.length - 1) {
                        li.addClass('active').attr('aria-current', 'page').text(crumb.name);
                    } else {
                        const link = $(`<a href="#">${crumb.name}</a>`);
                        link.data('level-data', crumb);
                        li.append(link);
                    }
                    nav.find('ol').append(li);
                });
                $container.append(nav);
            }

            $('#breadcrumb-container').on('click', 'a', function (e) {
                e.preventDefault();
                const crumb = $(this).data('level-data');
                if (!crumb) return;
                breadcrumbTrail = breadcrumbTrail.slice(0, crumb.level);
                renderBreadcrumbs();
                loadReport(crumb.reportId, crumb.name, crumb.level, crumb.params);
            });

            $.ajax({
                type: "POST", url: "/Web_Services/ReportService.asmx/GetReportMenu",
                contentType: "application/json", dataType: "json"
            }).done(function (response) {
                const menuData = JSON.parse(response.d);
                const $reportMenu = $("#reportMenu").empty();
                if (menuData.length === 0) { $reportMenu.html('<p class="text-muted text-center">No active reports found.</p>'); return; }
                menuData.forEach(item => {
                    $reportMenu.append(`<a href="#" class="menu-item" data-report-id="${item.ReportID}"><i class="fas fa-fw fa-file-alt"></i> ${item.ReportName}</a>`);
                });
            });

            $("#reportMenu").on("click", ".menu-item", function (e) {
                e.preventDefault();
                $("#reportMenu .menu-item").removeClass("active");
                $(this).addClass("active");
                const reportId = $(this).data("report-id");
                const reportName = $(this).clone().children().remove().end().text().trim();
                $("#reportLevelsContainer").empty();
                $("#parameterContainer").empty().hide();
                $("#welcomeMessage").hide();
                breadcrumbTrail = [];
                renderBreadcrumbs();
                checkAndLoadParameters(reportId, reportName);
            });

            function checkAndLoadParameters(reportId, reportName) {
                $("#loadingSpinner").show();
                $.ajax({
                    type: "POST", url: "/Web_Services/ReportService.asmx/GetReportParameters",
                    data: JSON.stringify({ reportId }), contentType: "application/json", dataType: "json"
                }).done(function (response) {
                    const parameters = JSON.parse(response.d);
                    if (parameters && parameters.length > 0) {
                        buildParameterForm(reportId, reportName, parameters);
                    } else {
                        loadReport(reportId, reportName, 1, null);
                    }
                }).fail(() => DevExpress.ui.notify("Error checking parameters.", "error"))
                    .always(() => $("#loadingSpinner").hide());
            }

            function buildParameterForm(reportId, reportName, parameters) {
                const $formContainer = $("#parameterContainer");
                $formContainer.show();
                let formItems = [];
                parameters.forEach(p => {
                    let fieldName = p.ParameterName.substring(1);
                    let editorOptions = {};
                    if (p.UIType === 'DropDown' && p.Options && p.Options.length > 0) {
                        editorOptions = {
                            dataSource: p.Options,
                            displayExpr: Object.keys(p.Options[0] || {})[0],
                            valueExpr: Object.keys(p.Options[0] || {})[0]
                        };
                    }
                    formItems.push({
                        dataField: fieldName,
                        label: { text: p.Label },
                        editorType: p.UIType === 'DropDown' ? 'dxSelectBox' : 'dxTextBox',
                        editorOptions: editorOptions,
                        validationRules: [{ type: "required" }]
                    });
                });
                formItems.push({ itemType: "button", horizontalAlignment: "left", buttonOptions: { text: "Run Report", icon: "check", type: "default", useSubmitBehavior: true } });
                const form = $formContainer.dxForm({ formData: {}, items: formItems, colCount: 3 }).dxForm("instance");
                $formContainer.on("submit", function (e) {
                    e.preventDefault();
                    if (form.validate().isValid) {
                        let userParams = {};
                        const formData = form.option("formData");
                        for (const key in formData) { userParams['@' + key] = formData[key]; }
                        loadReport(reportId, reportName, 1, userParams);
                        $formContainer.hide().empty();
                    }
                });
            }
            //Grid Data Show
            function loadReport(reportId, reportName, level, parameters) {
                if (level === 1) {
                    breadcrumbTrail = [{ name: reportName, level: 1, reportId: reportId, params: parameters }];
                }
                renderBreadcrumbs();
                $('.report-level-container').filter(function () { return $(this).data('level') >= level; }).remove();
                $("#loadingSpinner").show();
                $.ajax({
                    type: "POST", url: "/Web_Services/ReportService.asmx/ExecuteReportQuery",
                    data: JSON.stringify({ reportId, level, parameters }), contentType: "application/json", dataType: "json"
                }).done(function (response) {
                    const result = JSON.parse(response.d);
                    if (result.error) { DevExpress.ui.notify(result.error, 'error', 5000); return; }
                    const levelId = "report-level-" + level;
                    let headerHtml = `<div class="report-level-header d-flex justify-content-between align-items-center"><h3>${reportName}</h3><div id="exportExcelBtn-${level}"></div></div>`;
                    const reportHtml = `<div id="${levelId}" class="report-level-container" data-level="${level}" data-report-id="${reportId}">${headerHtml}<div class="chart-container mt-3"></div><div class="grid-container mt-4"></div></div>`;
                    $("#reportLevelsContainer").append(reportHtml);
                    const grid = $(`#${levelId} .grid-container`).dxDataGrid({
                        dataSource: result.Data, showBorders: true, columnAutoWidth: true, hoverStateEnabled: true, filterRow: { visible: true }, scrolling: { mode: 'virtual' },
                        onRowClick: (e) => { if (e.data && e.rowType === 'data') handleDrilldown(reportId, level, e.data); }
                    }).dxDataGrid("instance");
                    if (result.ChartSettings.Type !== 'GridOnly' && result.Data.length > 0) {
                        const chartOptions = buildChartOptions(result.Data, reportName, result.ChartSettings, reportId, level);
                        if (chartOptions) { $(`#${levelId} .chart-container`).dxChart(chartOptions); }
                    }
                    $(`#exportExcelBtn-${level}`).dxButton({ text: "Export", icon: "exportxlsx", onClick: () => DevExpress.excelExporter.exportDataGrid({ component: grid, fileName: `${reportName}_Level${level}` }) });
                }).always(() => $("#loadingSpinner").hide());
            }

            function buildChartOptions(data, reportName, settings, reportId, level) {
                if (!settings.ArgumentField || !data || data.length === 0) return null;
                let valueField = Object.keys(data[0]).find(key => typeof data[0][key] === 'number' && !key.toLowerCase().includes('id'));
                const pointClickHandler = (e) => handleDrilldown(reportId, level, e.target.data);
                return {
                    dataSource: data, palette: "Violet",
                    commonSeriesSettings: { argumentField: settings.ArgumentField, type: settings.Type || 'bar' },
                    series: [{ valueField: valueField, name: reportName }],
                    onPointClick: pointClickHandler, tooltip: { enabled: true, customizeTooltip: (arg) => ({ text: `${arg.argumentText}: ${arg.valueText}` }) },
                    legend: { visible: false }
                };
            }

            function handleDrilldown(reportId, currentLevel, selectedDataRow) {
                if (!selectedDataRow) return;
                $("#loadingSpinner").show();
                $.ajax({
                    type: "POST", url: "/Web_Services/ReportService.asmx/GetLevelConfig",
                    data: JSON.stringify({ reportId, level: currentLevel }), contentType: "application/json", dataType: "json"
                }).done(function (configResponse) {
                    const config = JSON.parse(configResponse.d);
                    if (!config || !config.DrillDownKeyField) { $("#loadingSpinner").hide(); return; }
                    const keyToPass = config.DrillDownKeyField;
                    $.ajax({
                        type: "POST", url: "/Web_Services/ReportService.asmx/GetDrilldownInfo",
                        data: JSON.stringify({ parentReportId: reportId, currentLevel: currentLevel }),
                        contentType: "application/json", dataType: "json"
                    }).done(function (drillInfoResponse) {
                        const drillInfo = drillInfoResponse.d;
                        if (drillInfo && drillInfo.NextLevel > 0) {
                            let parameters = {};
                            let actualKeyInRow = Object.keys(selectedDataRow).find(k => k.toLowerCase() === keyToPass.toLowerCase());
                            if (actualKeyInRow) {
                                parameters['@' + keyToPass] = selectedDataRow[actualKeyInRow];
                                let dynamicTitle = drillInfo.NextLevelTitle.replace('@' + keyToPass, selectedDataRow[actualKeyInRow]);
                                breadcrumbTrail = breadcrumbTrail.slice(0, currentLevel);
                                breadcrumbTrail.push({ name: dynamicTitle, level: drillInfo.NextLevel, reportId: reportId, params: parameters });
                                loadReport(reportId, dynamicTitle, drillInfo.NextLevel, parameters);
                            } else {
                                DevExpress.ui.notify(`Drilldown failed: Key '${keyToPass}' not found.`, 'error', 6000);
                            }
                        }
                    }).always(() => $("#loadingSpinner").hide());
                }).fail(() => {
                    $("#loadingSpinner").hide();
                    DevExpress.ui.notify("Error fetching level configuration.", "error", 4000);
                });
            }
        });
    </script>
</asp:Content>
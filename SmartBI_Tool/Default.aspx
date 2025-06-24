<%@ Page Title="Welcome" Language="vb" MasterPageFile="~/Site.Master" AutoEventWireup="false" CodeBehind="Default.aspx.vb" Inherits="SmartBI_Tool._Default" %>

<asp:Content ID="BodyContent" ContentPlaceHolderID="MainContent" runat="server">

    <style>
        .hero-section {
            text-align: center;
            padding: 4rem 1rem;
            background-color: var(--card-bg);
            border-radius: 12px;
            margin-bottom: 3rem;
            border: 1px solid var(--border-color);
        }

        .hero-section .icon {
            font-size: 3rem;
            color: var(--brand-color);
            margin-bottom: 1rem;
        }

        .hero-section h1 {
            font-family: 'Poppins', sans-serif;
            font-size: 3.5rem;
            font-weight: 700;
            color: var(--text-primary);
            margin-bottom: 1rem;
        }

        .hero-section p.lead {
            font-size: 1.25rem;
            color: var(--text-secondary);
            max-width: 700px;
            margin: 0 auto 2rem auto;
        }

        .cta-buttons .btn {
            font-size: 1.1rem;
            padding: 12px 30px;
            font-weight: 600;
            border-radius: 8px;
            margin: 0 10px;
            transition: all 0.2s;
        }
        
        .feature-card {
            background-color: var(--card-bg);
            padding: 25px;
            border-radius: 12px;
            text-align: center;
            border: 1px solid var(--border-color);
            transition: transform 0.2s, box-shadow 0.2s;
        }
        
        .feature-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 10px 20px rgba(0,0,0,0.08);
        }

        .feature-card .feature-icon {
            font-size: 2.5rem;
            color: var(--brand-color);
            margin-bottom: 1rem;
        }
        
        .feature-card h4 {
            font-family: 'Poppins', sans-serif;
            font-weight: 600;
            color: var(--text-primary);
        }
    </style>

    <div class="hero-section">
        <div class="icon">
            <i class="fas fa-lightbulb"></i>
        </div>
        <h1>Unlock Your Data's Potential</h1>
        <p class="lead">
            Welcome to Insightify, your self-service Business Intelligence platform. Create dynamic reports, visualize complex data, and drill down to uncover the insights that matter.
        </p>
        <div class="cta-buttons">
            <a href="User/ReportViewer.aspx" class="btn btn-primary">
                <i class="fas fa-chart-line me-2"></i>Go to Dashboard
            </a>
            <a href="Admin/ReportManager.aspx" class="btn btn-outline-secondary">
                <i class="fas fa-cogs me-2"></i>Manage Reports
            </a>
        </div>
    </div>

    <div class="row text-center g-4">
        <div class="col-md-4">
            <div class="feature-card">
                <div class="feature-icon"><i class="fas fa-drafting-compass"></i></div>
                <h4>Dynamic Reports</h4>
                <p class="text-secondary">Create any report on the fly using powerful SQL queries without writing a single line of application code.</p>
            </div>
        </div>
        <div class="col-md-4">
            <div class="feature-card">
                <div class="feature-icon"><i class="fas fa-chart-pie"></i></div>
                <h4>Interactive Charts</h4>
                <p class="text-secondary">Visualize your data with interactive charts. Click on any segment to explore deeper into the data.</p>
            </div>
        </div>
        <div class="col-md-4">
            <div class="feature-card">
                <div class="feature-icon"><i class="fas fa-sitemap"></i></div>
                <h4>N-Level Drilldown</h4>
                <p class="text-secondary">Configure unlimited levels of drill-down to analyze your data from a high-level summary to the finest detail.</p>
            </div>
        </div>
    </div>

</asp:Content>
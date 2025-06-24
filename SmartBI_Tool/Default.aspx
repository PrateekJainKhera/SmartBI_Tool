<%@ Page Title="Welcome" Language="vb" MasterPageFile="~/Site.Master" AutoEventWireup="false" CodeBehind="Default.aspx.vb" Inherits="SmartBI_Tool._Default" %>

<asp:Content ID="BodyContent" ContentPlaceHolderID="MainContent" runat="server">

    <%-- =================================================================== --%>
    <%-- === MASTERPIECE UI/UX WITH ANIMATED BACKGROUND === --%>
    <%-- =================================================================== --%>
    <style>
        /* Override page background from master page for a full-bleed effect */
        .main-content {
            padding: 0 !important; /* Remove master page padding */
            position: relative;
            overflow: hidden; /* Important for containing the animated background */
        }
        
        /* The Animated Gradient Background */
        .main-content::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            z-index: 0; /* Behind all content */
            background: linear-gradient(125deg, #e0c3fc, #8ec5fc, #e0c3fc, #a8edea);
            background-size: 400% 400%; /* Makes the gradient large enough to animate */
            animation: gradient-animation 20s ease infinite;
        }

        @keyframes gradient-animation {
            0% { background-position: 0% 50%; }
            50% { background-position: 100% 50%; }
            100% { background-position: 0% 50%; }
        }

        /* Container to place content above the background */
        .landing-container {
            position: relative;
            z-index: 1;
            max-width: 1200px;
            margin: 0 auto;
            padding: 5rem 2rem;
        }

        /* --- Hero Section with Enhanced Glassmorphism --- */
        .hero-section {
            text-align: center;
            padding: 5rem 2rem;
            border-radius: 24px;
            margin-bottom: 4rem;
            background: rgba(255, 255, 255, 0.5);
            backdrop-filter: blur(20px);
            -webkit-backdrop-filter: blur(20px);
            border: 1px solid rgba(255, 255, 255, 0.2);
            box-shadow: 0 16px 40px rgba(0, 0, 0, 0.1);
            opacity: 0;
            transform: scale(0.95);
            animation: fadeInScaleUp 1s ease-out 0.2s forwards;
        }

        .hero-section .icon {
            font-size: 3.5rem;
            color: #4f46e5;
            margin-bottom: 1.5rem;
            display: inline-block;
        }

        .hero-section h1 {
            font-family: 'Poppins', sans-serif;
            font-size: 4rem;
            font-weight: 700;
            color: #1f2937;
            margin-bottom: 1.5rem;
            letter-spacing: -2px;
            text-shadow: 0 2px 10px rgba(255,255,255,0.5); /* Subtle shadow for readability */
        }

        .hero-section p.lead {
            font-size: 1.3rem;
            color: #4b5563;
            max-width: 750px;
            margin: 0 auto 2.5rem auto;
            line-height: 1.7;
        }

        .cta-buttons .btn {
            font-size: 1.1rem;
            padding: 16px 40px;
            font-weight: 600;
            border-radius: 12px;
            margin: 0 10px;
            transition: all 0.3s cubic-bezier(0.25, 0.8, 0.25, 1);
            border-width: 0;
        }
        .cta-buttons .btn:hover {
            transform: translateY(-5px) scale(1.05);
            box-shadow: 0 10px 25px rgba(0,0,0,0.15);
        }
        .cta-buttons .btn:active {
            transform: translateY(-2px) scale(1.02);
            box-shadow: 0 4px 10px rgba(0,0,0,0.15);
        }
        .cta-buttons .btn-primary {
             background: linear-gradient(45deg, #6366f1, #818cf8);
             color: white;
        }
        .cta-buttons .btn-light {
            background: #fff;
            color: #4f46e5;
        }

        /* --- Feature Section --- */
        .features-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 2rem;
        }
        
        .feature-card {
            padding: 35px;
            border-radius: 20px;
            text-align: center;
            background: rgba(255, 255, 255, 0.65);
            backdrop-filter: blur(15px);
            -webkit-backdrop-filter: blur(15px);
            border: 1px solid rgba(255, 255, 255, 0.3);
            position: relative;
            overflow: hidden;
            transition: transform 0.3s ease-out, box-shadow 0.3s ease-out;
            opacity: 0;
            transform: translateY(50px);
        }
        
        .feature-card::before {
            content: '';
            position: absolute;
            top: 50%; left: 50%;
            width: 350px; height: 350px;
            background-image: radial-gradient(circle, rgba(79, 70, 229, 0.15), transparent 65%);
            transform: translate(-50%, -50%) scale(0);
            transition: all 0.6s cubic-bezier(0.19, 1, 0.22, 1);
            opacity: 0;
        }
        .feature-card:hover::before {
            transform: translate(-50%, -50%) scale(1);
            opacity: 1;
        }
        .feature-card:hover {
            transform: translateY(-12px);
            box-shadow: 0 25px 50px -12px rgba(0,0,0,0.15);
        }
        
        .feature-card .feature-icon, .feature-card h4, .feature-card p { position: relative; z-index: 2; }
        .feature-card .feature-icon { font-size: 3rem; color: var(--brand-color); margin-bottom: 1.5rem; }
        .feature-card h4 { font-family: 'Poppins', sans-serif; font-weight: 600; color: var(--text-primary); }

        /* Keyframe Animations */
        @keyframes fadeInScaleUp {
            from { opacity: 0; transform: scale(0.95); }
            to { opacity: 1; transform: scale(1); }
        }
        
        @keyframes slideUpFadeIn {
            from { opacity: 0; transform: translateY(50px); }
            to { opacity: 1; transform: translateY(0); }
        }

        .feature-card.is-visible { animation: slideUpFadeIn 0.8s cubic-bezier(0.165, 0.84, 0.44, 1) forwards; }
        .feature-card:nth-child(1).is-visible { animation-delay: 0.2s; }
        .feature-card:nth-child(2).is-visible { animation-delay: 0.3s; }
        .feature-card:nth-child(3).is-visible { animation-delay: 0.4s; }
    </style>

    <div class="landing-container">
        <div class="hero-section">
            <div class="icon"><i class="fas fa-rocket"></i></div>
            <h1>Unlock Your Data's Potential</h1>
            <p class="lead">
                Welcome to Insightify, your self-service Business Intelligence platform. Create dynamic reports, visualize complex data, and drill down to uncover the insights that matter.
            </p>
            <div class="cta-buttons">
                <a href="User/ReportViewer.aspx" class="btn btn-primary shadow-lg">
                    <i class="fas fa-chart-line me-2"></i>Go to Dashboard
                </a>
                <a href="Admin/ReportManager.aspx" class="btn btn-light shadow-sm">
                    <i class="fas fa-cogs me-2"></i>Manage Reports
                </a>
            </div>
        </div>

        <div class="features-grid">
            <div class="animate-on-scroll">
                <div class="feature-card">
                    <div class="feature-icon"><i class="fas fa-drafting-compass"></i></div>
                    <h4>Dynamic Reports</h4>
                    <p class="text-secondary">Create any report on the fly using powerful SQL queries without writing a single line of application code.</p>
                </div>
            </div>
            <div class="animate-on-scroll">
                 <div class="feature-card">
                    <div class="feature-icon"><i class="fas fa-chart-pie"></i></div>
                    <h4>Interactive Charts</h4>
                    <p class="text-secondary">Visualize your data with interactive charts. Click on any segment to explore deeper into the data.</p>
                </div>
            </div>
            <div class="animate-on-scroll">
                 <div class="feature-card">
                    <div class="feature-icon"><i class="fas fa-sitemap"></i></div>
                    <h4>N-Level Drilldown</h4>
                    <p class="text-secondary">Configure unlimited levels of drill-down to analyze your data from a high-level summary to the finest detail.</p>
                </div>
            </div>
        </div>
    </div>

    <script>
        $(document).ready(function () {
            const observer = new IntersectionObserver((entries) => {
                entries.forEach(entry => {
                    if (entry.isIntersecting) {
                        $(entry.target).find('.feature-card').addClass('is-visible');
                        observer.unobserve(entry.target);
                    }
                });
            }, {
                threshold: 0.15 // Trigger a bit later for a better effect
            });

            $('.animate-on-scroll').each(function () {
                observer.observe(this);
            });
        });
    </script>

</asp:Content>
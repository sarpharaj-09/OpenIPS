%% =========================================================================
%  Rectangular Inset-Fed Microstrip Patch Antenna Design
%  Target Frequency : 2.4 GHz (WiFi / ESP-NOW)
%  Substrate        : FR4  (εr = 4.4, h = 1.6 mm, tan δ = 0.02)
%  Feed Impedance   : 50 Ω (inset feed, no external matching network)
%
%  PLOTS:
%   Figure 1 — Physical antenna structure (3D layered geometry)
%   Figure 2 — 3D radiation pattern (surface plot in dBi)
%   Figure 3 — S11 parameter vs frequency
%   Figure 4 — Input impedance (R & X) over 11 frequency points
%
%  Reference: Balanis, "Antenna Theory: Analysis and Design", 4th ed. (TLM)
%% =========================================================================

clc; clear; close all;

%% ── SUBSTRATE & FREQUENCY PARAMETERS ─────────────────────────────────────
c      = 3e8;          % Speed of light (m/s)
f0     = 2.4e9;        % Resonant frequency (Hz)
eps_r  = 4.4;          % FR4 relative permittivity
h      = 1.6e-3;       % Substrate thickness (m)
tan_d  = 0.02;         % FR4 loss tangent
Z0     = 50;           % Feed impedance target (Ω)

lambda0 = c / f0;
k0      = 2*pi*f0 / c;

fprintf('=== 2.4 GHz Inset-Fed Patch Antenna — Design Script ===\n\n');

%% ── DESIGN EQUATIONS (Transmission Line Model) ────────────────────────────

% --- Patch Width ---
W = (c / (2*f0)) * sqrt(2 / (eps_r + 1));

% --- Effective Dielectric Constant ---
eps_eff = (eps_r+1)/2 + (eps_r-1)/2 * (1 + 12*h/W)^(-0.5);

% --- End-Effect Length Extension ---
delta_L = 0.412*h * ((eps_eff+0.3)*(W/h+0.264)) / ((eps_eff-0.258)*(W/h+0.8));

% --- Physical Patch Length ---
L_eff = c / (2*f0*sqrt(eps_eff));
L     = L_eff - 2*delta_L;

% --- Ground Plane (6h clearance each side) ---
Lg = L + 6*h;
Wg = W + 6*h;

% --- Radiation Conductances (Balanis eqs 14-13a, 14-21) ---
theta_v   = linspace(1e-6, pi-1e-6, 2000);
intgd_G1  = (sin(k0*W/2 .* cos(theta_v)) ./ cos(theta_v)).^2 .* sin(theta_v).^3;
G1        = (1/(120*pi^2)) * trapz(theta_v, intgd_G1);
intgd_G12 = (sin(k0*W/2 .* cos(theta_v)) ./ cos(theta_v)).^2 .* ...
             besselj(0, k0*L.*sin(theta_v)) .* sin(theta_v).^3;
G12       = (1/(120*pi^2)) * trapz(theta_v, intgd_G12);

% --- Edge Resistance ---
R_edge = 1 / (2*(G1 + G12));

% --- Inset Feed Depth for 50 Ω ---
if R_edge < Z0
    error('R_edge = %.1f Ω < 50 Ω — increase patch width.', R_edge);
end
y0 = (L/pi) * acos(sqrt(Z0 / R_edge));

% --- Inset Notch Width ---
g  = W / 10;

% --- 50 Ω Feed Line Width (Hammerstad) ---
A   = (Z0/60)*sqrt((eps_r+1)/2) + ((eps_r-1)/(eps_r+1))*(0.23+0.11/eps_r);
Wf  = 8*h*exp(A) / (exp(2*A)-2);

% --- RLC Model for frequency sweep ---
BW_frac = 0.035;
w0_rad  = 2*pi*f0;
Q_val   = 1/BW_frac;
C_eq    = Q_val / (R_edge * w0_rad);
L_eq    = 1 / (w0_rad^2 * C_eq);

%% ── PRINT SUMMARY ─────────────────────────────────────────────────────────
fprintf('========== FINAL DESIGN SUMMARY ==========\n');
fprintf('  W   = %.3f mm  (patch width)\n',      W*1e3);
fprintf('  L   = %.3f mm  (patch length)\n',     L*1e3);
fprintf('  y0  = %.3f mm  (inset feed depth)\n', y0*1e3);
fprintf('  g   = %.3f mm  (notch half-width)\n', g*1e3);
fprintf('  Wf  = %.3f mm  (feed line width)\n',  Wf*1e3);
fprintf('  Lg  = %.2f mm, Wg = %.2f mm\n',       Lg*1e3, Wg*1e3);
fprintf('  R_edge  = %.2f Ω\n',                  R_edge);
fprintf('  R_in(y0)= %.2f Ω  (at feed point)\n', R_edge*cos(pi*y0/L)^2);
fprintf('==========================================\n\n');

%% ══════════════════════════════════════════════════════════════════════════
%  FIGURE 1 — PHYSICAL ANTENNA STRUCTURE (3D LAYERED GEOMETRY)
%% ══════════════════════════════════════════════════════════════════════════
fig1 = figure('Name','Figure 1 — Physical Antenna Structure', ...
              'Color','w','Position',[50 500 820 560]);

ax1 = axes('Parent',fig1);
hold(ax1,'on'); axis(ax1,'equal'); grid(ax1,'on');
view(ax1, -38, 28);
lighting(ax1,'gouraud');
camlight(ax1,'headlight');

% Coordinates (centred at origin for clarity)
Lmm = L*1e3;  Wmm = W*1e3;  Lgmm = Lg*1e3;  Wgmm = Wg*1e3;
hmm = h*1e3;  y0mm= y0*1e3; gm  = g*1e3;    Wfmm = Wf*1e3;
sub_t  = hmm;            % substrate thickness (mm) → visual z-scale
gnd_t  = 0.5;            % ground copper visual thickness (mm)
pat_t  = 0.5;            % patch copper visual thickness (mm)

% --- Helper: draw a box [x1 x2] × [y1 y2] × [z1 z2] ---
    function draw_box(x1,x2,y1,y2,z1,z2,col,alph)
        X = [x1 x2 x2 x1; x1 x2 x2 x1; x1 x1 x2 x2; x1 x1 x2 x2; x1 x2 x2 x1; x1 x2 x2 x1];
        Y = [y1 y1 y2 y2; y1 y1 y2 y2; y1 y2 y2 y1; y1 y2 y2 y1; y1 y1 y1 y1; y2 y2 y2 y2];
        Z = [z1 z1 z1 z1; z2 z2 z2 z2; z1 z1 z2 z2; z2 z2 z1 z1; z1 z1 z2 z2; z1 z1 z2 z2];
        patch('XData',X','YData',Y','ZData',Z','FaceColor',col, ...
              'FaceAlpha',alph,'EdgeColor',[0.3 0.3 0.3],'LineWidth',0.5);
    end

% Layer z positions
z_gnd_bot = 0;
z_gnd_top = gnd_t;
z_sub_bot = z_gnd_top;
z_sub_top = z_sub_bot + sub_t;
z_pat_bot = z_sub_top;
z_pat_top = z_pat_bot + pat_t;

% --- Ground plane (copper gold) ---
draw_box(-Wgmm/2, Wgmm/2, -Lgmm/2, Lgmm/2, z_gnd_bot, z_gnd_top, [0.85 0.65 0.13], 1.0);

% --- FR4 Substrate (green translucent) ---
draw_box(-Wgmm/2, Wgmm/2, -Lgmm/2, Lgmm/2, z_sub_bot, z_sub_top, [0.2 0.55 0.2], 0.25);

% --- Patch copper (split into 3 rectangles to show inset notches) ---
% Left block (from -W/2 to -(Wf/2+g))
x_notch_left  = -(Wfmm/2 + gm);
x_notch_right =  (Wfmm/2 + gm);
y_inset_edge  = -Lmm/2;
y_inset_top   = -Lmm/2 + y0mm;

% Full patch top band (above inset)
draw_box(-Wmm/2, Wmm/2, y_inset_top, Lmm/2, z_pat_bot, z_pat_top, [0.95 0.75 0.1], 1.0);
% Left patch strip in inset region
draw_box(-Wmm/2, x_notch_left, y_inset_edge, y_inset_top, z_pat_bot, z_pat_top, [0.95 0.75 0.1], 1.0);
% Right patch strip in inset region
draw_box(x_notch_right, Wmm/2, y_inset_edge, y_inset_top, z_pat_bot, z_pat_top, [0.95 0.75 0.1], 1.0);

% --- Feed line (red copper strip) ---
y_feed_bot = -Lgmm/2;
draw_box(-Wfmm/2, Wfmm/2, y_feed_bot, y_inset_edge, z_pat_bot, z_pat_top, [0.85 0.1 0.1], 1.0);

% --- SMA connector symbolic dot ---
scatter3(0, -Lgmm/2, z_pat_top+1, 120, 'k', 'filled');
text(1.5, -Lgmm/2-1, z_pat_top+2, 'SMA feed', 'FontSize', 9, 'Color','k');

% --- Dimension annotations ---
% Width arrow
annotation('doublearrow','X',[0.13 0.87],'Y',[0.07 0.07],'Color','b','LineWidth',1.5,'Head1Length',6,'Head2Length',6);
annotation('textbox',[0.35 0.02 0.3 0.06],'String',sprintf('W = %.1f mm', Wmm), ...
    'EdgeColor','none','HorizontalAlignment','center','FontSize',10,'Color','b','FontWeight','bold');

xlabel(ax1,'x (mm)','FontSize',11); ylabel(ax1,'y (mm)','FontSize',11); zlabel(ax1,'z (mm)','FontSize',11);
title(ax1, sprintf(['Physical Structure — 2.4 GHz Inset-Fed Patch Antenna\n' ...
    'W=%.1f mm, L=%.1f mm, y_0=%.1f mm, W_f=%.1f mm, g=%.1f mm'], ...
    Wmm, Lmm, y0mm, Wfmm, gm), 'FontSize', 12, 'FontWeight', 'bold');

% Legend patches
h_gnd = patch(NaN,NaN,[0.85 0.65 0.13],'DisplayName','Ground Plane (Cu)');
h_sub = patch(NaN,NaN,[0.2 0.55 0.2],  'FaceAlpha',0.25,'DisplayName','FR4 Substrate');
h_pat = patch(NaN,NaN,[0.95 0.75 0.1], 'DisplayName','Patch (Cu)');
h_fed = patch(NaN,NaN,[0.85 0.1 0.1],  'DisplayName','Feed Line (Cu)');
legend([h_gnd h_sub h_pat h_fed],'Location','northeast','FontSize',9);
xlim(ax1,[-Wgmm/2-2 Wgmm/2+2]); ylim(ax1,[-Lgmm/2-4 Lgmm/2+2]);

%% ══════════════════════════════════════════════════════════════════════════
%  FIGURE 2 — 3D RADIATION PATTERN (surface, dBi)
%% ══════════════════════════════════════════════════════════════════════════
% Analytical far-field: product of E-plane and H-plane patterns
% Valid above the ground plane (upper hemisphere, 0 ≤ θ ≤ π/2)

N_th = 90;   N_ph = 181;
theta_3d = linspace(0,   pi/2, N_th);   % elevation: 0=broadside, π/2=horizon
phi_3d   = linspace(0, 2*pi,  N_ph);    % azimuth

[TH, PH] = meshgrid(theta_3d, phi_3d);

% E-plane element factor (elevation in xz-plane)
FE = cos(k0*(L/2).*sin(TH).*cos(PH)) .* cos(TH);
% H-plane element factor (elevation in yz-plane)  
FH = sinc((k0*W/(2*pi)).*sin(TH).*sin(PH));

% Total field magnitude (approximate 3D pattern)
F_total = abs(FE .* FH);
F_total = F_total / max(F_total(:));     % normalise to 1

% Estimated directivity for dBi scale
D0_lin = (2*pi*W/lambda0)^2 / (pi * trapz(theta_v, intgd_G1));
D0_dBi = 10*log10(D0_lin);

F_dBi  = D0_dBi + 20*log10(F_total + 1e-10);   % shift to dBi
F_dBi  = max(F_dBi, D0_dBi - 30);              % clip -30 dB floor

% Convert to Cartesian for surface plot (radius = linear F)
R_surf = F_total;
Xs = R_surf .* sin(TH) .* cos(PH);
Ys = R_surf .* sin(TH) .* sin(PH);
Zs = R_surf .* cos(TH);

figure('Name','Figure 2 — 3D Radiation Pattern','Color','w','Position',[900 500 720 560]);
surf(Xs, Ys, Zs, F_dBi, 'EdgeColor','none','FaceAlpha',0.92);
colormap(jet); cb = colorbar;
cb.Label.String = 'Gain (dBi)'; cb.Label.FontSize = 11;
clim([D0_dBi-20, D0_dBi+1]);
hold on;
% Broadside marker
scatter3(0,0,1.02,120,'w','filled','MarkerEdgeColor','k','LineWidth',1.5);
text(0.05,0,1.1,sprintf('Peak ≈ %.1f dBi',D0_dBi),'FontSize',10,'FontWeight','bold');
% Ground plane disc
[xd,yd] = meshgrid(linspace(-1,1,40));
rd = sqrt(xd.^2+yd.^2); zd = zeros(size(xd)); zd(rd>1)=NaN;
surf(xd,yd,zd-0.02,'FaceColor',[0.85 0.65 0.13],'EdgeColor','none','FaceAlpha',0.5);

axis equal; grid on; view(-35,25);
xlabel('x','FontSize',11); ylabel('y','FontSize',11); zlabel('z (Broadside)','FontSize',11);
title(sprintf('3D Radiation Pattern — 2.4 GHz Patch (TLM)\nPeak Directivity ≈ %.1f dBi', D0_dBi), ...
    'FontSize',12,'FontWeight','bold');
lighting gouraud; camlight headlight;
annotation('textbox',[0.02 0.02 0.45 0.07],'String', ...
    'Upper hemisphere shown (ground plane below)', ...
    'FitBoxToText','on','EdgeColor',[0.6 0.6 0.6],'FontSize',9,'BackgroundColor','w');

%% ══════════════════════════════════════════════════════════════════════════
%  FIGURE 3 — S11 PARAMETER vs FREQUENCY
%% ══════════════════════════════════════════════════════════════════════════
f_span  = linspace(1.6e9, 3.4e9, 2000);
w_span  = 2*pi*f_span;

Z_in    = 1 ./ (1/R_edge + 1./(1j*w_span*L_eq) + 1j*w_span*C_eq);
Gamma   = (Z_in - Z0) ./ (Z_in + Z0);
S11_dB  = 20*log10(abs(Gamma));

% -10 dB bandwidth
idx_bw  = S11_dB < -10;
if any(idx_bw)
    f_low  = min(f_span(idx_bw));
    f_high = max(f_span(idx_bw));
    BW_MHz = (f_high - f_low)/1e6;
else
    BW_MHz = 0; f_low = f0; f_high = f0;
end

figure('Name','Figure 3 — S11 Parameter','Color','w','Position',[50 50 780 460]);
ax3 = axes; hold(ax3,'on');

% BW shaded region
if BW_MHz > 0
    fill(ax3, [f_low f_high f_high f_low]/1e9, [-10 -10 min(S11_dB) min(S11_dB)], ...
        [0.8 0.95 0.8], 'EdgeColor','none','FaceAlpha',0.4, 'DisplayName','−10 dB BW region');
end

% S11 curve
plot(ax3, f_span/1e9, S11_dB, 'b-', 'LineWidth', 2.5, 'DisplayName', 'S_{11}');

% Reference lines
yline(ax3,-10,'r--','LineWidth',1.8,'Label','−10 dB','LabelHorizontalAlignment','left', ...
    'HandleVisibility','off');
xline(ax3,2.4,'Color',[0.1 0.7 0.1],'LineWidth',1.5,'LineStyle','--', ...
    'Label','2.4 GHz','HandleVisibility','off');
xline(ax3,2.485,'Color',[0.5 0.5 0.5],'LineWidth',1,'LineStyle',':','Label','2.485 GHz','HandleVisibility','off');

% Resonance marker
[S11_min, idx_min] = min(S11_dB);
f_res_actual = f_span(idx_min);
scatter(ax3, f_res_actual/1e9, S11_min, 90, 'r', 'filled', 'DisplayName', ...
    sprintf('Resonance: %.3f GHz, %.1f dB', f_res_actual/1e9, S11_min));

% BW annotation box
if BW_MHz > 0
    text(ax3, 2.35, -35, sprintf('BW_{-10dB}\n≈ %.0f MHz\n(%.1f–%.1f GHz)', ...
        BW_MHz, f_low/1e9, f_high/1e9), 'FontSize',10,'Color',[0 0.5 0], ...
        'BackgroundColor',[0.9 1 0.9],'EdgeColor',[0 0.5 0],'Margin',3);
end

xlabel(ax3,'Frequency (GHz)','FontSize',12);
ylabel(ax3,'S_{11} (dB)','FontSize',12);
title(ax3,'S_{11} vs Frequency — 2.4 GHz Inset-Fed Patch (TLM Model)', ...
    'FontSize',13,'FontWeight','bold');
legend(ax3,'Location','southeast','FontSize',10);
grid(ax3,'on'); ylim(ax3,[-45 5]); xlim(ax3,[1.6 3.4]);
set(ax3,'XTick',1.6:0.2:3.4);

%% ══════════════════════════════════════════════════════════════════════════
%  FIGURE 4 — INPUT IMPEDANCE (R & X) AT 11 FREQUENCY POINTS
%% ══════════════════════════════════════════════════════════════════════════
% 11 points: 1.9 GHz to 2.9 GHz in 0.1 GHz steps (centred on 2.4 GHz)
f_11   = linspace(1.9e9, 2.9e9, 11);
w_11   = 2*pi*f_11;

Z_11   = 1 ./ (1/R_edge + 1./(1j*w_11*L_eq) + 1j*w_11*C_eq);
R_11   = real(Z_11);
X_11   = imag(Z_11);

% Continuous curves for reference
f_cont = linspace(1.6e9, 3.2e9, 1000);
w_cont = 2*pi*f_cont;
Z_cont = 1 ./ (1/R_edge + 1./(1j*w_cont*L_eq) + 1j*w_cont*C_eq);
R_cont = real(Z_cont);
X_cont = imag(Z_cont);

figure('Name','Figure 4 — Input Impedance vs Frequency (11 Points)', ...
       'Color','w','Position',[900 50 820 520]);

% ── Resistance subplot ────────────────────────────────────────────────────
subplot(2,1,1);
hold on;
plot(f_cont/1e9, R_cont, 'b-', 'LineWidth',1.5, 'DisplayName','R_{in} (continuous)');
stem(f_11/1e9, R_11, 'filled', 'Color','b', 'MarkerFaceColor','b', ...
     'MarkerSize',8, 'LineWidth',1.8, 'DisplayName','R_{in} (11 points)');
yline(50,'r--','50 Ω','LineWidth',1.8,'LabelHorizontalAlignment','right');
xline(2.4,'Color',[0.1 0.7 0.1],'LineWidth',1.5,'LineStyle','--','Label','2.4 GHz');

% Label each stem with its value
for k = 1:11
    text(f_11(k)/1e9, R_11(k)+4, sprintf('%.0f',R_11(k)), ...
        'HorizontalAlignment','center','FontSize',7.5,'Color','b');
end

ylabel('Resistance R_{in} (Ω)','FontSize',11);
title('Input Impedance vs Frequency — 11 Discrete Points','FontSize',12,'FontWeight','bold');
legend('Location','northeast','FontSize',9); grid on;
xlim([1.7 3.1]); ylim([0 max(R_cont)*1.15]);
set(gca,'XTick',f_11/1e9,'XTickLabel',arrayfun(@(x) sprintf('%.1f',x), f_11/1e9,'UniformOutput',false));
xtickangle(30);

% ── Reactance subplot ─────────────────────────────────────────────────────
subplot(2,1,2);
hold on;
plot(f_cont/1e9, X_cont, 'r-', 'LineWidth',1.5, 'DisplayName','X_{in} (continuous)');
stem(f_11/1e9, X_11, 'filled', 'Color',[0.8 0 0], 'MarkerFaceColor',[0.8 0 0], ...
     'MarkerSize',8, 'LineWidth',1.8, 'DisplayName','X_{in} (11 points)');
yline(0,'k-','LineWidth',1,'HandleVisibility','off');
xline(2.4,'Color',[0.1 0.7 0.1],'LineWidth',1.5,'LineStyle','--','Label','2.4 GHz');

% Label each stem with its value
for k = 1:11
    offset = 8 * sign(X_11(k)); if abs(X_11(k)) < 5; offset = 10; end
    text(f_11(k)/1e9, X_11(k)+offset, sprintf('%.0f',X_11(k)), ...
        'HorizontalAlignment','center','FontSize',7.5,'Color',[0.8 0 0]);
end

xlabel('Frequency (GHz)','FontSize',11);
ylabel('Reactance X_{in} (Ω)','FontSize',11);
legend('Location','northeast','FontSize',9); grid on;
xlim([1.7 3.1]);
set(gca,'XTick',f_11/1e9,'XTickLabel',arrayfun(@(x) sprintf('%.1f',x), f_11/1e9,'UniformOutput',false));
xtickangle(30);

% Shared annotation: resonance = X_in = 0
[~,idx_res] = min(abs(X_11));
annotation('textbox',[0.62 0.08 0.33 0.10],'String', ...
    sprintf('At resonance (2.4 GHz):\nR_{in} ≈ %.0f Ω,  X_{in} ≈ %.0f Ω', ...
    R_11(idx_res), X_11(idx_res)), ...
    'FitBoxToText','on','BackgroundColor','#FFF8E7','EdgeColor','#E67E22', ...
    'FontSize',10,'FontWeight','bold');

%% ── TABULAR PRINTOUT OF 11-POINT IMPEDANCE DATA ──────────────────────────
fprintf('%-12s %-14s %-14s %-16s\n','Freq (GHz)','R_in (Ω)','X_in (Ω)','|Z_in| (Ω)');
fprintf('%s\n', repmat('-',1,58));
for k = 1:11
    fprintf('  %-10.2f %-14.2f %-14.2f %-14.2f\n', ...
        f_11(k)/1e9, R_11(k), X_11(k), abs(Z_11(k)));
end
fprintf('\n[Done] Figures 1–4 generated.\n');
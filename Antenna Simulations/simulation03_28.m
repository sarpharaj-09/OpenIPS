%% Inset-Fed Microstrip Patch Antenna (Table 1)
clear; clc; close all;

mm = 1e-3;
W  = 28.61*mm;  L  = 37.93*mm;   % Patch width, length
Wg = 57.23*mm;  Lg = 75.85*mm;   % Ground plane width, length
Y0 = 10.69*mm;  g  = 0.21*mm;    % Inset depth, inset gap
Wf = 2.52*mm;                    % Feed line width
h  = 1.6*mm;                     % Substrate height (not in table, FR4 standard assumed)

sub = dielectric('FR4');
sub.Thickness = h;

ant = patchMicrostripInsetfed('Length',L,'Width',W,'Height',h, ...
    'GroundPlaneLength',Lg,'GroundPlaneWidth',Wg, ...
    'NotchLength',Y0,'NotchWidth',g,'StripLineWidth',Wf, ...
    'Substrate',sub,'FeedOffset',[-Lg/2 0]);

freq = linspace(2e9,3e9,101);

figure; impedance(ant,freq);                        % Impedance vs frequency

s   = sparameters(ant,freq);
s11 = 20*log10(abs(squeeze(s.Parameters(1,1,:))));
figure; plot(freq/1e9,s11,'LineWidth',1.5); grid on;
xlabel('Frequency (GHz)'); ylabel('S_{11} (dB)'); title('S_{11} vs Frequency');

[~,idx] = min(s11);                                  % resonance = deepest S11 dip
figure; pattern(ant,freq(idx));                      % 3D pattern at resonance
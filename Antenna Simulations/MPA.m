% =====================================================================
% Inset-Fed Microstrip Patch Antenna - 2.4 GHz
% Dimensions taken from Alaa M. Abdulhussein MPA Calculator
% Substrate: FR4, Er = 4.4, h = 1.6 mm
% =====================================================================
p = patchMicrostripInsetfed;

% ---- Patch dimensions (Length = 28.6828 mm, Width = 38.01 mm) ----
p.Length            = 0.0287;        % 28.6828 mm -> m
p.Width             = 0.0380;        % 38.01 mm   -> m
p.Height            = 0.0016;        % 1.6 mm substrate thickness
p.PatchCenterOffset = [0 0];

% ---- Feed location ----
% FeedOffset is the COORDINATE of the feed point relative to the patch
% center, NOT the inset depth. For a patch fed from the radiating edge
% along -x, the feed line starts at the patch edge, i.e. x = -Length/2.
% (Using -Length here, as in the original script, places the feed a
% full patch-length away from the patch -- off the patch entirely.)
p.FeedOffset        = [-p.Length/2 0];   % = -0.01435 m, i.e. patch edge

% ---- Feed line / inset notch dimensions ----
p.StripLineWidth    = 0.0026;        % feed line width = 2.553 mm -> m
p.NotchLength       = 0.0107;        % inset feed depth (Fi) = 10.7087 mm -> m
p.NotchWidth        = 0.00020;        % inset feed gap (g) = 0.203 mm -> m
                                       % NOTE: double check this against the
                                       % calculator output. 0.203 mm is a
                                       % physically tiny gap (thinner than
                                       % most fab tolerances allow). Many
                                       % online MPA calculators report this
                                       % figure as the *slot width* rather
                                       % than a fabrication-ready notch gap.
                                       % Confirm units before sending to
                                       % fabrication; 0.2-0.5 mm is typical
                                       % for FR4 at 2.4 GHz.

% ---- Ground plane (sized with margin around patch, ~6h border) ----
p.GroundPlaneLength = 0.0480;        % patch length + margin
p.GroundPlaneWidth  = 0.0590;        % patch width  + margin

p.Tilt              = 0;

% ---- Substrate ----
p.Substrate             = dielectric('FR4');
p.Substrate.EpsilonR    = 4.4;
p.Substrate.LossTangent = 0.02;

show(p)               % verify visually before meshing -- feed line should
                       % appear as a thin stub touching the patch edge,
                       % running INTO the inset notch, not floating off it
mesh(p, 'MaxEdgeLength', 0.003);

freq = linspace(2.0e9, 2.8e9, 21);

% --- S11 plot ---
s = sparameters(p, freq);
figure
rfplot(s)
title('S_{11} vs Frequency')

% --- Impedance plot ---
figure
impedance(p, freq)
title('Input Impedance vs Frequency')
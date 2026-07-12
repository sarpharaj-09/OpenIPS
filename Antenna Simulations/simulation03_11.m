%% AI-Based Rapid Design of FR4 Inset-Fed Patch Antenna at 2.4 GHz
clear; clc;

%% --- Step 1: Build the base patchMicrostripInsetfed with YOUR substrate ---
% Substrate must be set on the REGULAR object before AI conversion --
% it becomes read-only once converted to AIAntenna.
p0 = patchMicrostripInsetfed;
p0.Substrate = dielectric('FR4');
p0.Substrate.EpsilonR = 4.4;
p0.Substrate.LossTangent = 0.02;

%% --- Step 2: Create the AI-based antenna at your target frequency ---
fd = 2.4e9;
pAI = design(p0, fd, ForAI=true)

%% --- Step 3: Check the read-only properties (confirms FR4 carried over) ---
showReadOnlyProperties(pAI)

%% --- Step 4: Instant resonant frequency + bandwidth check (sub-second) ---
tic
f_res_AI = resonantFrequency(pAI)
[bw_AI, f_low_AI, f_high_AI, matching_AI] = bandwidth(pAI)
timeAI_single = toc;
fprintf('AI single-point analysis time: %.4f seconds\n', timeAI_single);

%% --- Step 5: Check tunable ranges so we don't set invalid values ---
tRanges = tunableRanges(pAI)

%% --- Step 6: Fast grid search over Length and NotchLength (AI-based) ---
% This is the part that was taking 300-380s/point with full EM before.
% With AI-based analysis this should take well under a second total.

L_range  = linspace(0.0275, 0.0295, 21);   % 21 points, fine resolution
y0_range = linspace(0.0085, 0.0105, 21);    % 21 points

nL = length(L_range); ny0 = length(y0_range);
f_res_grid  = nan(ny0, nL);
S11_grid    = nan(ny0, nL);
matched_grid = false(ny0, nL);

target_Z0 = 50;

tic
for i = 1:nL
    for j = 1:ny0
        try
            pAI.Length = L_range(i);
            pAI.NotchLength = y0_range(j);
            % keep Width, StripLineWidth, NotchWidth at current AI defaults
            % (or set explicitly here if you want them fixed to your TLM values)

            [~,~,~,matchStatus] = bandwidth(pAI);
            matched_grid(j,i) = strcmp(string(matchStatus), "Matched");

            f_res_grid(j,i) = resonantFrequency(pAI);

        catch
            % invalid geometry combination for this AI model's trained range
            continue
        end
    end
end
sweepTimeAI = toc;
fprintf('\nAI-based grid sweep (%d points) completed in %.3f seconds.\n', nL*ny0, sweepTimeAI);

%% --- Step 7: Find best point — resonance closest to 2.4 GHz, must be matched ---
freq_err = abs(f_res_grid - fd);
freq_err(~matched_grid) = NaN;   % discard unmatched geometries entirely

[min_err, lin_idx] = min(freq_err(:));
[best_j, best_i] = ind2sub(size(freq_err), lin_idx);
best_L = L_range(best_i);
best_y0 = y0_range(best_j);

fprintf('\n=== BEST POINT (AI-based) ===\n');
fprintf('Length      = %.4f mm\n', best_L*1e3);
fprintf('NotchLength = %.4f mm\n', best_y0*1e3);
fprintf('Resonant frequency = %.4f GHz\n', f_res_grid(best_j,best_i)/1e9);

%% --- Step 8: Heatmap of the design space (built in under a second of solve time) ---
figure
imagesc(L_range*1e3, y0_range*1e3, f_res_grid/1e9)
set(gca, 'YDir', 'normal')
colorbar
xlabel('Length (mm)')
ylabel('NotchLength y_0 (mm)')
title(sprintf('AI-Based Resonant Frequency Map (%.3f sec for %d points)', sweepTimeAI, nL*ny0))
hold on
plot(best_L*1e3, best_y0*1e3, 'r*', 'MarkerSize', 15, 'LineWidth', 2)

%% --- Step 9: Set the best point and get full bandwidth/matching details ---
pAI.Length = best_L;
pAI.NotchLength = best_y0;
[bw_best, f_low_best, f_high_best, matching_best] = bandwidth(pAI)
f_res_best = resonantFrequency(pAI)

%% --- Step 10: Export to regular antenna and verify with full-wave EM (ONE solve only) ---
pFull = exportAntenna(pAI)

fprintf('\nRunning ONE full-wave EM confirmation (this is the only slow step)...\n');
fSweep = linspace(0.85, 1.15, 61) * fd;   % narrow band around 2.4 GHz

tic
[resFreqFullAll, ~, ~, typeAll] = resonantFrequency(pFull, fSweep);
[bwFull, ~, fLowFull, fHighFull] = bandwidth(pFull, fSweep)
timeFull = toc;
fprintf('Full-wave EM confirmation time: %.2f seconds\n', timeFull);

idxFull = getResonanceCloseToDesign(resFreqFullAll, typeAll, fd, "Series");
resFreqFull = resFreqFullAll(idxFull)

%% --- Step 11: Compare AI prediction vs full EM ground truth ---
fig = figure;
resonantFrequency(pFull, fSweep);
compareResonantFrequencies(fig, idxFull, f_res_best)

fig2 = figure;
bandwidth(pFull, fSweep);
compareBandwidth(fig2, bw_best, f_low_best, f_high_best)

fprintf('\n=== FINAL COMPARISON ===\n');
fprintf('AI-predicted resonance:   %.4f GHz\n', f_res_best/1e9);
fprintf('Full-EM resonance:        %.4f GHz\n', resFreqFull/1e9);
fprintf('Relative error: %.3f%%\n', 100*abs(f_res_best-resFreqFull)/resFreqFull);

%% --- Step 12: Final S11 and impedance plots from the confirmed full-EM object ---
freq_fine = linspace(2.2e9, 2.6e9, 41);
Z = impedance(pFull, freq_fine);
S11 = (Z - target_Z0)./(Z + target_Z0);

figure
subplot(2,1,1)
plot(freq_fine/1e9, 20*log10(abs(S11)), 'b-', 'LineWidth', 1.5)
hold on; yline(-10,'r--'); xline(2.4,'k:');
xlabel('Frequency (GHz)'); ylabel('S_{11} (dB)'); grid on
title('Final Confirmed S_{11} (Full-Wave EM)')

subplot(2,1,2)
plot(freq_fine/1e9, real(Z), 'b-', 'LineWidth', 1.5); hold on
plot(freq_fine/1e9, imag(Z), 'r-', 'LineWidth', 1.5)
yline(50,'b--'); yline(0,'r--'); xline(2.4,'k:');
xlabel('Frequency (GHz)'); ylabel('Impedance (\Omega)')
legend('R','X','Location','best'); grid on
title('Final Confirmed Impedance (Full-Wave EM)')
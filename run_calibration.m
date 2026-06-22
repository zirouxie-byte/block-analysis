function out = run_calibration()
% =========================================================================
% RUN_CALIBRATION
% =========================================================================
% Self-contained calibration tool. Processes TWO images (0002.jpg and
% 0010.jpg) and for each one runs 4 trials of clicking 8 corners
% (4 corners of the LEFT block + 4 corners of the RIGHT block).
%
% Total clicks: 4 trials x 8 clicks x 2 images = 64 clicks.
%
% Side label convention (clockwise from top on each block):
%   Left block:  L1 = top,   L2 = right, L3 = bottom, L4 = left
%   Right block: L5 = top,   L6 = right, L7 = bottom, L8 = left
%
% Output per image: a 1x16 cell named calibration_spring, where cells
% 1..8 hold the L1..L8 PHYSICAL distance arrays (mm) and cells 9..16
% hold the L1..L8 PIXEL arrays (px), each containing 4 numbers (one
% per trial).
%
% USAGE: just type   run_calibration   in the Command Window.
% =========================================================================
    close all;
    % ---------------------------------------------------------------------
    % IMAGES TO PROCESS
    % ---------------------------------------------------------------------
    imagePaths = {
        'Image - Test\0002.jpg';
        % '0010.jpg';
    };
    % ---------------------------------------------------------------------
    % HARD-CODED PHYSICAL DISTANCE MEASUREMENTS (mm)
    % Same physical blocks across both images, so distance is shared.
    % Transcribed from your handwritten table.
    % ---------------------------------------------------------------------
    distanceCommon    = cell(1, 8);
    distanceCommon{1} = [10.91 10.91 10.96 10.87];   % L1 left-top
    distanceCommon{2} = [23.73 23.96 23.81 23.98];   % L2 left-right
    distanceCommon{3} = [10.98 10.92 10.94 10.93];   % L3 left-bottom
    distanceCommon{4} = [23.86 23.88 23.81 23.90];   % L4 left-left
    distanceCommon{5} = [ 7.28  7.32  7.34  7.41];   % L5 right-top
    distanceCommon{6} = [24.14 24.07 24.14 24.09];   % L6 right-right
    distanceCommon{7} = [ 7.37  7.32  7.33  7.22];   % L7 right-bottom
    distanceCommon{8} = [24.06 24.12 24.12 23.98];   % L8 right-left
    % ---------------------------------------------------------------------
    % SHARED CLICK / PROBE / FIT PARAMETERS
    % ---------------------------------------------------------------------
    opts.NumTrials       = 4;
    opts.HalfWidth       = 25;
    opts.NumSamples      = 80;
    opts.MarginFrac      = 0.08;
    opts.MinGradient     = 3;
    opts.RansacDistance  = 1.5;
    opts.SmoothSigma     = 1.0;
    opts.MarkerSize      = 9;
    opts.MeanMarkerSize  = 13;
    opts.LineWidth       = 2;
    opts.EnhanceDisplay  = false;
    opts.SaveOutput      = true;
    % ---------------------------------------------------------------------
    % PROCESS EACH IMAGE
    % ---------------------------------------------------------------------
    allCalibrations = struct([]);
    for imgIdx = 1:numel(imagePaths)
        imgPath = imagePaths{imgIdx};
        fprintf('\n=============================================================\n');
        fprintf(' IMAGE %d of %d: %s\n', imgIdx, numel(imagePaths), imgPath);
        fprintf('=============================================================\n');
        if ~isfile(imgPath)
            warning('Image %s not found, skipping.', imgPath);
            continue;
        end
        results = process_one_image(imgPath, opts);
        % ----- compute the 8 pixel side-lengths per trial -----
        nT = size(results.cornersLeft, 3);
        Lpx = zeros(8, nT);
        for t = 1:nT
            TLl = results.cornersLeft(1, :, t);
            TRl = results.cornersLeft(2, :, t);
            BRl = results.cornersLeft(3, :, t);
            BLl = results.cornersLeft(4, :, t);
            TLr = results.cornersRight(1, :, t);
            TRr = results.cornersRight(2, :, t);
            BRr = results.cornersRight(3, :, t);
            BLr = results.cornersRight(4, :, t);
            Lpx(1, t) = norm(TRl - TLl);   % L1 top
            Lpx(2, t) = norm(BRl - TRl);   % L2 right
            Lpx(3, t) = norm(BLl - BRl);   % L3 bottom
            Lpx(4, t) = norm(TLl - BLl);   % L4 left
            Lpx(5, t) = norm(TRr - TLr);   % L5 top
            Lpx(6, t) = norm(BRr - TRr);   % L6 right
            Lpx(7, t) = norm(BLr - BRr);   % L7 bottom
            Lpx(8, t) = norm(TLr - BLr);   % L8 left
        end
        pixels = cell(1, 8);
        for k = 1:8
            pixels{k} = Lpx(k, :);
        end
        % labels = {'L1 left-top','L2 left-right','L3 left-bottom','L4 left-left', ...
                  % 'L5 right-top','L6 right-right','L7 right-bottom','L8 right-left'};
        % fprintf('\n--- IMAGE %d PIXEL SIDE LENGTHS ---\n', imgIdx);
    %     for k = 1:8
    %         fprintf('  %-18s : %.2f %.2f %.2f %.2f px\n', labels{k}, pixels{k});
    %     end
    %     fprintf('\n--- IMAGE %d mm/px CONSISTENCY CHECK ---\n', imgIdx);
    %     ratios = zeros(1, 8);
    %     for k = 1:8
    %         ratios(k) = mean(distanceCommon{k}) / mean(pixels{k});
    %         fprintf('  %-18s : %.4f mm/px  (mean px=%.2f, mean mm=%.3f)\n', ...
    %                 labels{k}, ratios(k), mean(pixels{k}), mean(distanceCommon{k}));
    %     end
    %     fprintf('  Overall mm/px: min=%.4f, max=%.4f, spread %.2f%%\n', ...
    %             min(ratios), max(ratios), ...
    %             100*(max(ratios)-min(ratios))/mean(ratios));
    %     % Option C: 1x16 cell - distances 1..8 then pixels 1..8
    %     calibration_spring = cell(1, 16);
    %     for k = 1:8
    %         calibration_spring{k}   = distanceCommon{k};
    %         calibration_spring{k+8} = pixels{k};
    %     end
    %     [p, n_, ~] = fileparts(imgPath);
    %     outMat = fullfile(p, sprintf('data_calibration_%s.mat', n_));
    %     save(outMat, 'calibration_spring');
    %     fprintf('Saved %s\n', outMat);
    %     allCalibrations(imgIdx).imgPath            = imgPath;
    %     allCalibrations(imgIdx).calibration_spring = calibration_spring;
    %     allCalibrations(imgIdx).pixels             = pixels;
    %     allCalibrations(imgIdx).distance           = distanceCommon;
    %     allCalibrations(imgIdx).results            = results;
    %     allCalibrations(imgIdx).ratios             = ratios;
    end
    % save('data_calibration_all.mat', 'allCalibrations');
    % fprintf('\nSaved combined output to data_calibration_all.mat\n');
    % fprintf('\nDone. To inspect results in Command Window:\n');
    % fprintf('  allCalibrations(1).pixels    %% image 1 pixel measurements\n');
    % fprintf('  allCalibrations(2).pixels    %% image 2 pixel measurements\n');
    % fprintf('  allCalibrations(1).ratios    %% image 1 mm/px ratios per side\n');

    out.mm = distanceCommon;
    out.px = pixels;

    parameters.pixels    = pixels;
    parameters.distances = distanceCommon;
    parameters.acc_inst  = 0.01;                      % fixed instrument uncertainty [mm];
    parameters.N_samples = 40000;                     % Samples to MCMC
    parameters.N_burnin  = 4000;                      % Burn-in period
    parameters.jump      = [0.05, 0.004, 0.4, 0.4]; %(tune to get ~35-50% acceptance per parameter)

    %% Analysis
    out_MCMC      = pixel_disp_fitting(parameters); % posterior for alpha, beta, e_p and e_d
    out_MCMC_aux  = pixel_disp_fitting(parameters); % posterior for alpha, beta, e_p and e_d
    alpha = out_MCMC(:,1);
    beta  = out_MCMC(:,2);
    e_p   = out_MCMC(:,3);
    e_d   = out_MCMC(:,4);
    
    %% 
    
    pixel_set = 50:50:1500; n = length(pixel_set);
    
    groups = {[1, 2], [3], [4]};
    theta       = out_MCMC;
    theta_aux   = out_MCMC_aux;
    
    R = corrcoef(out_MCMC);
    disp('Posterior Correlation Matrix:');
    disp(R); % Check for correlations before computing Sobol Indices
    
    Sobol_set1 = zeros(3,n);
    Sobol_set2 = zeros(3,n);
    
    for j = 1:n
    
        % The distance for a new pixel is:
        p_new = pixel_set(j);                           % pixels
        % d_new  = alpha + beta .* (p_new + e_p);       % corresponding distance [mm]
        d_new  = alpha + beta .* (p_new + e_p) + e_d;   % corresponding distance [mm]
        
        if pixel_set(j) == 600
            figure
            histogram(d_new,'Normalization','pdf')
            xlabel('Distance [mm]','FontSize',12);
            ylabel('Density','FontSize',12);
            title(['Histogram for a new measurement in pixels - ',num2str(p_new),' px'])
            xlim([14.5 15.5])
        end
    
        %% Sobol indices
    
        % h = @(theta) theta(1) + theta(2).*(p_new + theta(3));
        h = @(theta) theta(1) + theta(2).*(p_new + theta(3)) + theta(4);
        output = d_new;
        [Sobol_set1(:,j), Sobol_set2(:,j)] = sobol_indices_group(theta, theta_aux, h, output, groups);
    
    end
    
    px_names = cell(n,1);
    for j = 1:n; px_names{j} = num2str( pixel_set(j)); end
    
    figure
    bar([Sobol_set1; Sobol_set2]','stacked')
    set(gca, 'XTick', 1:n);
    xticklabels(px_names)
    xlabel('Pixels')
    ylabel('Sobol Index Value')
    legend('$\{\alpha,\beta\}$', '$\sigma_{p}$', '$\sigma_{d}$', '$\{\alpha,\beta\} - \sigma_{p}$', '$\{\alpha,\beta\} - \sigma_{d}$', '$\sigma_{p} - \sigma_{d}$', 'Interpreter', 'latex');
    ylim([0 1])


end
% =========================================================================
% =========================================================================
%                        LOCAL FUNCTIONS
% =========================================================================
% =========================================================================
function results = process_one_image(imgPath, opts)
% Run 4 trials on one image. Each trial: user clicks 4 corners of LEFT
% block, then 4 corners of RIGHT block. Returns struct with refined
% corner coordinates per trial.
    %% Load image
    [I0, map] = imread(imgPath);
    if ~isempty(map), I0 = im2uint8(ind2rgb(I0, map)); end
    if size(I0,3) == 4, I0 = I0(:,:,1:3); end
    if size(I0,3) == 1
        Idisplay = cat(3, I0, I0, I0);
    else
        Idisplay = I0;
    end
    if opts.EnhanceDisplay
        Idisplay = imadjust(Idisplay, stretchlim(Idisplay, [0.01 0.99]), []);
    end
    if size(I0,3) == 3
        I = rgb2gray(I0);
    else
        I = I0;
    end
    Ismooth = imgaussfilt(I, opts.SmoothSigma);
    fprintf('\n=== Processing image: %s ===\n', imgPath);
    %% Run trials
    cornersLeft  = zeros(4, 2, opts.NumTrials);
    cornersRight = zeros(4, 2, opts.NumTrials);
    blockNames = {'LEFT', 'RIGHT'};
    for t = 1:opts.NumTrials
        fprintf('--- Trial %d of %d ---\n', t, opts.NumTrials);
        fig = figure('Name', sprintf('%s | Trial %d/%d', imgPath, t, opts.NumTrials), ...
                     'NumberTitle', 'off', 'Color', 'w');
        imshow(Idisplay, 'InitialMagnification', 'fit');
        set(gca, 'Units', 'normalized', 'Position', [0.02 0.03 0.96 0.88]);
        hold on; ax = gca;
        roughBoth = zeros(4, 2, 2);
        for b = 1:2
            title(ax, sprintf('Trial %d/%d  --  Click 4 corners of %s block', ...
                  t, opts.NumTrials, blockNames{b}), 'FontSize', 14);
            clicks  = clickPoints(4, ax);
            ordered = orderCornersTL_TR_BR_BL(clicks);
            roughBoth(:, :, b) = ordered;
            plot(ax, [ordered(:,1); ordered(1,1)], ...
                     [ordered(:,2); ordered(1,2)], 'r-', 'LineWidth', 1);
        end
        title(ax, sprintf('Trial %d/%d: refining edges ...', t, opts.NumTrials), ...
              'FontSize', 14);
        drawnow;
        cornersLeft(:, :, t)  = refineBlockCorners(Ismooth, roughBoth(:,:,1), opts);
        cornersRight(:, :, t) = refineBlockCorners(Ismooth, roughBoth(:,:,2), opts);
        pause(0.3);
        close(fig);
    end
    %% Build overlay image with all trials and mean corners
    Iout = Idisplay;
    trialColors = {
        [255  60  60]; [ 60 200  60]; [ 60 120 255]; [255 180   0]; ...
        [200  80 255]; [  0 200 200]
    };
    for t = 1:opts.NumTrials
        col = trialColors{ min(t, numel(trialColors)) };
        for blkData = {cornersLeft, cornersRight}
            blk = blkData{1};
            C = blk(:, :, t);
            edges = [C(1,:), C(2,:); C(2,:), C(3,:); ...
                     C(3,:), C(4,:); C(4,:), C(1,:)];
            Iout = insertShape(Iout, 'line', edges, ...
                               'LineWidth', opts.LineWidth, 'Color', col);
            Iout = insertShape(Iout, 'filled-circle', ...
                               [C, opts.MarkerSize*ones(4,1)], ...
                               'Color', col, 'Opacity', 0.85);
        end
    end
    meanLeft  = mean(cornersLeft,  3);
    meanRight = mean(cornersRight, 3);
    meanDots  = [[meanLeft; meanRight], opts.MeanMarkerSize*ones(8,1)];
    Iout = insertShape(Iout, 'filled-circle', meanDots, ...
                       'Color', 'cyan', 'Opacity', 1.0);
    Iout = insertShape(Iout, 'circle', meanDots, ...
                       'Color', 'black', 'LineWidth', 2);
    figR = figure('Name', sprintf('Repeatability: %s', imgPath), ...
                  'NumberTitle', 'off', 'Color', 'w');
    imshow(Iout, 'InitialMagnification', 'fit');
    set(gca, 'Units', 'normalized', 'Position', [0.02 0.03 0.76 0.88]);
    hold on; axR = gca;
    legHandles = gobjects(opts.NumTrials + 1, 1);
    legLabels  = cell(opts.NumTrials + 1, 1);
    for t = 1:opts.NumTrials
        col = trialColors{ min(t, numel(trialColors)) } / 255;
        legHandles(t) = plot(axR, NaN, NaN, 's', ...
                             'MarkerFaceColor', col, ...
                             'MarkerEdgeColor', col, 'MarkerSize', 10);
        legLabels{t} = sprintf('Trial %d', t);
    end
    legHandles(end) = plot(axR, NaN, NaN, 'o', ...
                           'MarkerFaceColor', 'cyan', ...
                           'MarkerEdgeColor', 'k', 'MarkerSize', 12);
    legLabels{end} = 'Mean corner';
    legend(axR, legHandles, legLabels, ...
           'Location', 'northeastoutside', 'FontSize', 10);
    title(axR, sprintf('Repeatability — %s', imgPath), 'FontSize', 13);
    if opts.SaveOutput
        [p, n_, ~] = fileparts(imgPath);
        outPath = fullfile(p, [n_ '_2blocks_repeatability.png']);
        exportgraphics(figR, outPath, 'Resolution', 200);
        fprintf('Saved annotated image to: %s\n', outPath);
    end
    results.cornersLeft  = cornersLeft;
    results.cornersRight = cornersRight;
    results.imgPath      = imgPath;
end
function refined = refineBlockCorners(Ismooth, roughCorners, opts)
    sideEnds = [1 2; 2 3; 3 4; 4 1];
    L = zeros(4, 3);
    for s = 1:4
        p1 = roughCorners(sideEnds(s,1), :);
        p2 = roughCorners(sideEnds(s,2), :);
        edgePts = sampleEdgePoints(Ismooth, p1, p2, opts);
        if size(edgePts, 1) < 4
            L(s,:) = lineFromTwoPoints(p1, p2);
        else
            L(s,:) = robustLineFit(edgePts, opts.RansacDistance);
        end
    end
    cornerSides = [4 1; 1 2; 2 3; 3 4];
    refined = zeros(4, 2);
    for c = 1:4
        refined(c, :) = lineIntersection( ...
            L(cornerSides(c,1), :), L(cornerSides(c,2), :));
    end
end
function pts = clickPoints(N, ax)
    if nargin < 2, ax = gca; end
    pts = zeros(N, 2);
    for i = 1:N
        [x, y] = ginput(1);
        if isempty(x), error('Click cancelled.'); end
        pts(i, :) = [x, y];
        plot(ax, x, y, 'r+', 'MarkerSize', 14, 'LineWidth', 2);
        text(ax, x+8, y, sprintf('%d', i), 'Color', 'r', ...
             'FontSize', 11, 'FontWeight', 'bold');
        drawnow;
    end
end
function ordered = orderCornersTL_TR_BR_BL(pts)
    [~, ySort] = sort(pts(:,2));
    top = pts(ySort(1:2), :);  bot = pts(ySort(3:4), :);
    [~, tIdx] = sort(top(:,1)); [~, bIdx] = sort(bot(:,1));
    ordered = [top(tIdx(1),:); top(tIdx(2),:); bot(bIdx(2),:); bot(bIdx(1),:)];
end
function edgePts = sampleEdgePoints(I, p1, p2, opts)
    [H, W] = size(I);  Id = double(I);
    d = p2 - p1;  Lnorm = norm(d);
    if Lnorm < eps, edgePts = zeros(0,2); return; end
    dHat = d / Lnorm;  nHat = [-dHat(2), dHat(1)];
    ts = linspace(opts.MarginFrac, 1-opts.MarginFrac, opts.NumSamples);
    halfW = opts.HalfWidth;  edgePts = zeros(0, 2);
    for i = 1:numel(ts)
        center = p1 + ts(i) * d;
        ks = -halfW : halfW;
        xs = center(1) + ks * nHat(1);  ys = center(2) + ks * nHat(2);
        valid = xs >= 1 & xs <= W & ys >= 1 & ys <= H;
        if nnz(valid) < 6, continue; end
        intensity = interp2(Id, xs, ys, 'linear', NaN);
        validIdx  = find(valid & ~isnan(intensity));
        if numel(validIdx) < 6, continue; end
        ksValid = ks(validIdx);  intValid = intensity(validIdx);
        grad = abs(diff(intValid));
        if isempty(grad), continue; end
        gradKs = (ksValid(1:end-1) + ksValid(2:end)) / 2;
        [maxGrad, idx] = max(grad);
        if maxGrad < opts.MinGradient, continue; end
        if idx > 1 && idx < numel(grad)
            y0 = grad(idx-1); y1 = grad(idx); y2 = grad(idx+1);
            denom = y0 - 2*y1 + y2;
            if abs(denom) > eps
                delta = 0.5 * (y0 - y2) / denom;
                kEdge = gradKs(idx) + delta * mean(diff(gradKs));
            else
                kEdge = gradKs(idx);
            end
        else
            kEdge = gradKs(idx);
        end
        edgePts(end+1, :) = center + kEdge * nHat; %#ok<AGROW>
    end
end
function l = robustLineFit(pts, maxDistance)
    if size(pts,1) < 2, l = [0 0 0]; return; end
    fitFcn  = @(P) homogLineFromTwoPoints(P);
    distFcn = @(model, P) abs(P*model(1:2)' + model(3));
    inlierIdx = true(size(pts,1), 1);
    try, [~, inlierIdx] = ransac(pts, fitFcn, distFcn, 2, maxDistance); catch, end
    inl = pts(inlierIdx, :);
    if size(inl,1) < 2, inl = pts; end
    mu = mean(inl, 1);  [~, ~, V] = svd(inl - mu, 0);
    n = V(:, 2);  n = n / norm(n);
    l = [n(1), n(2), -n' * mu(:)];
end
function model = homogLineFromTwoPoints(P)
    p1 = [P(1,:) 1]'; p2 = [P(2,:) 1]';
    L  = cross(p1, p2);  nm = norm(L(1:2));
    if nm < eps, nm = 1; end
    model = (L / nm)';
end
function l = lineFromTwoPoints(p1, p2)
    L = cross([p1(:); 1], [p2(:); 1]);
    nm = norm(L(1:2));  if nm < eps, nm = 1; end
    l = (L / nm)';
end
function p = lineIntersection(l1, l2)
    pH = cross(l1(:), l2(:));
    if abs(pH(3)) < 1e-10, p = [NaN NaN];
    else, p = [pH(1)/pH(3), pH(2)/pH(3)]; end
end
function out = load_px2dist_data(imgDir)
    % LOAD_PX2DIST_DATA Returns physical (mm) and pixel measurements of the
    % block sides for use by calibration_px2dist.
    %
    % out.d : 1x8 cell array, each cell holds 4 physical measurements (mm)
    % for sides L1..L8.
    % out.px : 1x8 cell array, each cell holds 4 pixel measurements (px)
    % for sides L1..L8 (extracted from user-clicked corners).
    %
    % Workflow:
    % - User clicks 4 corners of LEFT block, then 4 corners of RIGHT block.
    % - Repeat 4 times (= 4 trials, 32 clicks total).
    % - Function returns mm and px data without saving anything to disk.
    % ---------------------------------------------------------------------
    % IMAGE TO PROCESS
    % ---------------------------------------------------------------------
    imgPath = [imgDir,'reference.jpg'];
    % ---------------------------------------------------------------------
    % HARD-CODED PHYSICAL DISTANCE MEASUREMENTS (mm)
    % L1..L4 = left block (top, right, bottom, left)
    % L5..L8 = right block (top, right, bottom, left)
    % ---------------------------------------------------------------------
    distanceCommon = cell(1, 8);
    distanceCommon{1} = [10.91 10.91 10.96 10.87]; % L1 left-top
    distanceCommon{2} = [23.73 23.96 23.81 23.98]; % L2 left-right
    distanceCommon{3} = [10.98 10.92 10.94 10.93]; % L3 left-bottom
    distanceCommon{4} = [23.86 23.88 23.81 23.90]; % L4 left-left
    distanceCommon{5} = [ 7.28 7.32 7.34 7.41]; % L5 right-top
    distanceCommon{6} = [24.14 24.07 24.14 24.09]; % L6 right-right
    distanceCommon{7} = [ 7.37 7.32 7.33 7.22]; % L7 right-bottom
    distanceCommon{8} = [24.06 24.12 24.12 23.98]; % L8 right-left
    % ---------------------------------------------------------------------
    % CLICK / PROBE / FIT PARAMETERS
    % ---------------------------------------------------------------------
    opts.NumTrials = 4;
    opts.HalfWidth = 25;
    opts.NumSamples = 80;
    opts.MarginFrac = 0.08;
    opts.MinGradient = 3;
    opts.RansacDistance = 1.5;
    opts.SmoothSigma = 1.0;
    opts.EnhanceDisplay = false;
    % ---------------------------------------------------------------------
    % PROCESS THE IMAGE
    % ---------------------------------------------------------------------
    if ~isfile(imgPath)
        error('Image file not found: %s', imgPath);
    end
    fprintf('\n=== Processing image: %s ===\n', imgPath);
    results = process_one_image(imgPath, opts);
    % Compute the 8 pixel side-lengths per trial
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
        Lpx(1, t) = norm(TRl - TLl); % L1 top of left
        Lpx(2, t) = norm(BRl - TRl); % L2 right of left
        Lpx(3, t) = norm(BLl - BRl); % L3 bottom of left
        Lpx(4, t) = norm(TLl - BLl); % L4 left of left
        Lpx(5, t) = norm(TRr - TLr); % L5 top of right
        Lpx(6, t) = norm(BRr - TRr); % L6 right of right
        Lpx(7, t) = norm(BLr - BRr); % L7 bottom of right
        Lpx(8, t) = norm(TLr - BLr); % L8 left of right
    end
    pixels = cell(1, 8);
    for k = 1:8
        pixels{k} = Lpx(k, :);
    end
    % ---------------------------------------------------------------------
    % OUTPUTS
    % ---------------------------------------------------------------------
    out.d = distanceCommon;
    out.px = pixels;
end

% =========================================================================
% =========================================================================
% LOCAL FUNCTIONS
% =========================================================================
% =========================================================================

function results = process_one_image(imgPath, opts)
% Run NumTrials trials on the image. Each trial: user clicks 4 corners of
% LEFT block, then 4 corners of RIGHT block. Returns refined corners.
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
 %% Run trials
 cornersLeft = zeros(4, 2, opts.NumTrials);
 cornersRight = zeros(4, 2, opts.NumTrials);
 blockNames = {'LEFT', 'RIGHT'};
 for t = 1:opts.NumTrials
 fprintf('--- Trial %d of %d ---\n', t, opts.NumTrials);
 % Open the figure DOCKED inside the MATLAB workspace. In MATLAB
 % Online this is the only way to make the figure fully fill the
 % available work area; setting Position or WindowState 'maximized'
 % is ignored by the browser host. Docking the figure causes it to
 % expand to occupy the entire central work area of the IDE.
 fig = figure('Name', sprintf('%s | Trial %d/%d', imgPath, t, opts.NumTrials), ...
 'NumberTitle', 'off', 'Color', 'w', ...
 'WindowStyle', 'docked');
 drawnow;
 imshow(Idisplay, 'InitialMagnification', 'fit');
 set(gca, 'Units', 'normalized', 'Position', [0.02 0.03 0.96 0.88]);
 hold on; ax = gca;
 roughBoth = zeros(4, 2, 2);
 for b = 1:2
 title(ax, sprintf('Trial %d/%d -- Click 4 corners of %s block', ...
 t, opts.NumTrials, blockNames{b}), 'FontSize', 14);
 clicks = clickPoints(4, ax);
 ordered = orderCornersTL_TR_BR_BL(clicks);
 roughBoth(:, :, b) = ordered;
 plot(ax, [ordered(:,1); ordered(1,1)], ...
 [ordered(:,2); ordered(1,2)], 'r-', 'LineWidth', 1);
 end
 title(ax, sprintf('Trial %d/%d: refining edges ...', t, opts.NumTrials), ...
 'FontSize', 14);
 drawnow;
 cornersLeft(:, :, t) = refineBlockCorners(Ismooth, roughBoth(:,:,1), opts);
 cornersRight(:, :, t) = refineBlockCorners(Ismooth, roughBoth(:,:,2), opts);
 pause(0.3);
 close(fig);
 end
 results.cornersLeft = cornersLeft;
 results.cornersRight = cornersRight;
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
 top = pts(ySort(1:2), :); bot = pts(ySort(3:4), :);
 [~, tIdx] = sort(top(:,1)); [~, bIdx] = sort(bot(:,1));
 ordered = [top(tIdx(1),:); top(tIdx(2),:); bot(bIdx(2),:); bot(bIdx(1),:)];
end
function edgePts = sampleEdgePoints(I, p1, p2, opts)
 [H, W] = size(I); Id = double(I);
 d = p2 - p1; Lnorm = norm(d);
 if Lnorm < eps, edgePts = zeros(0,2); return; end
 dHat = d / Lnorm; nHat = [-dHat(2), dHat(1)];
 ts = linspace(opts.MarginFrac, 1-opts.MarginFrac, opts.NumSamples);
 halfW = opts.HalfWidth; edgePts = zeros(0, 2);
 for i = 1:numel(ts)
 center = p1 + ts(i) * d;
 ks = -halfW : halfW;
 xs = center(1) + ks * nHat(1); ys = center(2) + ks * nHat(2);
 valid = xs >= 1 & xs <= W & ys >= 1 & ys <= H;
 if nnz(valid) < 6, continue; end
 intensity = interp2(Id, xs, ys, 'linear', NaN);
 validIdx = find(valid & ~isnan(intensity));
 if numel(validIdx) < 6, continue; end
 ksValid = ks(validIdx); intValid = intensity(validIdx);
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
 fitFcn = @(P) homogLineFromTwoPoints(P);
 distFcn = @(model, P) abs(P*model(1:2)' + model(3));
 inlierIdx = true(size(pts,1), 1);
 try, [~, inlierIdx] = ransac(pts, fitFcn, distFcn, 2, maxDistance); catch, end
 inl = pts(inlierIdx, :);
 if size(inl,1) < 2, inl = pts; end
 mu = mean(inl, 1); [~, ~, V] = svd(inl - mu, 0);
 n = V(:, 2); n = n / norm(n);
 l = [n(1), n(2), -n' * mu(:)];
end
function model = homogLineFromTwoPoints(P)
 p1 = [P(1,:) 1]'; p2 = [P(2,:) 1]';
 L = cross(p1, p2); nm = norm(L(1:2));
 if nm < eps, nm = 1; end
 model = (L / nm)';
end
function l = lineFromTwoPoints(p1, p2)
 L = cross([p1(:); 1], [p2(:); 1]);
 nm = norm(L(1:2)); if nm < eps, nm = 1; end
 l = (L / nm)';
end
function p = lineIntersection(l1, l2)
 pH = cross(l1(:), l2(:));
 if abs(pH(3)) < 1e-10, p = [NaN NaN];
 else, p = [pH(1)/pH(3), pH(2)/pH(3)]; end
end
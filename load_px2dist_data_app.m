function out = load_px2dist_data_app(imgDir, parentFig)
% LOAD_PX2DIST_DATA_APP  App-friendly variant of load_px2dist_data.
%
%   Same algorithm (4 trials × 8 corner clicks, perpendicular-probe edge
%   refinement, RANSAC line fit, sub-pixel corner intersection) but the
%   click window is a modal uifigure dialog instead of a free-standing
%   figure(). Designed to be called from BlockAnalysisApp.m.
%
%   INPUTS:
%       imgDir   - path to image folder (will look for 0002.jpg by default)
%       parentFig - uifigure handle for modal dialog parenting (optional)
%
%   OUTPUT:
%       out.d  : 1x8 cell, each with 4 mm measurements (hardcoded lab data)
%       out.px : 1x8 cell, each with 4 pixel measurements from clicks

    if nargin < 2, parentFig = []; end

    % ---------------------------------------------------------------------
    % Find an image to use
    % ---------------------------------------------------------------------
    imgPath = '';
    if ~isempty(imgDir)
        candidates = {'0002.jpg', '0010.jpg', 'reference.jpg'};
        for c = 1:numel(candidates)
            p = fullfile(imgDir, candidates{c});
            if isfile(p), imgPath = p; break; end
        end
        % If none found, pick the first jpg/png in folder
        if isempty(imgPath)
            d = dir(fullfile(imgDir, '*.jpg'));
            if isempty(d), d = dir(fullfile(imgDir, '*.png')); end
            if ~isempty(d), imgPath = fullfile(imgDir, d(1).name); end
        end
    end
    if isempty(imgPath) || ~isfile(imgPath)
        error('No image found. Provide a folder containing 0002.jpg or any image.');
    end

    % ---------------------------------------------------------------------
    % Hard-coded physical mm measurements (per your lab table)
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

    opts.NumTrials      = 4;
    opts.HalfWidth      = 25;
    opts.NumSamples     = 80;
    opts.MarginFrac     = 0.08;
    opts.MinGradient    = 3;
    opts.RansacDistance = 1.5;
    opts.SmoothSigma    = 1.0;

    % Load image
    [I0, map] = imread(imgPath);
    if ~isempty(map), I0 = im2uint8(ind2rgb(I0, map)); end
    if size(I0,3) == 4, I0 = I0(:,:,1:3); end
    if size(I0,3) == 1, Idisp = cat(3, I0, I0, I0); else, Idisp = I0; end
    if size(I0,3) == 3, Igray = rgb2gray(I0); else, Igray = I0; end
    Ismooth = imgaussfilt(Igray, opts.SmoothSigma);

    cornersLeft  = zeros(4, 2, opts.NumTrials);
    cornersRight = zeros(4, 2, opts.NumTrials);

    for t = 1:opts.NumTrials
        % Collect all 8 corners (4 LEFT then 4 RIGHT) in a SINGLE window so
        % the image doesn't flash/reload between the two blocks.
        [clicksL, clicksR] = collectBothBlocksInModal(Idisp, t, parentFig);
        if size(clicksL,1) < 4 || size(clicksR,1) < 4
            error('Cancelled by user.');
        end
        orderedL = orderCornersTLTRBRBL(clicksL);
        orderedR = orderCornersTLTRBRBL(clicksR);
        cornersLeft(:,:,t)  = refineBlockCorners(Ismooth, orderedL, opts);
        cornersRight(:,:,t) = refineBlockCorners(Ismooth, orderedR, opts);
    end

    % Compute the 8 pixel side-lengths per trial
    Lpx = zeros(8, opts.NumTrials);
    for t = 1:opts.NumTrials
        Lpx(1,t) = norm(cornersLeft(2,:,t) - cornersLeft(1,:,t));
        Lpx(2,t) = norm(cornersLeft(3,:,t) - cornersLeft(2,:,t));
        Lpx(3,t) = norm(cornersLeft(4,:,t) - cornersLeft(3,:,t));
        Lpx(4,t) = norm(cornersLeft(1,:,t) - cornersLeft(4,:,t));
        Lpx(5,t) = norm(cornersRight(2,:,t) - cornersRight(1,:,t));
        Lpx(6,t) = norm(cornersRight(3,:,t) - cornersRight(2,:,t));
        Lpx(7,t) = norm(cornersRight(4,:,t) - cornersRight(3,:,t));
        Lpx(8,t) = norm(cornersRight(1,:,t) - cornersRight(4,:,t));
    end
    pixels = cell(1, 8);
    for k = 1:8, pixels{k} = Lpx(k, :); end

    out.d  = distanceCommon;
    out.px = pixels;
end


% =========================================================================
% Modal click collector — collects 4 LEFT corners then 4 RIGHT corners in a
% SINGLE window (the image is loaded once and never flashes between blocks).
% Returns clicksL (4x2) and clicksR (4x2).
% =========================================================================
function [clicksL, clicksR] = collectBothBlocksInModal(I, trialNum, parentFig) %#ok<INUSD>
    [H, W, ~] = size(I);
    clicks   = zeros(0, 2);   % clicks for the current block
    clicksL  = zeros(0, 2);
    clicksR  = zeros(0, 2);
    phase    = 1;             % 1 = LEFT block, 2 = RIGHT block
    finished = false;
    cancelled = false;

    aspect = W / H;
    winW = min(1100, max(700, round(720 * aspect)));
    winH = min(820,  round(winW / aspect) + 150);

    modal = uifigure('Name', sprintf('Click corners — Trial %d', trialNum), ...
        'Position', [80 80 winW winH], 'WindowStyle', 'modal');
    movegui(modal, 'center');

    g = uigridlayout(modal, [3, 1]);
    g.RowHeight = {'fit', '1x', 'fit'};
    g.Padding = [12 12 12 12];

    titleLbl = uilabel(g, 'Text', sprintf( ...
        'Trial %d / 4  —  Click the 4 corners of the LEFT block (any order)', trialNum), ...
        'FontSize', 15, 'FontWeight','bold');
    titleLbl.Layout.Row = 1;

    ax = uiaxes(g);
    ax.Layout.Row = 2;
    imgObj = image(ax, I);          % drawn ONCE for the whole trial
    ax.YDir = 'reverse';
    ax.DataAspectRatio = [1 1 1];
    ax.XLim = [0.5 W+0.5];
    ax.YLim = [0.5 H+0.5];
    ax.XTick = []; ax.YTick = [];
    ax.Box = 'on';
    ax.Toolbar.Visible = 'off';
    disableDefaultInteractivity(ax);

    imgObj.ButtonDownFcn = @(src,evt) doClick(evt);
    ax.ButtonDownFcn     = @(src,evt) doClick(evt);

    ctrlPanel = uipanel(g, 'BorderType','none');
    ctrlPanel.Layout.Row = 3;
    cg = uigridlayout(ctrlPanel, [1, 3]);
    cg.ColumnWidth = {'1x','fit','fit'};
    cg.Padding = [0 6 0 0];
    statusLbl = uilabel(cg, 'Text','LEFT block — 0 / 4 clicks', 'FontSize', 13);
    btnUndo  = uibutton(cg, 'Text','Undo');
    btnDone  = uibutton(cg, 'Text','Cancel', 'FontColor', [0.64 0.18 0.18]);
    btnUndo.ButtonPushedFcn = @(~,~) doUndo();
    btnDone.ButtonPushedFcn = @(~,~) doCancel();
    modal.CloseRequestFcn = @(~,~) doCancel();

    uiwait(modal);
    if isvalid(modal), delete(modal); end
    if cancelled
        clicksL = zeros(0,2); clicksR = zeros(0,2);
    end

    % ---- nested funcs ----
    function doClick(evt)
        if finished, return; end
        try
            p = evt.IntersectionPoint(1:2);
        catch
            cp = ax.CurrentPoint; p = cp(1, 1:2);
        end
        if p(1) < 0.5 || p(1) > W+0.5 || p(2) < 0.5 || p(2) > H+0.5
            return;
        end
        clicks(end+1, :) = p; %#ok<AGROW>
        redrawMarkers();
        if size(clicks,1) >= 4
            if phase == 1
                % store LEFT, switch to RIGHT — WITHOUT reloading the image
                clicksL = clicks;
                clicks  = zeros(0, 2);
                phase   = 2;
                titleLbl.Text = sprintf( ...
                    'Trial %d / 4  —  Now click the 4 corners of the RIGHT block', trialNum);
                % recolor the left markers so the user can see they're locked
                lockLeftMarkers();
                statusLbl.Text = 'RIGHT block — 0 / 4 clicks';
                drawnow;
            else
                clicksR = clicks;
                finished = true;
                statusLbl.Text = 'Got all 8 corners — processing...';
                drawnow;
                uiresume(modal);
            end
        end
    end

    function doUndo()
        if size(clicks,1) == 0
            % allow undo back into the LEFT phase
            if phase == 2 && size(clicksL,1) == 4
                phase = 1;
                clicks = clicksL;
                clicksL = zeros(0,2);
                delete(findobj(ax,'Tag','lockMarker'));
                titleLbl.Text = sprintf( ...
                    'Trial %d / 4  —  Click the 4 corners of the LEFT block (any order)', trialNum);
                redrawMarkers();
            end
            return;
        end
        clicks(end,:) = [];
        redrawMarkers();
    end

    function doCancel()
        cancelled = true;
        finished = true;
        uiresume(modal);
    end

    function redrawMarkers()
        delete(findobj(ax,'Tag','clickMarker'));
        hold(ax, 'on');
        markerColor = [1.00 0.30 0.65];   % bright pink (visible on most images)
        for i = 1:size(clicks,1)
            p = clicks(i,:);
            plot(ax, p(1), p(2), '+', 'Color', markerColor, ...
                'MarkerSize', 18, 'LineWidth', 3, ...
                'Tag', 'clickMarker', 'PickableParts','none', 'HitTest','off');
            text(ax, p(1)+12, p(2), num2str(i), ...
                'Color', markerColor, 'FontWeight','bold', 'FontSize', 14, ...
                'Tag', 'clickMarker', 'PickableParts','none', 'HitTest','off');
        end
        hold(ax, 'off');
        if phase == 1
            statusLbl.Text = sprintf('LEFT block — %d / 4 clicks', size(clicks,1));
        else
            statusLbl.Text = sprintf('RIGHT block — %d / 4 clicks', size(clicks,1));
        end
        drawnow;
    end

    function lockLeftMarkers()
        % Turn the active pink markers into locked purple ones so the user
        % can see which corners are already committed for the LEFT block.
        delete(findobj(ax,'Tag','clickMarker'));
        hold(ax, 'on');
        lockColor = [0.55 0.18 0.65];   % deep purple
        for i = 1:size(clicksL,1)
            p = clicksL(i,:);
            plot(ax, p(1), p(2), '+', 'Color', lockColor, ...
                'MarkerSize', 16, 'LineWidth', 3, ...
                'Tag', 'lockMarker', 'PickableParts','none', 'HitTest','off');
        end
        hold(ax, 'off');
    end
end


% =========================================================================
% Helpers (same algorithm as your existing code)
% =========================================================================
function out = ternary(cond, a, b)
    if cond, out = a; else, out = b; end
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

function ordered = orderCornersTLTRBRBL(pts)
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

function app = BlockAnalysisApp
% BLOCKANALYSISAPP  Modern GUI for the block / hydrogel measurement pipeline.
%
%   Usage:
%       BlockAnalysisApp
%       app = BlockAnalysisApp;
%
%   Requires the following .m files to be on the MATLAB path:
%       load_spring_data.m, calibration_spring.m,
%       load_px2dist_data_app.m, calibration_px2dist.m,
%       ROI_selection.m, DIC_distance_calculation.m,
%       unit_coversion.m, MLE.m, H.m, J_error_MLE.m,
%       pixel_disp_fitting.m, disp_foce_fitting.m
%
%   This app DOES NOT reimplement any math. It wraps a polished UI around
%   your existing functions and stores intermediate results in the app's
%   state struct. Auto-saves the session to BlockAnalysisApp_session.mat
%   so you can close the app and resume later.

    % ---------------------------------------------------------------------
    % Global state container shared across callbacks
    % ---------------------------------------------------------------------
    S = struct();
    S.session_file = 'BlockAnalysisApp_session.mat';
    S.spring_data        = [];
    S.spring_calibration = [];
    S.dist2px_data       = [];
    S.dist2px_calibration= [];
    S.pattern            = [];
    S.distance           = [];
    S.data               = [];     % unit-converted spring/gel data
    S.fit_results        = [];     % MLE output
    S.imgDir             = '';
    S.spring_id          = 1;
    S.hydrogel.width     = 24.0;
    S.hydrogel.thickness = 5.38;
    S.hydrogel.length    = 7.304;
    S.image_paths        = {};     % uploaded image paths
    S.calImagePath       = '';     % direct path to the Step 2 calibration image
    S.refImagePath       = '';     % reference image for ROI selection
    S.dicDir             = '';     % folder of "after" images for DIC
    S.dicSeriesPaths     = {};     % uploaded after-series files
    % ---------------------------------------------------------------------
    % Color tokens — sunset (pink → purple) palette
    % ---------------------------------------------------------------------
    CLR.bg          = [0.985 0.965 0.975];     % blush cream background
    CLR.surface     = [1.000 1.000 1.000];     % cards / surfaces
    CLR.surface2    = [0.975 0.940 0.960];     % subtle alt-surface
    CLR.border      = [0.88 0.82 0.86];        % dusty rose border
    CLR.text        = [0.16 0.10 0.18];        % deep aubergine for body text
    CLR.text2       = [0.40 0.30 0.42];        % muted mauve
    CLR.text3       = [0.60 0.50 0.62];        % soft lilac-gray
    CLR.accent      = [0.745 0.310 0.580];     % rose-magenta primary
    CLR.accentDark  = [0.498 0.196 0.435];     % plum on hover
    CLR.info        = [0.522 0.318 0.620];     % twilight purple
    CLR.warn        = [0.847 0.490 0.388];     % coral-amber
    CLR.danger      = [0.694 0.231 0.243];     % crimson
    CLR.pillBg      = [0.988 0.918 0.945];     % petal pink
    CLR.pillFg      = [0.435 0.169 0.388];     % deep magenta on petal
    CLR.success     = [0.643 0.255 0.510];     % berry (replaces green)
    CLR.successBg   = [0.973 0.902 0.937];     % blush success card

    % Typography — prefer a serif family that reads like Times New Roman
    FNT.serif       = 'Times New Roman';
    FNT.serifAlt    = 'Georgia';

    % ---------------------------------------------------------------------
    % Main window
    % ---------------------------------------------------------------------
    screenSize = get(0, 'ScreenSize');
    figW = min(1280, screenSize(3) - 80);
    figH = min(820,  screenSize(4) - 120);

    fig = uifigure('Name', 'Block Analysis — Hydrogel Stiffness Pipeline', ...
                   'Position', [40, 60, figW, figH], ...
                   'Color', CLR.bg, ...
                   'Resize', 'on', ...
                   'AutoResizeChildren', 'on');
    fig.UserData = S;

    % Main grid: header / sidebar / content / footer
    g = uigridlayout(fig, [2, 1]);
    g.RowHeight   = {64, '1x'};
    g.ColumnWidth = {'1x'};
    g.Padding     = [0 0 0 0];
    g.RowSpacing  = 0;

    % Header bar
    header = uipanel(g, 'BackgroundColor', CLR.surface, ...
                        'BorderType', 'none');
    header.Layout.Row = 1;
    headerG = uigridlayout(header, [1, 3]);
    headerG.ColumnWidth = {'fit', '1x', 'fit'};
    headerG.Padding     = [24 12 24 12];
    headerG.ColumnSpacing = 16;

    % Brand
    brandPanel = uipanel(headerG, 'BorderType','none', 'BackgroundColor', CLR.surface);
    brandPanel.Layout.Column = 1;
    bg = uigridlayout(brandPanel, [1, 2]);
    bg.ColumnWidth = {40, 'fit'};
    bg.Padding = [0 0 0 0];
    bg.ColumnSpacing = 12;
    brandMark = uilabel(bg, 'Text','B', ...
        'FontWeight','bold', 'FontSize', 18, 'FontColor', [1 1 1], ...
        'BackgroundColor', CLR.accent, ...
        'HorizontalAlignment','center', 'VerticalAlignment','center');
    brandMark.Layout.Column = 1;
    brandText = uilabel(bg, 'Text','Block Analysis', ...
        'FontSize', 16, 'FontWeight','bold', 'FontColor', CLR.text);
    brandText.Layout.Column = 2;

    % Center column reserved for spacing (subtitle removed per user request)
    sub = uilabel(headerG, 'Text','', ...
        'HorizontalAlignment','center');
    sub.Layout.Column = 2;

    % Header controls (Export results sits in step 6; here we just keep a Reset)
    sessPanel = uipanel(headerG, 'BorderType','none', 'BackgroundColor', CLR.surface);
    sessPanel.Layout.Column = 3;
    sg = uigridlayout(sessPanel, [1, 1]);
    sg.ColumnWidth = {'fit'};
    sg.Padding = [0 0 0 0];
    btnReset = uibutton(sg, 'Text','Start over', 'FontSize', 12, ...
        'FontColor', CLR.danger);
    btnReset.ButtonPushedFcn = @(~,~) resetSession();

    % Body: sidebar + content
    body = uigridlayout(g, [1, 2]);
    body.Layout.Row     = 2;
    body.ColumnWidth    = {240, '1x'};
    body.Padding        = [0 0 0 0];
    body.ColumnSpacing  = 0;

    sidebar = uipanel(body, 'BackgroundColor', CLR.surface2, 'BorderType','line');
    sidebar.Layout.Column = 1;
    % 7 buttons (Instructions then Steps 1-6) plus a flexible spacer at the bottom
    sideG = uigridlayout(sidebar, [8, 1]);
    sideG.RowHeight = {56, 56, 56, 56, 56, 56, 56, '1x'};
    sideG.Padding   = [12 18 12 18];
    sideG.RowSpacing= 6;

    % Instructions tab sits above the pipeline steps as "Step 0".
    gettingStartedBtn = makeSidebarStep(sideG, '0', 'Instructions', CLR);
    gettingStartedBtn.Layout.Row = 1;
    gettingStartedBtn.ButtonPushedFcn = @(b,e) switchTo(7);

    stepBtns = gobjects(6, 1);
    stepNames = {'Spring calibration', 'Pixel calibration', ...
                 'ROI selection', 'DIC tracking', ...
                 'Unit conversion', 'MLE fit & result'};
    stepIcons = {'1','2','3','4','5','6'};
    for i = 1:6
        btn = makeSidebarStep(sideG, stepIcons{i}, stepNames{i}, CLR);
        btn.Layout.Row = i + 1;
        btn.ButtonPushedFcn = @(b,e) switchTo(i);
        stepBtns(i) = btn;
    end

    % Content area
    contentWrap = uipanel(body, 'BackgroundColor', CLR.bg, 'BorderType','none');
    contentWrap.Layout.Column = 2;
    contentG = uigridlayout(contentWrap, [1, 1]);
    contentG.Padding = [32 24 32 24];

    % Seven panels: 1-6 for pipeline steps, 7 for the Getting Started page.
    stepPanels = gobjects(7, 1);
    for i = 1:7
        p = uipanel(contentG, 'BorderType','none', 'BackgroundColor', CLR.bg, ...
                              'Visible','off');
        p.Layout.Row = 1; p.Layout.Column = 1;
        stepPanels(i) = p;
    end

    % ---------------------------------------------------------------------
    % Build each step
    % ---------------------------------------------------------------------
    handles = struct();
    handles.step1 = buildStep1_SpringCalibration(stepPanels(1), CLR);
    handles.step2 = buildStep2_PixelCalibration(stepPanels(2), CLR);
    handles.step3 = buildStep3_ROISelection(stepPanels(3), CLR);
    handles.step4 = buildStep4_DICTracking(stepPanels(4), CLR);
    handles.step5 = buildStep5_UnitConversion(stepPanels(5), CLR);
    handles.step6 = buildStep6_MLEFit(stepPanels(6), CLR);
    handles.step0 = buildStep0_GettingStarted(stepPanels(7), CLR);


    % Apply serif font family to every text-bearing component in the figure
    applySerifFontRecursive(fig, FNT.serif);

    % Always start fresh: delete any stale session file from a previous run
    % so the user gets a clean slate every time they launch the app.
    if isfile(S.session_file)
        try, delete(S.session_file); catch, end
    end

    % When the user closes the app, also delete the session file so the
    % next launch is truly fresh.
    fig.CloseRequestFcn = @(src,~) onAppClose(src);

    switchTo(7);   % Open on the Getting Started page
    if nargout < 1, clear app; end


    % =====================================================================
    % NESTED CALLBACKS
    % =====================================================================
    function switchTo(idx)
        for k = 1:7
            stepPanels(k).Visible = 'off';
        end
        for k = 1:6
            tagBtn(stepBtns(k), false, CLR);
        end
        tagBtn(gettingStartedBtn, false, CLR);
        stepPanels(idx).Visible = 'on';
        if idx >= 1 && idx <= 6
            tagBtn(stepBtns(idx), true, CLR);
        elseif idx == 7
            % Mark Instructions as "viewed" with a checkmark, then highlight it
            updateSidebarDone(gettingStartedBtn, CLR);
            tagBtn(gettingStartedBtn, true, CLR);
        end
    end

    function S = getState
        S = fig.UserData;
    end

    function setState(S)
        fig.UserData = S;
    end

    function onAppClose(src)
        % Wipe the session file so the next launch is fresh
        try
            sf = src.UserData.session_file;
            if isfile(sf), delete(sf); end
        catch
        end
        delete(src);
    end

    function saveSession()
        try
            S = fig.UserData; %#ok<NASGU>
            save(S.session_file, 'S');
            uialert(fig, sprintf('Session saved to %s', S.session_file), ...
                    'Saved', 'Icon','success');
        catch ME
            uialert(fig, sprintf('Save failed: %s', ME.message), 'Error');
        end
    end

    function loadSession()
        try
            if ~isfile(S.session_file)
                uialert(fig, 'No saved session found.', 'Info');
                return;
            end
            d = load(S.session_file);
            fig.UserData = d.S;
            refreshAllSteps();
            uialert(fig, 'Session loaded.', 'Loaded', 'Icon','success');
        catch ME
            uialert(fig, sprintf('Load failed: %s', ME.message), 'Error');
        end
    end

    function resetSession()
        sel = uiconfirm(fig, ...
            'This will clear all progress and reset every step. Continue?', ...
            'Start over', 'Options', {'Start over','Cancel'}, ...
            'DefaultOption', 'Cancel', 'Icon','warning');
        if ~strcmp(sel, 'Start over'), return; end

        % 1) Close any stray diagnostic figures (non-app, non-uifigure)
        try
            strayFigs = findall(0, 'Type', 'figure');
            for k = 1:numel(strayFigs)
                f = strayFigs(k);
                if f == fig, continue; end
                isUif = false;
                try, isUif = matlab.ui.internal.isUIFigure(f); catch, end
                if ~isUif
                    try, delete(f); catch, end
                end
            end
        catch
        end

        % 2) Reset the state struct to fresh defaults
        S2 = struct();
        S2.session_file        = 'BlockAnalysisApp_session.mat';
        S2.spring_data         = [];
        S2.spring_calibration  = [];
        S2.dist2px_data        = [];
        S2.dist2px_calibration = [];
        S2.pattern             = [];
        S2.distance            = [];
        S2.data                = [];
        S2.fit_results         = [];
        S2.imgDir              = '';
        S2.spring_id           = 1;
        S2.hydrogel.width      = 24.0;
        S2.hydrogel.thickness  = 5.38;
        S2.hydrogel.length     = 7.304;
        S2.image_paths         = {};
        S2.calImagePath        = '';
        S2.refImagePath        = '';
        S2.refImageData        = [];
        S2.dicDir              = '';
        S2.dicSeriesPaths      = {};
        fig.UserData = S2;

        % 3) Delete & rebuild each step panel's contents so all inputs,
        %    tables, plots, and status labels go back to their initial state.
        for k = 1:6
            delete(stepPanels(k).Children);
        end
        handles.step1 = buildStep1_SpringCalibration(stepPanels(1), CLR);
        handles.step2 = buildStep2_PixelCalibration(stepPanels(2), CLR);
        handles.step3 = buildStep3_ROISelection(stepPanels(3), CLR);
        handles.step4 = buildStep4_DICTracking(stepPanels(4), CLR);
        handles.step5 = buildStep5_UnitConversion(stepPanels(5), CLR);
        handles.step6 = buildStep6_MLEFit(stepPanels(6), CLR);

        % 4) Clear sidebar checkmarks (both pipeline steps and Instructions)
        for k = 1:6
            stepBtns(k).Text = sprintf('  %s   %s', stepIcons{k}, stepNames{k});
            stepBtns(k).FontColor = CLR.text2;
            stepBtns(k).FontWeight = 'normal';
        end
        gettingStartedBtn.Text = sprintf('  %s   %s', '0', 'Instructions');
        gettingStartedBtn.FontColor = CLR.text2;
        gettingStartedBtn.FontWeight = 'normal';

        % 5) Re-apply font and switch back to the Instructions page
        %    (switchTo(7) will re-add the checkmark on Instructions)
        applySerifFontRecursive(fig, FNT.serif);
        switchTo(7);
    end

    function refreshAllSteps()
        % Update each step's UI to reflect loaded state
        refreshStep1();
        refreshStep2();
        refreshStep3();
        refreshStep4();
        refreshStep5();
        refreshStep6();
    end

    function refreshStep1()
        S = fig.UserData;
        h = handles.step1;
        h.springDropDown.Value = S.spring_id;
        fillTableFromSpring(h, S.spring_id);
        if ~isempty(S.spring_calibration)
            a = S.spring_calibration.means(1);
            b = S.spring_calibration.means(2);
            h.statusLbl.Text = sprintf( ...
                'Calibration complete · offset alpha = %.4f g, stiffness beta = %.4f g/mm', a, b);
            h.statusLbl.FontColor = CLR.success;
            updateSidebarDone(stepBtns(1), CLR);
        end
    end

    function refreshStep2()
        S = fig.UserData;
        h = handles.step2;
        if ~isempty(S.imgDir)
            h.imgDirField.Value = S.imgDir;
        end
        if ~isempty(S.dist2px_calibration)
            h.statusLbl.Text = sprintf( ...
                'Calibration complete · alpha = %.4f, beta = %.6f mm/px', ...
                S.dist2px_calibration.means(1), S.dist2px_calibration.means(2));
            h.statusLbl.FontColor = CLR.success;
            updateSidebarDone(stepBtns(2), CLR);
        end
    end

    function refreshStep3()
        S = fig.UserData;
        h = handles.step3;
        if ~isempty(S.pattern)
            h.statusLbl.Text = sprintf('%d regions selected — ready for DIC tracking in step 4', ...
                size(S.pattern.rects, 1));
            h.statusLbl.FontColor = CLR.success;
            updateSidebarDone(stepBtns(3), CLR);
        end
    end

    function refreshStep4()
        S = fig.UserData;
        h = handles.step4;
        if ~isempty(S.distance)
            h.statusLbl.Text = sprintf( ...
                'DIC complete · %d images tracked', size(S.distance, 1));
            h.statusLbl.FontColor = CLR.success;
            updateSidebarDone(stepBtns(4), CLR);
        end
    end

    function refreshStep5()
        S = fig.UserData;
        h = handles.step5;
        h.widthField.Value     = S.hydrogel.width;
        h.thicknessField.Value = S.hydrogel.thickness;
        h.lengthField.Value    = S.hydrogel.length;
        if ~isempty(S.data)
            h.statusLbl.Text = 'Conversion complete';
            h.statusLbl.FontColor = CLR.success;
            updateSidebarDone(stepBtns(5), CLR);
        end
    end

    function refreshStep6()
        S = fig.UserData;
        h = handles.step6;
        if ~isempty(S.fit_results)
            h.resultLbl.Text = sprintf('E_gel = %.4f MPa  (%.2f kPa)', ...
                S.fit_results.theta_MLE, S.fit_results.theta_MLE * 1000);
            updateSidebarDone(stepBtns(6), CLR);
        end
    end

    % =====================================================================
    % STEP 0: GETTING STARTED — instructions page
    % =====================================================================
    function H = buildStep0_GettingStarted(parent, CLR)
        layout = uigridlayout(parent, [1, 1]);
        layout.Padding = [4 4 4 4];
        layout.Scrollable = 'on';

        card = makeCard(layout, CLR);
        cg = uigridlayout(card, [1, 1]);
        cg.Padding = [32 28 32 28];

        % All instruction content is rendered as a single uihtml component
        % so we can style it richly with headings, lists, and emphasis.
        H.html = uihtml(cg);
        H.html.HTMLSource = getInstructionsHTML();
    end

    function htmlStr = getInstructionsHTML()
        accentHex = '#BE4F94';
        infoHex   = '#8551A0';
        textHex   = '#291B2E';
        text2Hex  = '#665566';
        bgHex     = '#FBF8F9';
        pillHex   = '#FCEAF1';

        htmlStr = [ ...
        '<!DOCTYPE html><html><head><style>' ...
        sprintf('body { font-family: "Times New Roman", Georgia, serif; color: %s; background: %s; margin: 0; padding: 0; line-height: 1.55; font-size: 15px; }', textHex, bgHex) ...
        sprintf('h1 { color: %s; font-size: 28px; margin-bottom: 4px; }', accentHex) ...
        sprintf('h2 { color: %s; font-size: 20px; margin-top: 28px; margin-bottom: 8px; border-bottom: 1px solid %s; padding-bottom: 4px; }', textHex, accentHex) ...
        sprintf('h3 { color: %s; font-size: 17px; margin-top: 18px; margin-bottom: 6px; }', infoHex) ...
        sprintf('.subtitle { color: %s; font-style: italic; margin-bottom: 18px; }', text2Hex) ...
        sprintf('.note { background: %s; border-left: 3px solid %s; padding: 10px 14px; margin: 12px 0; border-radius: 4px; }', pillHex, accentHex) ...
        sprintf('.warn { background: #FFF4ED; border-left: 3px solid #D87D63; padding: 10px 14px; margin: 12px 0; border-radius: 4px; }') ...
        'ul, ol { margin: 6px 0 10px 0; padding-left: 28px; }' ...
        'li { margin-bottom: 4px; }' ...
        'b, strong { color: ' textHex '; }' ...
        'code { background: #EFE8EC; padding: 1px 6px; border-radius: 3px; font-family: Consolas, monospace; font-size: 13px; }' ...
        'p { margin: 6px 0 10px 0; }' ...
        '</style></head><body>' ...
        ...
        '<h1>Block Analysis</h1>' ...
        '<p class="subtitle">A complete guide to measuring hydrogel stiffness with this app.</p>' ...
        ...
        '<div class="note"><b>Before you begin:</b> Gather (a) your spring force-displacement data, ' ...
        '(b) a single calibration image showing the two reference blocks, and (c) a folder of "after" ' ...
        'images captured at successive load steps during your experiment. The app walks you ' ...
        'through the rest. Estimated time: 15-25 minutes per sample.</div>' ...
        ...
        '<h2>What this app does</h2>' ...
        '<p>This app computes the elastic modulus (Young''s modulus, E) of a hydrogel sample using ' ...
        'a six-step pipeline. You provide spring calibration data, two reference blocks of known size, ' ...
        'and a series of images captured while load is applied to the gel. The app uses Bayesian ' ...
        'calibration, digital image correlation (DIC), and maximum likelihood estimation to compute ' ...
        'stress vs. strain and fit the linear modulus.</p>' ...
        ...
        '<h2>What you''ll need</h2>' ...
        '<ul>' ...
        '<li><b>Spring calibration data:</b> a known spring (SP1, SP2, or SP3) characterized at ' ...
        '8 displacement levels with 3 force trials each. Built-in defaults are provided.</li>' ...
        '<li><b>Calibration image:</b> a single image (typically <code>0002.jpg</code>) showing both ' ...
        'reference blocks side by side, in clear focus.</li>' ...
        '<li><b>Reference image:</b> the "before" frame of your experiment, showing the gel at rest ' ...
        '(typically <code>0001.jpg</code> or <code>reference.jpg</code>).</li>' ...
        '<li><b>Image series:</b> a sequence of "after" images (<code>0001.jpg</code>, <code>0002.jpg</code>, ...) ' ...
        'captured at successive load steps. <b>Order matters.</b></li>' ...
        '<li><b>Hydrogel dimensions:</b> width, thickness, and length in millimeters.</li>' ...
        '</ul>' ...
        ...
        '<div class="note">As you finish each step, a small purple checkmark appears next to that ' ...
        'step in the sidebar so you can see your progress at a glance. The Instructions tab also ' ...
        'gets a checkmark as soon as you have read this page.</div>' ...
        ...
        '<h2>Step-by-step walkthrough</h2>' ...
        ...
        '<h3>Step 1 — Spring calibration</h3>' ...
        '<p>The pipeline needs to know how your reference spring converts displacement (mm) into force (g). ' ...
        'This step performs Bayesian linear regression (MCMC with 20,000 samples) on your spring''s ' ...
        'force-displacement data.</p>' ...
        '<ol>' ...
        '<li>Pick your spring from the dropdown (SP1, SP2, or SP3). The displacement and force-trial ' ...
        'table populates with default measured values.</li>' ...
        '<li>If you have a custom spring or want to override the values, edit any cell of the table ' ...
        'directly. Hit Enter to commit.</li>' ...
        '<li>Click <b>Preview data</b> to see your table plotted before fitting.</li>' ...
        '<li>Click <b>Run calibration</b>. The MCMC fit takes about 15-30 seconds and several ' ...
        'diagnostic figures (posterior distributions, Sobol indices) will appear in separate windows.</li>' ...
        '<li>When done, a purple checkmark appears next to "Spring calibration" in the sidebar.</li>' ...
        '</ol>' ...
        ...
        '<h3>Step 2 — Pixel calibration</h3>' ...
        '<p>Determine the pixels-per-millimeter scale of your imaging setup by clicking the corners ' ...
        'of two reference blocks of known size.</p>' ...
        '<ol>' ...
        '<li>Click <b>Upload image</b> and pick your calibration image (typically <code>0002.jpg</code>).</li>' ...
        '<li>Review the dimensions table — 8 sides × 4 trials of measured mm values. The defaults match ' ...
        'standard reference blocks. Overwrite any cell that differs for your blocks.</li>' ...
        '<li>Click <b>Click corners (4 trials)</b>. A window pops up showing your image.</li>' ...
        '<li>For each of 4 trials: click the 4 corners of the LEFT block in any order (markers turn pink). ' ...
        'Once you''ve placed 4, they lock to purple and the prompt updates to ask for the RIGHT block''s ' ...
        '4 corners. Then a new trial starts.</li>' ...
        '<li>Sub-pixel corner refinement and Bayesian calibration run automatically after the last click. ' ...
        'A scatter plot of pixels vs. mm appears with the fit line.</li>' ...
        '</ol>' ...
        '<div class="note"><b>Tip:</b> click somewhere near the corner, not exactly on it. The algorithm ' ...
        'uses sub-pixel edge refinement to lock onto the true corner. Being within ~10 pixels is plenty.</div>' ...
        ...
        '<h3>Step 3 — ROI selection</h3>' ...
        '<p>Pick 4 small patches on the reference image — these are the features the DIC algorithm will ' ...
        'track across the image series.</p>' ...
        '<ol>' ...
        '<li>Click <b>Upload image</b> and pick your reference (the "before" image, typically ' ...
        '<code>0001.jpg</code> or <code>reference.jpg</code>).</li>' ...
        '<li>Click <b>Draw 4 regions</b>. A window opens with your image.</li>' ...
        '<li>Click and drag to draw 4 rectangles, in order. <b>Convention:</b> R1 and R2 typically ' ...
        'frame the gel; R3 and R4 frame the spring.</li>' ...
        '<li>Pick patches with strong, distinctive features — corners, marks, edges, texture. Bland ' ...
        'uniform regions will track poorly.</li>' ...
        '<li>Patches should be small enough to be distinctive but large enough to contain unique features ' ...
        '(roughly 30-80 pixels on a side works well).</li>' ...
        '</ol>' ...
        ...
        '<h3>Step 4 — DIC tracking</h3>' ...
        '<p>Track the 4 patches across every "after" image and compute the distances R1-R2 (gel) and ' ...
        'R3-R4 (spring) for each frame.</p>' ...
        '<ol>' ...
        '<li>Click <b>Upload images from your computer</b> and multi-select all your "after" frames. ' ...
        'Hold Ctrl (or Cmd on Mac) and click each file, or Shift-click a range.</li>' ...
        '<li><b>You need at least 2 images.</b> The first frame (alphabetically sorted) becomes the ' ...
        'reference; every other image is tracked against it.</li>' ...
        '<li>Click <b>Run DIC tracking</b>. This takes several seconds per image. The plot shows ' ...
        'distance vs. image index for both pairs.</li>' ...
        '</ol>' ...
        '<div class="warn"><b>Critical: image order must match loading order.</b> The app sorts ' ...
        'uploaded files alphabetically before processing. If your filenames are not in load-increasing ' ...
        'order (e.g. <code>load_5g.jpg</code>, <code>load_10g.jpg</code>, <code>load_20g.jpg</code> are ' ...
        'fine, but <code>img_A.jpg</code>, <code>img_B.jpg</code>, ... with no relation to load order ' ...
        'is not), the resulting curves will look like zig-zags rather than smooth lines. Rename files ' ...
        'or use the diagnostic "sort by deformation" toggle in Step 5 if you suspect this.</div>' ...
        ...
        '<h3>Step 5 — Unit conversion</h3>' ...
        '<p>Combine the spring and pixel calibrations to convert DIC distances into millimeters of ' ...
        'deformation and grams of force.</p>' ...
        '<ol>' ...
        '<li>Enter your hydrogel''s dimensions: width, thickness, length (in mm).</li>' ...
        '<li>Click <b>Run unit conversion</b>. Two plots appear: the spring force-displacement curve ' ...
        '(left) and the hydrogel force-displacement curve (right). Both should be straight, monotonic ' ...
        'lines climbing up and to the right.</li>' ...
        '<li>If either curve has loops, zig-zags, or backtracks, your image series was likely not in ' ...
        'load order. Tick the <b>"Sort points by deformation"</b> checkbox and re-run as a diagnostic. ' ...
        'If sorting fixes the shape, fix your image ordering at the source — the sort toggle hides ' ...
        'the problem, it doesn''t solve it.</li>' ...
        '</ol>' ...
        ...
        '<h3>Step 6 — MLE fit & elastic modulus</h3>' ...
        '<p>Convert force-displacement to stress-strain using the gel dimensions, fit the linear elastic ' ...
        'modulus E, and display the result.</p>' ...
        '<ol>' ...
        '<li>Click <b>Run MLE fit</b>. A stress-strain plot appears with your data points and a dashed ' ...
        'linear fit. The elastic modulus is displayed in MPa and kPa.</li>' ...
        '<li>If your data appears non-monotonic, tick the <b>"Sort points by strain before fitting"</b> ' ...
        'checkbox before running. As in Step 5, this is a diagnostic — large differences from the ' ...
        'unsorted fit flag an image-ordering problem you should fix upstream.</li>' ...
        '<li>For hydrogels, expected values are typically 1 kPa to several hundred kPa depending on ' ...
        'composition and crosslinking density.</li>' ...
        '<li>Click <b>Export all results</b> to save the fit results, calibrations, and raw data to a ' ...
        '<code>.mat</code> or <code>.csv</code> file for downstream analysis.</li>' ...
        '</ol>' ...
        '<div class="note"><b>If the result looks wrong:</b> compare runs with the sort-by-strain ' ...
        'diagnostic toggle on and off. Large differences flag an image-ordering issue. Look at the ' ...
        'DIC overlay figures from Step 4 to spot any frames where a patch lost its lock. Sanity check ' ...
        'against a known calibration sample if possible.</div>' ...
        ...
        '<h2>Tips and troubleshooting</h2>' ...
        ...
        '<h3>Best practices</h3>' ...
        '<ul>' ...
        '<li><b>Image filenames matter.</b> Always name files in a way that sorts alphabetically into ' ...
        'load-increasing order. <code>0001.jpg, 0002.jpg, ...</code> is the safest convention.</li>' ...
        '<li><b>Reference image quality.</b> Use a sharp, well-lit reference frame for ROI selection. ' ...
        'A blurry reference produces poor patch matches throughout the series.</li>' ...
        '<li><b>Patch features.</b> When drawing ROIs, look for distinctive marks — printed dots, ink ' ...
        'speckle, scratches, edges of the gel/spring. Avoid bland uniform regions.</li>' ...
        '<li><b>Recordkeeping.</b> Note which spring (SP1/SP2/SP3) and which reference blocks you ' ...
        'used so the calibration tables stay correct across samples.</li>' ...
        '</ul>' ...
        ...
        '<h3>Common issues</h3>' ...
        '<ul>' ...
        '<li><b>"Step 3 says incomplete in Step 4":</b> Make sure ROI selection actually finished — ' ...
        'all 4 rectangles drawn and the purple checkmark visible on Step 3 in the sidebar.</li>' ...
        '<li><b>Step 4 shows no checkmark after DIC:</b> You may have uploaded only 1 image. DIC needs ' ...
        'at least 2 (one reference + one tracked frame).</li>' ...
        '<li><b>Force-displacement curves loop or zig-zag:</b> Image series uploaded out of load order. ' ...
        'See Steps 4 and 5 above.</li>' ...
        '<li><b>Elastic modulus seems impossibly high or low:</b> Check the hydrogel dimensions in ' ...
        'Step 5 (a 10x error in length gives a 10x error in strain), confirm the spring assignment in ' ...
        'Step 1 matches the spring physically used, and verify the px-to-mm scale by inspecting the ' ...
        'Step 2 scatter plot.</li>' ...
        '</ul>' ...
        ...
        '<h3>Using "Start over"</h3>' ...
        '<p>The <b>Start over</b> button in the upper right wipes all progress, clears all inputs, ' ...
        'and returns you to this Instructions page. Use it when you want a clean slate for a new ' ...
        'sample. It does not affect installed files or your image folders.</p>' ...
        ...
        '<h2>Pipeline overview</h2>' ...
        '<p>Under the hood:</p>' ...
        '<ol>' ...
        '<li><b>Spring calibration</b> fits force = a + b·displacement via Bayesian MCMC (Statistics Toolbox).</li>' ...
        '<li><b>Pixel calibration</b> uses sub-pixel edge refinement (perpendicular probes, parabolic peak ' ...
        'fit), RANSAC line fitting, and cross-product corner intersection to extract precise side lengths, ' ...
        'then Bayesian regression maps pixels to mm.</li>' ...
        '<li><b>ROI selection</b> picks 4 templates from the reference frame.</li>' ...
        '<li><b>DIC tracking</b> uses normalized cross-correlation (<code>normxcorr2</code>) to locate ' ...
        'each template in every "after" frame.</li>' ...
        '<li><b>Unit conversion</b> applies the two calibrations to convert pixel distances to mm and ' ...
        'grams of force.</li>' ...
        '<li><b>MLE fit</b> computes stress = force / cross-sectional area and strain = deformation / ' ...
        'length, then fits stress = E·strain to extract the elastic modulus.</li>' ...
        '</ol>' ...
        ...
        '</body></html>' ...
        ];
    end

    % =====================================================================
    % STEP 1 BUILDER & CALLBACK
    % =====================================================================
    function H = buildStep1_SpringCalibration(parent, CLR)
        % Use Scrollable on the uigridlayout itself so vertical scrolling works
        layout = uigridlayout(parent, [6, 1]);
        layout.RowHeight = {'fit', 'fit', 'fit', 'fit', 420, 'fit'};
        layout.ColumnWidth = {'1x'};
        layout.RowSpacing = 16;
        layout.Padding = [4 4 4 4];
        layout.Scrollable = 'on';

        % ---- Header ----
        headerCard = makeStepHeader(layout, '01', 'Spring calibration', ...
            ['Convert the reference spring''s stretch into the force it applies. ' ...
             'This gives us a force scale we''ll use later to measure the gel.'], ...
            CLR);
        headerCard.Layout.Row = 1;

        % ---- "What is this step?" explainer banner ----
        infoCard = uipanel(layout, 'BorderType','line', ...
            'BackgroundColor', CLR.pillBg);
        infoCard.Layout.Row = 2;
        ic = uigridlayout(infoCard, [1, 2]);
        ic.ColumnWidth = {36, '1x'};
        ic.Padding = [16 14 16 14];
        ic.ColumnSpacing = 12;
        iconLbl = uilabel(ic, 'Text', 'i', 'FontSize', 18, 'FontWeight','bold', ...
            'FontColor', [1 1 1], 'BackgroundColor', CLR.info, ...
            'HorizontalAlignment','center','VerticalAlignment','center');
        iconLbl.Layout.Column = 1;
        infoTxt = uilabel(ic, 'WordWrap','on', 'FontSize', 13, 'FontColor', CLR.pillFg, ...
            'Text', ['What this does: A calibration spring with known behavior is ' ...
            'stretched by set distances, and the resulting force is measured 3 times ' ...
            'at each distance. Fitting a line (Force = alpha + beta x displacement) ' ...
            'tells us the spring''s stiffness (beta) and offset (alpha). We reuse ' ...
            'that line later to turn the gel''s measured displacement into force. ' ...
            'The reference data for springs SP1-SP3 is built in below; you can edit ' ...
            'any value if your spring differs.']);
        infoTxt.Layout.Column = 2;

        % ---- Spring picker ----
        topRow = uigridlayout(layout, [1, 1]);
        topRow.Layout.Row = 3;
        topRow.ColumnWidth = {'1x'};
        topRow.Padding = [0 0 0 0];

        % picker card (full width now that the diagram is removed)
        pickCard = makeCard(topRow, CLR);
        pickCard.Layout.Column = 1;
        pk = uigridlayout(pickCard, [3, 2]);
        pk.RowHeight = {'fit','fit','fit'};
        pk.ColumnWidth = {'fit','1x'};
        pk.Padding = [20 18 20 18];
        pk.RowSpacing = 14; pk.ColumnSpacing = 14;

        pkTitle = uilabel(pk, 'Text','Which spring are you calibrating?', ...
            'FontSize', 14, 'FontWeight','bold', 'FontColor', CLR.text);
        pkTitle.Layout.Row = 1; pkTitle.Layout.Column = [1 2];

        l1 = uilabel(pk, 'Text', 'Spring', 'FontWeight','bold', ...
            'FontColor', CLR.text2, 'FontSize', 13);
        l1.Layout.Row = 2; l1.Layout.Column = 1;
        H.springDropDown = uidropdown(pk, ...
            'Items', {'SP1','SP2','SP3'}, ...
            'ItemsData', {1, 2, 3}, ...
            'Value', 1, 'FontSize', 13);
        H.springDropDown.Layout.Row = 2; H.springDropDown.Layout.Column = 2;
        H.springDropDown.ValueChangedFcn = @(d,~) onSpringPicked(d.Value);

        pkHint = uilabel(pk, 'WordWrap','on', 'FontSize', 12, 'FontColor', CLR.text3, ...
            'Text', ['Choosing a spring fills the table below with that ' ...
            'spring''s reference measurements. Edit cells if your readings differ.']);
        pkHint.Layout.Row = 3; pkHint.Layout.Column = [1 2];

        % ---- Editable data table ----
        tableCard = makeCard(layout, CLR);
        tableCard.Layout.Row = 4;
        tg = uigridlayout(tableCard, [2, 1]);
        tg.RowHeight = {'fit', 'fit'};
        tg.Padding = [20 16 20 16];
        tg.RowSpacing = 10;

        tTitle = uilabel(tg, 'Text', ...
            'Reference data — displacement (mm) and the 3 force trials (g) at each step', ...
            'FontSize', 14, 'FontWeight','bold', 'FontColor', CLR.text);
        tTitle.Layout.Row = 1;

        H.dataTable = uitable(tg, ...
            'ColumnName', {'Displacement (mm)', 'Force trial 1 (g)', ...
                           'Force trial 2 (g)', 'Force trial 3 (g)'}, ...
            'ColumnEditable', [true true true true], ...
            'FontSize', 12, ...
            'RowName', {});
        H.dataTable.Layout.Row = 2;
        H.dataTable.CellEditCallback = @(~,~) onTableEdited();

        % ---- Plot + actions row ----
        bottomRow = uigridlayout(layout, [1, 2]);
        bottomRow.Layout.Row = 5;
        bottomRow.ColumnWidth = {'1x', 300};
        bottomRow.ColumnSpacing = 16;
        bottomRow.Padding = [0 0 0 0];

        % plot
        plotCard = makeCard(bottomRow, CLR);
        plotCard.Layout.Column = 1;
        pg = uigridlayout(plotCard, [1,1]);
        pg.Padding = [16 16 16 16];
        H.axes = uiaxes(pg);
        H.axes.XLabel.String = 'Displacement [mm]';
        H.axes.YLabel.String = 'Force [g]';
        H.axes.Title.String  = 'Spring data and fitted line';
        H.axes.FontSize = 11;

        % action panel
        actCard = makeCard(bottomRow, CLR);
        actCard.Layout.Column = 2;
        ag = uigridlayout(actCard, [6, 1]);
        ag.RowHeight = {'fit','fit','fit','fit','fit','1x'};
        ag.Padding = [18 18 18 18];
        ag.RowSpacing = 12;

        actTitle = uilabel(ag, 'Text','Actions', 'FontSize', 14, ...
            'FontWeight','bold', 'FontColor', CLR.text);
        actTitle.Layout.Row = 1;

        step1desc = uilabel(ag, 'WordWrap','on', 'FontSize', 12, 'FontColor', CLR.text2, ...
            'Text', ['1. Preview plots your table values so you can eyeball the ' ...
            'data before fitting.']);
        step1desc.Layout.Row = 2;
        btnPreview = uibutton(ag, 'Text','Preview data', 'FontSize', 13);
        btnPreview.Layout.Row = 3;
        btnPreview.ButtonPushedFcn = @(~,~) previewSpring();

        step2desc = uilabel(ag, 'WordWrap','on', 'FontSize', 12, 'FontColor', CLR.text2, ...
            'Text', ['2. Run calibration fits the line with Bayesian MCMC ' ...
            '(20,000 samples — takes ~10-30 s and opens a few diagnostic figures).']);
        step2desc.Layout.Row = 4;
        btnRun = uibutton(ag, 'Text','Run calibration', 'FontSize', 13, ...
            'BackgroundColor', CLR.accent, 'FontColor', [1 1 1]);
        btnRun.Layout.Row = 5;
        btnRun.ButtonPushedFcn  = @(~,~) runSpringCal();
        % Row 6 is an empty '1x' spacer so the buttons keep their natural
        % height instead of stretching to fill the card.

        % ---- Status footer ----
        statusCard = makeStatusFooter(layout, CLR);
        statusCard.Layout.Row = 6;
        H.statusLbl = statusCard.UserData.lbl;

        % Initialize the table with SP1 data
        fillTableFromSpring(H, 1);
    end

    function fillTableFromSpring(H, springId)
        sd = load_spring_data(springId);
        n = numel(sd.d);
        T = zeros(n, 4);
        for i = 1:n
            T(i,1) = sd.d{i};
            fi = sd.f{i};
            T(i,2:4) = fi(1:3);
        end
        H.dataTable.Data = T;
    end

    function onSpringPicked(id)
        S = fig.UserData;
        S.spring_id = id;
        fig.UserData = S;
        fillTableFromSpring(handles.step1, id);
        handles.step1.statusLbl.Text = sprintf( ...
            'Loaded reference data for SP%d. Edit cells if needed, then Run calibration.', id);
        handles.step1.statusLbl.FontColor = CLR.text2;
    end

    function onTableEdited()
        handles.step1.statusLbl.Text = ...
            'Table edited. Click Preview data to re-plot, or Run calibration to fit.';
        handles.step1.statusLbl.FontColor = CLR.warn;
    end

    % Build a spring_data struct from the current table contents
    function sd = springDataFromTable()
        T = handles.step1.dataTable.Data;
        n = size(T, 1);
        d = cell(n, 1);
        f = cell(1, n);
        for i = 1:n
            d{i} = T(i, 1);
            f{i} = T(i, 2:4);
        end
        sd.d = d; sd.f = f; sd.sp = fig.UserData.spring_id;
    end

    function previewSpring()
        h = handles.step1;
        T = h.dataTable.Data;
        cla(h.axes);
        allD = []; allF = [];
        for i = 1:size(T,1)
            allD = [allD; repmat(T(i,1), 3, 1)]; %#ok<AGROW>
            allF = [allF; T(i,2:4)'];            %#ok<AGROW>
        end
        scatter(h.axes, allD, allF, 30, CLR.info, 'filled');
        h.axes.Title.String = 'Spring data (preview)';
        legend(h.axes, 'off');
        h.statusLbl.Text = sprintf('Previewing %d points. Ready to run calibration.', numel(allD));
        h.statusLbl.FontColor = CLR.text2;
    end

    function runSpringCal()
        S = fig.UserData;
        S.spring_data = springDataFromTable();
        fig.UserData = S;
        d = uiprogressdlg(fig, 'Title','Running Bayesian calibration', ...
            'Message', sprintf(['Sampling 20,000 MCMC draws for SP%d.\n' ...
            'This takes ~10-30 seconds and may open diagnostic figures.'], ...
            S.spring_id), 'Indeterminate','on');
        cleanupObj = onCleanup(@() close(d));
        try
            S.spring_calibration = calibration_spring(S.spring_data);
            fig.UserData = S;
            % Plot data + fit line in the step's own axes
            h = handles.step1;
            previewSpring();
            hold(h.axes, 'on');
            xLim = h.axes.XLim;
            xs = linspace(xLim(1), xLim(2), 100);
            a = S.spring_calibration.means(1);
            b = S.spring_calibration.means(2);
            ys = a + b * xs;
            plot(h.axes, xs, ys, 'Color', CLR.accent, 'LineWidth', 2.5);
            hold(h.axes, 'off');
            h.axes.Title.String = 'Spring data and fitted line';
            legend(h.axes, {'Measured', sprintf('Fit: F = %.3f + %.3f·d', a, b)}, ...
                'Location','northwest');
            refreshStep1();
        catch ME
            uialert(fig, sprintf('Calibration failed: %s', ME.message), 'Error');
        end
    end
    function H = buildStep2_PixelCalibration(parent, CLR)
        layout = uigridlayout(parent, [7, 1]);
        layout.RowHeight = {'fit', 'fit', 'fit', 'fit', 'fit', 480, 'fit'};
        layout.ColumnWidth = {'1x'};
        layout.RowSpacing = 16;
        layout.Padding = [4 4 4 4];
        layout.Scrollable = 'on';

        headerCard = makeStepHeader(layout, '02', 'Pixel calibration', ...
            ['Tell the app how many pixels equal one millimeter in your camera ' ...
             'setup, by clicking the corners of two reference blocks of known size.'], CLR);
        headerCard.Layout.Row = 1;

        % ---- Info banner ----
        infoCard = uipanel(layout, 'BorderType','line', 'BackgroundColor', CLR.pillBg);
        infoCard.Layout.Row = 2;
        ic = uigridlayout(infoCard, [1, 2]);
        ic.ColumnWidth = {36, '1x'};
        ic.Padding = [16 14 16 14];
        ic.ColumnSpacing = 12;
        iconLbl = uilabel(ic, 'Text', 'i', 'FontSize', 18, 'FontWeight','bold', ...
            'FontColor', [1 1 1], 'BackgroundColor', CLR.info, ...
            'HorizontalAlignment','center','VerticalAlignment','center');
        iconLbl.Layout.Column = 1;
        infoTxt = uilabel(ic, 'WordWrap','on', 'FontSize', 13, 'FontColor', CLR.pillFg, ...
            'Text', ['What this does: Upload a calibration image showing two ' ...
            'reference blocks of known dimensions (the standard image is ' ...
            '0002.jpg). Enter the blocks'' true mm side lengths in the table ' ...
            'below. You then click the 4 corners of the left block and the ' ...
            '4 corners of the right block, repeated 4 times for repeatability. ' ...
            'Sub-pixel edge refinement gives precise side lengths, and Bayesian ' ...
            'calibration runs automatically after the last click to derive the ' ...
            'pixels-per-mm scale used downstream.']);
        infoTxt.Layout.Column = 2;

        % ---- Step 1: upload card ----
        upCard = makeCard(layout, CLR);
        upCard.Layout.Row = 3;
        ug = uigridlayout(upCard, [3, 3]);
        ug.RowHeight = {'fit','fit','fit'};
        ug.ColumnWidth = {'fit','1x','fit'};
        ug.Padding = [20 18 20 18];
        ug.RowSpacing = 10;
        ug.ColumnSpacing = 12;

        uTitle = uilabel(ug, 'Text','Step 1 — Choose your calibration image', ...
            'FontSize', 14, 'FontWeight','bold', 'FontColor', CLR.text);
        uTitle.Layout.Row = 1; uTitle.Layout.Column = [1 3];

        lDir = uilabel(ug, 'Text','Image path', 'FontWeight','bold', ...
            'FontColor', CLR.text2, 'FontSize', 13);
        lDir.Layout.Row = 2; lDir.Layout.Column = 1;
        H.imgDirField = uieditfield(ug, 'text', ...
            'Placeholder','Full path to a .jpg or .png — use Upload or type it here');
        H.imgDirField.Layout.Row = 2; H.imgDirField.Layout.Column = 2;
        H.imgDirField.Editable = 'on';
        H.imgDirField.ValueChangedFcn = @(d,~) loadTypedImagePath(d.Value);

        btnUpload = uibutton(ug, 'Text','Upload image...', 'FontSize', 13);
        btnUpload.Layout.Row = 2; btnUpload.Layout.Column = 3;
        btnUpload.ButtonPushedFcn = @(~,~) uploadImages();

        uHint = uilabel(ug, 'WordWrap','on', 'FontSize', 12, 'FontColor', CLR.text3, ...
            'Text', ['Either click Upload to browse, or paste a full file path ' ...
            '(e.g. C:\Users\you\Pictures\0002.jpg) and press Enter. The image should ' ...
            'clearly show both reference blocks side by side.']);
        uHint.Layout.Row = 3; uHint.Layout.Column = [1 3];

        % ---- Step 2: dimensions table card ----
        dimCard = makeCard(layout, CLR);
        dimCard.Layout.Row = 4;
        dg = uigridlayout(dimCard, [3, 1]);
        dg.RowHeight = {'fit', 'fit', 'fit'};
        dg.Padding = [20 18 20 18];
        dg.RowSpacing = 10;

        dTitle = uilabel(dg, 'Text','Step 2 — Enter the true side lengths (mm)', ...
            'FontSize', 14, 'FontWeight','bold', 'FontColor', CLR.text);
        dTitle.Layout.Row = 1;

        dDesc = uilabel(dg, 'WordWrap','on', 'FontSize', 12, 'FontColor', CLR.text2, ...
            'Text', ['One row per labelled side (L1-L4 = left block, L5-L8 = right ' ...
            'block). Four columns for the four repeated measurements. Defaults ' ...
            'reflect the standard lab blocks — overwrite any cells that differ ' ...
            'for your setup.']);
        dDesc.Layout.Row = 2;

        defaultDims = [10.91 10.91 10.96 10.87;   % L1 left-top
                       23.73 23.96 23.81 23.98;   % L2 left-right
                       10.98 10.92 10.94 10.93;   % L3 left-bottom
                       23.86 23.88 23.81 23.90;   % L4 left-left
                        7.28  7.32  7.34  7.41;   % L5 right-top
                       24.14 24.07 24.14 24.09;   % L6 right-right
                        7.37  7.32  7.33  7.22;   % L7 right-bottom
                       24.06 24.12 24.12 23.98];  % L8 right-left
        H.dimsTable = uitable(dg, 'Data', defaultDims, ...
            'ColumnName', {'Trial 1','Trial 2','Trial 3','Trial 4'}, ...
            'RowName', {'L1 (LEFT top)','L2 (LEFT right)','L3 (LEFT bottom)', ...
                        'L4 (LEFT left)','L5 (RIGHT top)','L6 (RIGHT right)', ...
                        'L7 (RIGHT bottom)','L8 (RIGHT left)'}, ...
            'ColumnEditable', true(1, 4), ...
            'ColumnWidth', repmat({90}, 1, 4), ...
            'FontSize', 12);
        H.dimsTable.Layout.Row = 3;

        % ---- Step 3: action card ----
        actCard = makeCard(layout, CLR);
        actCard.Layout.Row = 5;
        ag = uigridlayout(actCard, [3, 1]);
        ag.RowHeight = {'fit','fit','fit'};
        ag.Padding = [20 18 20 18];
        ag.RowSpacing = 10;

        aTitle = uilabel(ag, 'Text','Step 3 — Click corners (4 trials)', ...
            'FontSize', 14, 'FontWeight','bold', 'FontColor', CLR.text);
        aTitle.Layout.Row = 1;

        aDesc = uilabel(ag, 'WordWrap','on', 'FontSize', 12, 'FontColor', CLR.text2, ...
            'Text', ['Opens a click window. For each of 4 trials, click the 4 ' ...
            'corners of the LEFT block (any order), then the 4 corners of the ' ...
            'RIGHT block. The Bayesian px-to-mm fit runs automatically ' ...
            'when all 4 trials are done.']);
        aDesc.Layout.Row = 2;

        btnTrials = uibutton(ag, 'Text','Click corners (4 trials)', 'FontSize', 13, ...
            'BackgroundColor', CLR.accent, 'FontColor', [1 1 1]);
        btnTrials.Layout.Row = 3;
        btnTrials.ButtonPushedFcn = @(~,~) runCornerTrials();

        % ---- Plot card ----
        plotCard = makeCard(layout, CLR);
        plotCard.Layout.Row = 6;
        pg = uigridlayout(plotCard, [1,1]);
        pg.Padding = [16 16 16 16];
        H.axes = uiaxes(pg);
        H.axes.XLabel.String = 'Pixels';
        H.axes.YLabel.String = 'Distance [mm]';
        H.axes.Title.String  = 'Pixel-to-distance calibration';
        H.axes.FontSize = 11;

        statusCard = makeStatusFooter(layout, CLR);
        statusCard.Layout.Row = 7;
        H.statusLbl = statusCard.UserData.lbl;
    end

    function setImgDir(p)
        S = fig.UserData; S.imgDir = p; fig.UserData = S;
    end

    function browseImgDir()
        try
            p = uigetdir(pwd, 'Select image folder');
            if p ~= 0
                S = fig.UserData; S.imgDir = [p filesep]; fig.UserData = S;
                handles.step2.imgDirField.Value = S.imgDir;
            end
        catch
            uialert(fig, ...
                ['Folder browse not available in this environment. ' ...
                 'Type the path manually or use Upload image(s).'], ...
                'Info');
        end
    end

    function uploadImages()
        try
            [files, path] = uigetfile({'*.jpg;*.jpeg;*.png;*.bmp;*.tif;*.tiff', ...
                'Image files (*.jpg;*.jpeg;*.png;*.bmp;*.tif;*.tiff)'; ...
                '*.*', 'All files (*.*)'}, ...
                'Select calibration image', 'MultiSelect','on');
            if isequal(files, 0), return; end
            if ischar(files), files = {files}; end
            S = fig.UserData;
            S.image_paths = cellfun(@(f) fullfile(path, f), files, 'uni', false);
            S.imgDir = path;
            % Store the FULL path to the first uploaded image so the
            % calibration routine knows exactly which file to open. This
            % avoids the old behavior where it searched the folder for a
            % hardcoded filename like 0002.jpg.
            S.calImagePath = S.image_paths{1};
            fig.UserData = S;
            handles.step2.imgDirField.Value = S.calImagePath;
            handles.step2.statusLbl.Text = sprintf( ...
                'Loaded "%s". Click "Click corners" to continue.', files{1});
            handles.step2.statusLbl.FontColor = CLR.text2;
        catch ME
            uialert(fig, sprintf('Upload failed: %s', ME.message), 'Error');
        end
    end

    function loadTypedImagePath(p)
        % Handle a user typing a path directly into the field.
        if isempty(p), return; end
        if ~isfile(p)
            uialert(fig, sprintf( ...
                ['The path you entered doesn''t point to an existing file:\n\n' ...
                '%s\n\nDouble-check the path and try again.'], p), 'File not found');
            return;
        end
        S = fig.UserData;
        S.calImagePath = p;
        [folder, ~, ~] = fileparts(p);
        S.imgDir = [folder filesep];
        S.image_paths = {p};
        fig.UserData = S;
        [~, name, ext] = fileparts(p);
        handles.step2.statusLbl.Text = sprintf( ...
            'Loaded "%s%s". Click "Click corners" to continue.', name, ext);
        handles.step2.statusLbl.FontColor = CLR.text2;
    end

    function runCornerTrials()
        S = fig.UserData;
        if isempty(S.imgDir) && isempty(S.image_paths) && ...
                (~isfield(S,'calImagePath') || isempty(S.calImagePath))
            uialert(fig, 'Specify an image folder or upload an image first.', 'Missing image'); return;
        end
        % Read the user-edited dimensions table and validate
        dimsTable = handles.step2.dimsTable.Data;
        if ~isnumeric(dimsTable) || ~isequal(size(dimsTable), [8 4]) ...
                || any(~isfinite(dimsTable(:))) || any(dimsTable(:) <= 0)
            uialert(fig, ['The side-length table must contain 8 rows × 4 columns ' ...
                'of positive numbers in mm. Fix any empty or non-numeric cells ' ...
                'and try again.'], 'Bad dimensions table');
            return;
        end
        try
            % Prefer the direct image path if we have one; fall back to folder
            if isfield(S, 'calImagePath') && ~isempty(S.calImagePath) && isfile(S.calImagePath)
                imgArg = S.calImagePath;
            else
                imgArg = S.imgDir;
            end
            S.dist2px_data = load_px2dist_data_app(imgArg, fig, dimsTable);
            fig.UserData = S;
            handles.step2.statusLbl.Text = ...
                sprintf('Captured %d sides × 4 trials. Starting px→mm calibration...', 8);
            handles.step2.statusLbl.FontColor = CLR.text2;
            drawnow;
            % Chain automatically into calibration so the user doesn't have to
            % click a second button.
            runPxCal();
        catch ME
            uialert(fig, sprintf('Click trials failed: %s', ME.message), 'Error');
        end
    end

    function runPxCal()
        S = fig.UserData;
        if isempty(S.dist2px_data)
            uialert(fig, 'Run corner trials first.', 'Missing data'); return;
        end
        d = uiprogressdlg(fig, 'Title','Running Bayesian px→mm calibration', ...
            'Message','Sampling MCMC, please wait...', 'Indeterminate','on');
        cleanupObj = onCleanup(@() close(d));
        try
            S.dist2px_calibration = calibration_px2dist(S.dist2px_data);
            fig.UserData = S;
            % Plot
            h = handles.step2;
            cla(h.axes);
            allPx = []; allMm = [];
            for k = 1:numel(S.dist2px_data.px)
                allPx = [allPx; S.dist2px_data.px{k}(:)]; %#ok<AGROW>
                allMm = [allMm; S.dist2px_data.d{k}(:)];   %#ok<AGROW>
            end
            scatter(h.axes, allPx, allMm, 24, CLR.info, 'filled');
            hold(h.axes, 'on');
            xs = linspace(min(allPx), max(allPx), 100);
            ys = S.dist2px_calibration.means(1) + S.dist2px_calibration.means(2) * xs;
            plot(h.axes, xs, ys, 'Color', CLR.accent, 'LineWidth', 2);
            hold(h.axes, 'off');
            legend(h.axes, {'Data', sprintf('Fit: %.4f + %.6f·px', ...
                S.dist2px_calibration.means(1), S.dist2px_calibration.means(2))}, ...
                'Location','best');
            refreshStep2();
        catch ME
            uialert(fig, sprintf('Calibration failed: %s', ME.message), 'Error');
        end
    end


    % =====================================================================
    % STEP 3: ROI SELECTION
    % =====================================================================
    function H = buildStep3_ROISelection(parent, CLR)
        layout = uigridlayout(parent, [6, 1]);
        layout.RowHeight = {'fit', 'fit', 'fit', 'fit', 480, 'fit'};
        layout.ColumnWidth = {'1x'};
        layout.RowSpacing = 16;
        layout.Padding = [4 4 4 4];
        layout.Scrollable = 'on';

        % ---- Header ----
        headerCard = makeStepHeader(layout, '03', 'ROI selection', ...
            ['Choose 4 pattern regions (R1-R4) on a reference image. ' ...
             'These regions get tracked frame-by-frame in step 4 to measure ' ...
             'how points on the gel move under load.'], CLR);
        headerCard.Layout.Row = 1;

        % ---- Info banner ----
        infoCard = uipanel(layout, 'BorderType','line', ...
            'BackgroundColor', CLR.pillBg);
        infoCard.Layout.Row = 2;
        ic = uigridlayout(infoCard, [1, 2]);
        ic.ColumnWidth = {36, '1x'};
        ic.Padding = [16 14 16 14];
        ic.ColumnSpacing = 12;
        iconLbl = uilabel(ic, 'Text', 'i', 'FontSize', 18, 'FontWeight','bold', ...
            'FontColor', [1 1 1], 'BackgroundColor', CLR.info, ...
            'HorizontalAlignment','center','VerticalAlignment','center');
        iconLbl.Layout.Column = 1;
        infoTxt = uilabel(ic, 'WordWrap','on', 'FontSize', 13, 'FontColor', CLR.pillFg, ...
            'Text', ['What this does: You pick 4 small rectangular patches on a ' ...
            'reference image — typically two on the spring side and two on the gel ' ...
            'side. The DIC algorithm in step 4 looks for each of these patches in ' ...
            'every other image, tracking how they shift to compute displacement. ' ...
            'Pick patches with strong, identifiable features (corners, marks, ' ...
            'edges) — they need to be visually unique so the tracker can find them.']);
        infoTxt.Layout.Column = 2;

        % ---- Upload card ----
        uploadCard = makeCard(layout, CLR);
        uploadCard.Layout.Row = 3;
        ug = uigridlayout(uploadCard, [3, 3]);
        ug.RowHeight = {'fit','fit','fit'};
        ug.ColumnWidth = {'fit','1x','fit'};
        ug.Padding = [20 18 20 18];
        ug.RowSpacing = 12;
        ug.ColumnSpacing = 12;

        uTitle = uilabel(ug, 'Text','Step 1 — Choose the reference image', ...
            'FontSize', 14, 'FontWeight','bold', 'FontColor', CLR.text);
        uTitle.Layout.Row = 1; uTitle.Layout.Column = [1 3];

        lLbl = uilabel(ug, 'Text','Reference image', ...
            'FontWeight','bold', 'FontColor', CLR.text2, 'FontSize', 13);
        lLbl.Layout.Row = 2; lLbl.Layout.Column = 1;
        H.refField = uieditfield(ug, 'text', ...
            'Placeholder','No image selected — use Upload or paste a full path here');
        H.refField.Layout.Row = 2; H.refField.Layout.Column = 2;
        H.refField.Editable = 'on';
        H.refField.ValueChangedFcn = @(d,~) loadTypedRefImage(d.Value);

        btnUpload = uibutton(ug, 'Text','Upload image...', 'FontSize', 13);
        btnUpload.Layout.Row = 2; btnUpload.Layout.Column = 3;
        btnUpload.ButtonPushedFcn = @(~,~) uploadRefImage();

        uHint = uilabel(ug, 'WordWrap','on', 'FontSize', 12, 'FontColor', CLR.text3, ...
            'Text', ['Either click Upload to browse, or paste a full file path ' ...
            '(e.g. C:\Users\you\Pictures\0001.jpg) and press Enter. This is usually ' ...
            'the first frame of your DIC series (before the spring/gel deforms).']);
        uHint.Layout.Row = 3; uHint.Layout.Column = [1 3];

        % ---- Action card ----
        actCard = makeCard(layout, CLR);
        actCard.Layout.Row = 4;
        ag = uigridlayout(actCard, [3, 1]);
        ag.RowHeight = {'fit','fit','fit'};
        ag.Padding = [20 18 20 18];
        ag.RowSpacing = 10;

        aTitle = uilabel(ag, 'Text','Step 2 — Draw the 4 regions', ...
            'FontSize', 14, 'FontWeight','bold', 'FontColor', CLR.text);
        aTitle.Layout.Row = 1;

        aDesc = uilabel(ag, 'WordWrap','on', 'FontSize', 12, 'FontColor', CLR.text2, ...
            'Text', ['Opens a full-window picker. For each region R1, R2, R3, R4: ' ...
            'click and drag to draw a rectangle around the feature you want to ' ...
            'track. The window will guide you through all 4 in sequence.']);
        aDesc.Layout.Row = 2;

        btnDraw = uibutton(ag, 'Text','Draw 4 regions', 'FontSize', 13, ...
            'BackgroundColor', CLR.accent, 'FontColor', [1 1 1]);
        btnDraw.Layout.Row = 3;
        btnDraw.ButtonPushedFcn = @(~,~) runROISelection();

        % ---- Preview card ----
        previewCard = makeCard(layout, CLR);
        previewCard.Layout.Row = 5;
        pg = uigridlayout(previewCard, [1, 1]);
        pg.Padding = [12 12 12 12];
        H.previewAxes = uiaxes(pg);
        H.previewAxes.Title.String = 'Reference image preview (regions will appear in green)';
        H.previewAxes.FontSize = 11;
        H.previewAxes.XTick = []; H.previewAxes.YTick = [];

        % ---- Status footer ----
        statusCard = makeStatusFooter(layout, CLR);
        statusCard.Layout.Row = 6;
        H.statusLbl = statusCard.UserData.lbl;
    end

    function uploadRefImage()
        try
            [file, path] = uigetfile({'*.jpg;*.jpeg;*.png;*.bmp;*.tif;*.tiff', ...
                'Image files'}, 'Select the reference image');
            if isequal(file, 0), return; end
            setRefImage(fullfile(path, file));
        catch ME
            uialert(fig, sprintf('Upload failed: %s', ME.message), 'Error');
        end
    end

    function loadTypedRefImage(p)
        if isempty(p), return; end
        if ~isfile(p)
            uialert(fig, sprintf(['The path you entered doesn''t point to an ' ...
                'existing file:\n\n%s\n\nDouble-check the path and try again.'], ...
                p), 'File not found');
            return;
        end
        setRefImage(p);
    end

    function setRefImage(fullPath)
        S = fig.UserData;
        S.refImagePath = fullPath;
        [folder, name, ext] = fileparts(fullPath);
        S.imgDir = [folder filesep];
        fig.UserData = S;
        handles.step3.refField.Value = fullPath;
        % Show preview
        try
            I = imread(fullPath);
            imshow(I, 'Parent', handles.step3.previewAxes);
            handles.step3.previewAxes.Title.String = ...
                sprintf('Preview: %s%s', name, ext);
        catch
            % preview failure is non-fatal
        end
        handles.step3.statusLbl.Text = ...
            'Reference image loaded. Click "Draw 4 regions" to continue.';
        handles.step3.statusLbl.FontColor = CLR.text2;
    end

    function runROISelection()
        % Always re-read state freshly to avoid stale local copies.
        S = fig.UserData;
        refPath = '';
        if isfield(S, 'refImagePath') && ~isempty(S.refImagePath) && isfile(S.refImagePath)
            refPath = S.refImagePath;
        elseif ~isempty(S.imgDir)
            candidate = fullfile(S.imgDir, 'reference.jpg');
            if isfile(candidate), refPath = candidate; end
        end
        if isempty(refPath)
            uialert(fig, 'Upload a reference image first using the button above.', ...
                'Missing image');
            return;
        end
        try
            pattern = drawROIsInModal(refPath);
            if isempty(pattern) || ~isstruct(pattern) || ~isfield(pattern,'regions')
                handles.step3.statusLbl.Text = 'Cancelled — no regions saved.';
                handles.step3.statusLbl.FontColor = CLR.warn;
                return;
            end
            % Re-fetch state right before writing so we don't clobber
            % anything that may have changed during the long ROI session.
            S = fig.UserData;
            S.pattern = pattern;
            % Also cache the reference image data in memory so the
            % preview stays alive even if the file moves later.
            try
                S.refImageData = imread(refPath);
            catch
            end
            fig.UserData = S;

            % Draw the saved regions on the preview axes using image()
            % (not imshow) so it doesn't touch the parent figure state.
            try
                renderRegionsPreview(handles.step3.previewAxes, S.refImageData, ...
                    S.pattern.rects, CLR.accent);
            catch
            end
            refreshStep3();
        catch ME
            uialert(fig, sprintf('ROI selection failed: %s', ME.message), 'Error');
        end
    end


    % =====================================================================
    % STEP 4: DIC TRACKING
    % =====================================================================
    function H = buildStep4_DICTracking(parent, CLR)
        layout = uigridlayout(parent, [6, 1]);
        % Plot row gets a tall fixed height so the chart isn't squished.
        % Layout.Scrollable lets the user scroll the whole panel.
        layout.RowHeight = {'fit', 'fit', 'fit', 'fit', 480, 'fit'};
        layout.ColumnWidth = {'1x'};
        layout.RowSpacing = 16;
        layout.Padding = [4 4 4 4];
        layout.Scrollable = 'on';

        headerCard = makeStepHeader(layout, '04', 'DIC tracking', ...
            ['Track the 4 regions from step 3 across a series of "after" images ' ...
             '(one per load step) to measure how the gel and spring deform.'], CLR);
        headerCard.Layout.Row = 1;

        % ---- Info banner ----
        infoCard = uipanel(layout, 'BorderType','line', 'BackgroundColor', CLR.pillBg);
        infoCard.Layout.Row = 2;
        ic = uigridlayout(infoCard, [1, 2]);
        ic.ColumnWidth = {36, '1x'};
        ic.Padding = [16 14 16 14];
        ic.ColumnSpacing = 12;
        iconLbl = uilabel(ic, 'Text', 'i', 'FontSize', 18, 'FontWeight','bold', ...
            'FontColor', [1 1 1], 'BackgroundColor', CLR.info, ...
            'HorizontalAlignment','center','VerticalAlignment','center');
        iconLbl.Layout.Column = 1;
        infoTxt = uilabel(ic, 'WordWrap','on', 'FontSize', 13, 'FontColor', CLR.pillFg, ...
            'Text', ['What this does: Step 3 picked 4 small patches on a single ' ...
            '"before" image (the reference). This step needs the matching ' ...
            '"after" images — typically a series like 0001.jpg, 0002.jpg, ' ...
            '0003.jpg ... one per load step in your experiment. The DIC ' ...
            'algorithm hunts for each patch in every "after" image and records ' ...
            'how the distances between them change as load is applied.']);
        infoTxt.Layout.Column = 2;

        % ---- Upload card ----
        upCard = makeCard(layout, CLR);
        upCard.Layout.Row = 3;
        ug = uigridlayout(upCard, [5, 3]);
        ug.RowHeight = {'fit','fit','fit','fit','fit'};
        ug.ColumnWidth = {'fit','1x','fit'};
        ug.Padding = [20 18 20 18];
        ug.RowSpacing = 10;
        ug.ColumnSpacing = 12;

        uTitle = uilabel(ug, 'Text','Step 1 — Upload your "after" image series', ...
            'FontSize', 14, 'FontWeight','bold', 'FontColor', CLR.text);
        uTitle.Layout.Row = 1; uTitle.Layout.Column = [1 3];

        lDir = uilabel(ug, 'Text','Folder path', 'FontWeight','bold', ...
            'FontColor', CLR.text2, 'FontSize', 13);
        lDir.Layout.Row = 2; lDir.Layout.Column = 1;
        H.dicDirField = uieditfield(ug, 'text', ...
            'Placeholder','Paste a folder path with numbered jpgs, or use Upload below');
        H.dicDirField.Layout.Row = 2; H.dicDirField.Layout.Column = [2 3];
        H.dicDirField.Editable = 'on';
        H.dicDirField.ValueChangedFcn = @(d,~) loadTypedDICFolder(d.Value);

        btnUploadDIC = uibutton(ug, 'Text','Upload images from your computer...', ...
            'FontSize', 13, 'BackgroundColor', CLR.accent, 'FontColor', [1 1 1]);
        btnUploadDIC.Layout.Row = 3; btnUploadDIC.Layout.Column = [1 3];
        btnUploadDIC.ButtonPushedFcn = @(~,~) uploadDICSeries();

        btnPickFolder = uibutton(ug, 'Text','...or browse for a folder', ...
            'FontSize', 12);
        btnPickFolder.Layout.Row = 4; btnPickFolder.Layout.Column = [1 3];
        btnPickFolder.ButtonPushedFcn = @(~,~) chooseDICFolder();

        uHint = uilabel(ug, 'WordWrap','on', 'FontSize', 12, 'FontColor', CLR.text3, ...
            'Text', ['Three ways to provide your "after" series: (1) click Upload to ' ...
            'multi-select images from anywhere on your computer, (2) click Browse to ' ...
            'pick a folder that already contains numbered jpgs, or (3) paste a folder ' ...
            'path directly into the field above. The reference image from step 3 can ' ...
            'be in the set — it is skipped automatically.']);
        uHint.Layout.Row = 5; uHint.Layout.Column = [1 3];

        % ---- Action card ----
        actCard = makeCard(layout, CLR);
        actCard.Layout.Row = 4;
        ag = uigridlayout(actCard, [3, 1]);
        ag.RowHeight = {'fit','fit','fit'};
        ag.Padding = [20 18 20 18];
        ag.RowSpacing = 10;

        aTitle = uilabel(ag, 'Text','Step 2 — Run digital image correlation', ...
            'FontSize', 14, 'FontWeight','bold', 'FontColor', CLR.text);
        aTitle.Layout.Row = 1;

        aDesc = uilabel(ag, 'WordWrap','on', 'FontSize', 12, 'FontColor', CLR.text2, ...
            'Text', ['Click run to track all 4 ROIs across the image series. ' ...
            'Two distances are recorded per image: distance between R1-R2 ' ...
            '(typically gel) and R3-R4 (typically spring). Takes several ' ...
            'seconds per image and opens diagnostic figures as it runs.']);
        aDesc.Layout.Row = 2;

        btnRun = uibutton(ag, 'Text','Run DIC tracking', 'FontSize', 13, ...
            'BackgroundColor', CLR.accent, 'FontColor', [1 1 1]);
        btnRun.Layout.Row = 3;
        btnRun.ButtonPushedFcn = @(~,~) runDIC();

        % ---- Plot card ----
        plotCard = makeCard(layout, CLR);
        plotCard.Layout.Row = 5;
        pg = uigridlayout(plotCard, [2,1]);
        pg.RowHeight = {'1x', 'fit'};
        pg.Padding = [16 16 16 16];
        pg.RowSpacing = 6;
        H.axes = uiaxes(pg);
        H.axes.Layout.Row = 1;
        H.axes.XLabel.String = 'Image index';
        H.axes.YLabel.String = 'Distance [px]';
        H.axes.Title.String  = 'DIC-measured distances over the load series';
        H.axes.FontSize = 11;
        plotNote = uilabel(pg, ...
            'Text', ['Note: "Image index" = the number of each frame in your ' ...
                     'uploaded series (1 = first frame after loading begins, ' ...
                     '2 = second frame, etc.). Higher index = later in the experiment.'], ...
            'WordWrap', 'on', 'FontSize', 11, 'FontColor', CLR.text2, ...
            'FontAngle', 'italic');
        plotNote.Layout.Row = 2;

        statusCard = makeStatusFooter(layout, CLR);
        statusCard.Layout.Row = 6;
        H.statusLbl = statusCard.UserData.lbl;
    end

    function setDicDir(p)
        S = fig.UserData;
        if isempty(p), S.dicDir = ''; else, S.dicDir = p; end
        fig.UserData = S;
    end

    function chooseDICFolder()
        try
            p = uigetdir(pwd, 'Select the folder containing your "after" image series');
            if isequal(p, 0), return; end
            setDICFolder(p);
        catch ME
            uialert(fig, ['Folder picker is unavailable in this environment. ' ...
                'Use Upload or paste a folder path instead. (' ME.message ')'], 'Info');
        end
    end

    function loadTypedDICFolder(p)
        if isempty(p), return; end
        if ~isfolder(p)
            uialert(fig, sprintf(['The path you entered doesn''t point to an ' ...
                'existing folder:\n\n%s\n\nDouble-check the path and try again.'], ...
                p), 'Folder not found');
            return;
        end
        setDICFolder(p);
    end

    function setDICFolder(p)
        S = fig.UserData;
        S.dicDir = p;
        fig.UserData = S;
        handles.step4.dicDirField.Value = p;
        n = numel(dir(fullfile(p, '*.jpg')));
        if n < 2
            handles.step4.statusLbl.Text = sprintf( ...
                'Warning: folder has only %d jpg(s). DIC needs at least 2.', n);
            handles.step4.statusLbl.FontColor = CLR.warn;
        else
            handles.step4.statusLbl.Text = sprintf( ...
                'Folder selected (%d jpg files): %s', n, p);
            handles.step4.statusLbl.FontColor = CLR.text2;
        end
    end

    function uploadDICSeries()
        try
            [files, path] = uigetfile({'*.jpg;*.jpeg;*.png;*.bmp;*.tif;*.tiff', ...
                'Image files'}, 'Select your "after" image series (multi-select)', ...
                'MultiSelect','on');
            if isequal(files, 0), return; end
            if ischar(files), files = {files}; end

            if numel(files) < 2
                uialert(fig, ['DIC tracking needs at least 2 images: one ' ...
                    'reference frame and one or more "after" frames. ' ...
                    'You only selected 1 image. ' ...
                    'Use Ctrl-click or Shift-click to select multiple files.'], ...
                    'Need more images');
                return;
            end

            % Copy the chosen files into a fresh temp folder named with
            % sequential 000N.jpg names so DIC_distance_calculation (which
            % reads a numbered folder) works regardless of original names.
            % The underlying DIC routine does jpgCount = numel(jpgFiles) - 1
            % (subtracts one to treat the first jpg as a reference), so to
            % make sure ALL of the user's selected frames get processed we
            % duplicate the last frame at index N+1. The loop then walks
            % indices 1..N, hitting every original frame.
            tmpDir = fullfile(tempdir, sprintf('dic_series_%s', ...
                datestr(now,'yyyymmdd_HHMMSS')));
            if ~exist(tmpDir, 'dir'), mkdir(tmpDir); end
            % Sort filenames so the sequence is preserved
            files = sort(files);
            N = numel(files);
            for k = 1:N
                src = fullfile(path, files{k});
                dst = fullfile(tmpDir, sprintf('%04d.jpg', k));
                copyfile(src, dst);
            end
            % Duplicate the last frame as the (N+1)th file so DIC's
            % off-by-one trim doesn't drop the user's actual last frame.
            srcLast = fullfile(path, files{end});
            dstExtra = fullfile(tmpDir, sprintf('%04d.jpg', N + 1));
            copyfile(srcLast, dstExtra);

            S = fig.UserData;
            S.dicDir = [tmpDir filesep];
            S.dicSeriesPaths = cellfun(@(f) fullfile(path, f), files, 'uni', false);
            fig.UserData = S;
            handles.step4.dicDirField.Value = S.dicDir;
            handles.step4.statusLbl.Text = sprintf( ...
                'Uploaded %d images. First one will be used as reference; %d more will be tracked.', ...
                numel(files), numel(files)-1);
            handles.step4.statusLbl.FontColor = CLR.text2;
        catch ME
            uialert(fig, sprintf('Upload failed: %s', ME.message), 'Error');
        end
    end

    function runDIC()
        S = fig.UserData;
        if isempty(S.pattern)
            uialert(fig, 'Step 3 (ROI selection) needs to be completed first.', 'Missing ROIs');
            return;
        end
        dicDir = '';
        if isfield(S,'dicDir') && ~isempty(S.dicDir), dicDir = S.dicDir; end
        if isempty(dicDir), dicDir = S.imgDir; end
        if isempty(dicDir) || ~isfolder(dicDir)
            uialert(fig, 'No image folder provided. Upload the "after" image series above.', ...
                'Missing folder');
            return;
        end
        % Make sure dicDir ends in a separator (DIC_distance_calculation uses string concat)
        if dicDir(end) ~= filesep, dicDir = [dicDir filesep]; end

        % Verify the folder actually contains numbered jpg files
        jpgFiles = dir(fullfile(dicDir, '*.jpg'));
        if numel(jpgFiles) < 2
            uialert(fig, sprintf(['DIC tracking needs at LEAST 2 images: one to ' ...
                'serve as the reference and one or more "after" frames to track.\n\n' ...
                'Found only %d image(s) in:\n%s\n\n' ...
                'Please upload your full image series (the reference + all the ' ...
                'frames captured during loading).'], numel(jpgFiles), dicDir), ...
                'Need more images');
            return;
        end

        d = uiprogressdlg(fig, 'Title','Running DIC', ...
            'Message', sprintf('Tracking patterns across %d images...', numel(jpgFiles)-1), ...
            'Indeterminate','on');
        cleanupObj = onCleanup(@() close(d));
        try
            S.distance = DIC_distance_calculation(dicDir, S.pattern);
            fig.UserData = S;

            % If DIC returned empty, treat it as a failure with a clear msg.
            if isempty(S.distance) || size(S.distance, 1) == 0
                uialert(fig, ['DIC produced no measurements. This usually means ' ...
                    'the image folder only contained the reference image with no ' ...
                    'frames to track. Upload more frames and try again.'], ...
                    'No frames tracked');
                return;
            end

            h = handles.step4;
            cla(h.axes);
            plot(h.axes, S.distance(:,1), '-o', 'Color', CLR.info, 'LineWidth', 1.5);
            hold(h.axes, 'on');
            if size(S.distance, 2) >= 2
                plot(h.axes, S.distance(:,2), '-o', 'Color', CLR.accent, 'LineWidth', 1.5);
                legend(h.axes, {'R1-R2 distance','R3-R4 distance'},'Location','best');
            end
            hold(h.axes, 'off');
            refreshStep4();
            h.statusLbl.Text = sprintf('DIC complete · %d images tracked.', size(S.distance,1));
            h.statusLbl.FontColor = CLR.success;
        catch ME
            uialert(fig, sprintf('DIC tracking failed:\n\n%s', ME.message), 'DIC Error');
        end
    end


    % =====================================================================
    % STEP 5: UNIT CONVERSION
    % =====================================================================
    function H = buildStep5_UnitConversion(parent, CLR)
        layout = uigridlayout(parent, [4, 1]);
        layout.RowHeight = {'fit', 'fit', 480, 'fit'};
        layout.ColumnWidth = {'1x'};
        layout.RowSpacing = 16;
        layout.Scrollable = 'on';

        headerCard = makeStepHeader(layout, '05', 'Unit conversion', ...
            ['Combine the spring and pixel calibrations to convert DIC distances ' ...
             'into mm and force in grams.'], CLR);
        headerCard.Layout.Row = 1;

        inputCard = makeCard(layout, CLR);
        inputCard.Layout.Row = 2;
        ig = uigridlayout(inputCard, [3, 6]);
        ig.RowHeight = {'fit','fit','fit'};
        ig.ColumnWidth = {'fit', 100, 'fit', 100, 'fit', 100};
        ig.Padding = [20 16 20 16];
        ig.ColumnSpacing = 10;
        ig.RowSpacing = 10;

        l1 = uilabel(ig, 'Text','Width (mm)', 'FontColor', CLR.text2, 'FontWeight','bold');
        l1.Layout.Row = 1; l1.Layout.Column = 1;
        H.widthField = uieditfield(ig, 'numeric', 'Value', 24.0);
        H.widthField.Layout.Row = 1; H.widthField.Layout.Column = 2;
        H.widthField.ValueChangedFcn = @(d,~) updateHydrogel('width', d.Value);

        l2 = uilabel(ig, 'Text','Thickness (mm)', 'FontColor', CLR.text2, 'FontWeight','bold');
        l2.Layout.Row = 1; l2.Layout.Column = 3;
        H.thicknessField = uieditfield(ig, 'numeric', 'Value', 5.38);
        H.thicknessField.Layout.Row = 1; H.thicknessField.Layout.Column = 4;
        H.thicknessField.ValueChangedFcn = @(d,~) updateHydrogel('thickness', d.Value);

        l3 = uilabel(ig, 'Text','Length (mm)', 'FontColor', CLR.text2, 'FontWeight','bold');
        l3.Layout.Row = 1; l3.Layout.Column = 5;
        H.lengthField = uieditfield(ig, 'numeric', 'Value', 7.304);
        H.lengthField.Layout.Row = 1; H.lengthField.Layout.Column = 6;
        H.lengthField.ValueChangedFcn = @(d,~) updateHydrogel('length', d.Value);

        btnConv = uibutton(ig, 'Text','Run unit conversion →', ...
            'BackgroundColor', CLR.accent, 'FontColor', [1 1 1], 'FontSize', 13);
        btnConv.Layout.Row = 2; btnConv.Layout.Column = [1 6];
        btnConv.ButtonPushedFcn = @(~,~) runConv();

        H.sortCheck = uicheckbox(ig, ...
            'Text', ['  Sort points by deformation before plotting   ' ...
                     '(diagnostic: use only if image series was uploaded out of order)'], ...
            'Value', false, ...
            'FontSize', 12, ...
            'FontColor', CLR.text2);
        H.sortCheck.Layout.Row = 3; H.sortCheck.Layout.Column = [1 6];

        % Plots
        plotCard = makeCard(layout, CLR);
        plotCard.Layout.Row = 3;
        pg = uigridlayout(plotCard, [1, 2]);
        pg.Padding = [16 16 16 16];
        pg.ColumnSpacing = 16;
        H.axesSpring = uiaxes(pg);
        H.axesSpring.XLabel.String = 'Deformation [mm]';
        H.axesSpring.YLabel.String = 'Force [g]';
        H.axesSpring.Title.String  = 'Spring';
        H.axesGel = uiaxes(pg);
        H.axesGel.XLabel.String = 'Deformation [mm]';
        H.axesGel.YLabel.String = 'Force [g]';
        H.axesGel.Title.String  = 'Hydrogel';

        statusCard = makeStatusFooter(layout, CLR);
        H.statusLbl = statusCard.UserData.lbl;
    end

    function updateHydrogel(field, val)
        S = fig.UserData;
        S.hydrogel.(field) = val;
        fig.UserData = S;
    end

    function runConv()
        S = fig.UserData;
        if isempty(S.distance) || isempty(S.spring_calibration) || isempty(S.dist2px_calibration)
            uialert(fig, 'Need spring calibration, px calibration, and DIC distances.', ...
                'Missing prerequisites'); return;
        end
        try
            S.data = unit_coversion(S.distance, S.spring_calibration, S.dist2px_calibration);

            % Optional diagnostic: sort the spring and gel curves by ascending
            % deformation. This is a band-aid for image series uploaded out
            % of order — it does NOT fix true non-monotonic behavior
            % (hysteresis, mis-tracking). The sorted data is stored back
            % into S.data so Step 6 inherits it.
            sortedFlag = false;
            try
                if handles.step5.sortCheck.Value
                    [S.data.d_s, idxS] = sort(S.data.d_s(:));
                    fs = S.data.f_s(:); S.data.f_s = fs(idxS);
                    [S.data.d_g, idxG] = sort(S.data.d_g(:));
                    fg = S.data.f_g(:); S.data.f_g = fg(idxG);
                    sortedFlag = true;
                end
            catch
            end

            fig.UserData = S;
            h = handles.step5;
            cla(h.axesSpring); cla(h.axesGel);
            plot(h.axesSpring, S.data.d_s, S.data.f_s, '-o', ...
                'Color', CLR.info, 'LineWidth', 1.5);
            plot(h.axesGel, S.data.d_g, S.data.f_g, '-o', ...
                'Color', CLR.accent, 'LineWidth', 1.5);
            if sortedFlag
                title(h.axesSpring, 'Spring (sorted by deformation)');
                title(h.axesGel, 'Hydrogel (sorted by deformation)');
            else
                title(h.axesSpring, 'Spring');
                title(h.axesGel, 'Hydrogel');
            end
            refreshStep5();
        catch ME
            uialert(fig, sprintf('Unit conversion failed: %s', ME.message), 'Error');
        end
    end


    % =====================================================================
    % STEP 6: MLE FIT & FINAL RESULT
    % =====================================================================
    function H = buildStep6_MLEFit(parent, CLR)
        layout = uigridlayout(parent, [4, 1]);
        layout.RowHeight = {'fit', 'fit', 480, 'fit'};
        layout.ColumnWidth = {'1x'};
        layout.RowSpacing = 16;
        layout.Scrollable = 'on';

        headerCard = makeStepHeader(layout, '06', 'MLE fit & elastic modulus', ...
            ['Maximum likelihood fit of stress vs strain yields the elastic ' ...
             'modulus of the hydrogel.'], CLR);
        headerCard.Layout.Row = 1;

        ctrlCard = makeCard(layout, CLR);
        ctrlCard.Layout.Row = 2;
        cg = uigridlayout(ctrlCard, [2, 2]);
        cg.RowHeight = {'fit', 'fit'};
        cg.ColumnWidth = {'1x','fit'};
        cg.Padding = [20 16 20 16];
        cg.RowSpacing = 10;
        H.infoLbl = uilabel(cg, ...
            'Text','Uses stress/strain derived from step 5.', ...
            'FontColor', CLR.text2);
        H.infoLbl.Layout.Row = 1; H.infoLbl.Layout.Column = 1;
        btnRun = uibutton(cg, 'Text','Run MLE fit →', ...
            'BackgroundColor', CLR.accent, 'FontColor', [1 1 1], 'FontSize', 13);
        btnRun.Layout.Row = 1; btnRun.Layout.Column = 2;
        btnRun.ButtonPushedFcn = @(~,~) runMLE();

        H.sortCheck = uicheckbox(cg, ...
            'Text', ['  Sort points by strain before fitting   ' ...
                     '(diagnostic: use only if image series was uploaded out of order)'], ...
            'Value', false, ...
            'FontSize', 12, ...
            'FontColor', CLR.text2);
        H.sortCheck.Layout.Row = 2; H.sortCheck.Layout.Column = [1 2];

        plotCard = makeCard(layout, CLR);
        plotCard.Layout.Row = 3;
        pg = uigridlayout(plotCard, [2, 1]);
        pg.RowHeight = {'1x', 80};
        pg.Padding = [16 16 16 16];
        H.axes = uiaxes(pg);
        H.axes.XLabel.String = 'Strain [mm/mm]';
        H.axes.YLabel.String = 'Stress [MPa]';
        H.axes.Title.String  = 'Stress–strain fit';

        resultBox = uipanel(pg, 'BorderType','line', ...
            'BackgroundColor', CLR.successBg, 'Title','Elastic modulus');
        resultBox.Layout.Row = 2;
        rg = uigridlayout(resultBox, [1,2]);
        rg.ColumnWidth = {'1x', 'fit'};
        rg.Padding = [16 8 16 8];
        H.resultLbl = uilabel(rg, 'Text','Run MLE to compute E_gel', ...
            'FontSize', 18, 'FontWeight','bold', 'FontColor', CLR.success);
        btnExport = uibutton(rg, 'Text','Export all results', ...
            'FontSize', 13);
        btnExport.ButtonPushedFcn = @(~,~) exportAll();

        statusCard = makeStatusFooter(layout, CLR);
        H.statusLbl = statusCard.UserData.lbl;
    end

    function runMLE()
        S = fig.UserData;
        if isempty(S.data)
            uialert(fig, 'Run unit conversion in step 5 first.', 'Missing data'); return;
        end
        try
            length_g = S.hydrogel.length;
            A_g = S.hydrogel.width * S.hydrogel.thickness;
            strain_g = S.data.d_g / length_g;
            stress_g = S.data.f_g * 10 / 1000 / A_g;     % MPa

            % If the sort-by-strain diagnostic toggle is on, reorder both
            % vectors by ascending strain before fitting. This is a band-aid
            % for image series uploaded out of order — it does NOT fix true
            % non-monotonic behavior (hysteresis, mis-tracking).
            sortedFlag = false;
            try
                if handles.step6.sortCheck.Value
                    [strain_g, sortIdx] = sort(strain_g(:));
                    stress_g = stress_g(:);
                    stress_g = stress_g(sortIdx);
                    sortedFlag = true;
                end
            catch
            end

            Dat.x = strain_g; Dat.y = stress_g;
            Dat.lb = 0; Dat.ub = 1e10;
            Dat.error = 0;
            Dat.theta_nom = S.spring_calibration.means(2);
            Dat.index = 1;

            S.fit_results = MLE(Dat);
            fig.UserData = S;

            % Plot
            h = handles.step6;
            cla(h.axes);
            plot(h.axes, strain_g, stress_g, 'o-', ...
                'Color', CLR.info, 'LineWidth', 1.5, 'MarkerSize', 6);
            hold(h.axes, 'on');
            Y_pred = (strain_g - strain_g(1)) * S.fit_results.theta_MLE + stress_g(1);
            plot(h.axes, strain_g, Y_pred, '--', ...
                'Color', CLR.accent, 'LineWidth', 2);
            dataLabel = 'Data';
            if sortedFlag, dataLabel = 'Data (sorted by strain)'; end
            legend(h.axes, {dataLabel, ...
                sprintf('Linear fit: E = %.2f kPa', S.fit_results.theta_MLE*1000)}, ...
                'Location','best');
            hold(h.axes, 'off');

            refreshStep6();
        catch ME
            uialert(fig, sprintf('MLE failed: %s', ME.message), 'Error');
        end
    end

    function exportAll()
        S = fig.UserData;
        if isempty(S.fit_results)
            uialert(fig, 'Nothing to export — run MLE first.', 'Empty'); return;
        end
        try
            [file, path] = uiputfile({'*.mat'; '*.csv'}, ...
                'Save results', 'block_analysis_results');
            if isequal(file, 0), return; end
            outFile = fullfile(path, file);
            results.spring_calibration = S.spring_calibration;
            results.dist2px_calibration = S.dist2px_calibration;
            results.pattern = S.pattern;
            results.distance = S.distance;
            results.data = S.data;
            results.fit_results = S.fit_results;
            results.E_gel_MPa = S.fit_results.theta_MLE;
            results.E_gel_kPa = S.fit_results.theta_MLE * 1000;
            results.hydrogel = S.hydrogel;
            [~,~,ext] = fileparts(file);
            if strcmpi(ext, '.csv')
                T = table([S.data.d_g(:)], [S.data.f_g(:)], ...
                          'VariableNames', {'Deformation_mm','Force_g'});
                writetable(T, outFile);
            else
                save(outFile, 'results');
            end
            uialert(fig, sprintf('Saved to %s', outFile), 'Exported', 'Icon','success');
        catch ME
            uialert(fig, sprintf('Export failed: %s', ME.message), 'Error');
        end
    end

end

% =========================================================================
% =========================================================================
%                    LOCAL UI-BUILDING HELPERS
% =========================================================================
% =========================================================================

function p = makeCard(parent, CLR)
    p = uipanel(parent, 'BorderType','line', ...
                       'BackgroundColor', CLR.surface);
end

function p = makeStepHeader(parent, num, title, subtitle, CLR)
    p = uipanel(parent, 'BorderType','none', 'BackgroundColor', CLR.bg);
    g = uigridlayout(p, [2, 2]);
    g.RowHeight = {'fit', 'fit'};
    g.ColumnWidth = {'fit', '1x'};
    g.Padding = [0 0 0 8];
    g.ColumnSpacing = 14;
    g.RowSpacing = 4;
    pill = uilabel(g, 'Text', sprintf(' STEP %s ', num), ...
        'FontWeight','bold', 'FontSize', 11, ...
        'FontColor', CLR.pillFg, 'BackgroundColor', CLR.pillBg, ...
        'HorizontalAlignment','center', 'VerticalAlignment','center');
    pill.Layout.Row = 1; pill.Layout.Column = 1;
    titleLbl = uilabel(g, 'Text', title, 'FontSize', 22, 'FontWeight','bold', ...
        'FontColor', CLR.text);
    titleLbl.Layout.Row = 1; titleLbl.Layout.Column = 2;
    subLbl = uilabel(g, 'Text', subtitle, 'FontSize', 13, 'FontColor', CLR.text2);
    subLbl.Layout.Row = 2; subLbl.Layout.Column = [1 2];
    subLbl.WordWrap = 'on';
end

function p = makeStatusFooter(parent, CLR)
    p = uipanel(parent, 'BorderType','line', 'BackgroundColor', CLR.surface2);
    g = uigridlayout(p, [1, 1]);
    g.Padding = [14 10 14 10];
    lbl = uilabel(g, 'Text','Ready', 'FontSize', 12, 'FontColor', CLR.text2);
    p.UserData = struct('lbl', lbl);
end

function btn = makeSidebarStep(parent, num, label, CLR)
    btn = uibutton(parent, 'Text', sprintf('  %s   %s', num, label), ...
        'FontSize', 13, ...
        'BackgroundColor', CLR.surface2, 'FontColor', CLR.text2, ...
        'HorizontalAlignment','left');
end

function tagBtn(btn, isActive, CLR)
    checkColor = CLR.success;   % berry-purple, matches sunset palette
    hasCheck   = contains(btn.Text, '✓');
    if isActive
        btn.BackgroundColor = CLR.surface;
        if hasCheck
            btn.FontColor = checkColor;
        else
            btn.FontColor = CLR.accent;
        end
        btn.FontWeight  = 'bold';
    else
        btn.BackgroundColor = CLR.surface2;
        if hasCheck
            btn.FontColor  = checkColor;
            btn.FontWeight = 'normal';
        else
            btn.FontColor  = CLR.text2;
            btn.FontWeight = 'normal';
        end
    end
end

% =========================================================================
% Render a reference image with labelled ROI rectangles into an axes,
% using image() (not imshow) so it never disturbs the parent figure state.
% =========================================================================
function renderRegionsPreview(ax, img, rects, color)
    if isempty(img), return; end
    cla(ax, 'reset');
    if size(img,3) == 1, img = repmat(img, [1 1 3]); end
    image(ax, img);
    ax.YDir = 'reverse';
    ax.DataAspectRatio = [1 1 1];
    ax.XLim = [0.5 size(img,2)+0.5];
    ax.YLim = [0.5 size(img,1)+0.5];
    ax.XTick = []; ax.YTick = [];
    hold(ax, 'on');
    for r = 1:size(rects,1)
        rectangle(ax, 'Position', rects(r,:), 'EdgeColor', color, 'LineWidth', 2);
        text(ax, rects(r,1), max(1, rects(r,2)-12), sprintf('R%d', r), ...
            'Color', color, 'FontWeight','bold', 'FontSize', 13);
    end
    hold(ax, 'off');
end


function updateSidebarDone(btn, CLR)
    % Add a sunset-purple checkmark hint to the text. Uses CLR.success
    % (berry) so the "done" indicator stays in the sunset palette.
    if ~contains(btn.Text, '✓')
        btn.Text = [btn.Text, '   ✓'];
    end
    btn.FontColor = CLR.success;
end


% =========================================================================
% Recursively apply a font family to every text-bearing UI component
% =========================================================================
function applySerifFontRecursive(node, fontName)
    if ~isvalid(node), return; end
    try
        if isprop(node, 'FontName')
            node.FontName = fontName;
        end
    catch
    end
    try
        kids = node.Children;
    catch
        kids = [];
    end
    for k = 1:numel(kids)
        applySerifFontRecursive(kids(k), fontName);
    end
end


% =========================================================================
% In-app ROI rectangle picker — returns the same struct as ROI_selection.m
% =========================================================================
function out = drawROIsInModal(refPath)
    out = [];

    scaleFactor = 2;
    refImg = imread(refPath);
    if size(refImg, 3) > 1, refImg = rgb2gray(refImg); end
    refImg = imresize(refImg, scaleFactor, 'lanczos3');
    [H, W] = size(refImg);

    aspect = W / H;
    winW = min(1200, max(800, round(820 * aspect)));
    winH = min(900,  round(winW / aspect) + 160);

    modal = uifigure('Name', 'ROI selection — Draw 4 regions', ...
        'Position', [60 60 winW winH], 'WindowStyle', 'normal');
    movegui(modal, 'center');

    g = uigridlayout(modal, [3, 1]);
    g.RowHeight = {'fit', '1x', 'fit'};
    g.Padding = [12 12 12 12];

    titleLbl = uilabel(g, 'Text', 'Region R1 — Click and drag to draw a rectangle', ...
        'FontSize', 15, 'FontWeight','bold');
    titleLbl.Layout.Row = 1;

    ax = uiaxes(g);
    ax.Layout.Row = 2;
    image(ax, repmat(refImg, [1 1 3]));
    ax.YDir = 'reverse';
    ax.DataAspectRatio = [1 1 1];
    ax.XLim = [0.5 W+0.5]; ax.YLim = [0.5 H+0.5];
    ax.XTick = []; ax.YTick = [];
    ax.Toolbar.Visible = 'off';
    disableDefaultInteractivity(ax);

    ctrlPanel = uipanel(g, 'BorderType','none');
    ctrlPanel.Layout.Row = 3;
    cg = uigridlayout(ctrlPanel, [1, 3]);
    cg.ColumnWidth = {'1x','fit','fit'};
    cg.Padding = [0 6 0 0];
    statusLbl = uilabel(cg, 'Text','Drag a rectangle for R1 (1/4)', 'FontSize', 13);
    btnReset = uibutton(cg, 'Text','Start over');
    btnCancel= uibutton(cg, 'Text','Cancel', 'FontColor', [0.64 0.18 0.18]);

    rects     = zeros(0, 4);
    regionsC  = cell(1, 4);
    cancelled = false;

    btnReset.ButtonPushedFcn = @(~,~) doReset();
    btnCancel.ButtonPushedFcn= @(~,~) doCancel();
    modal.CloseRequestFcn    = @(~,~) doCancel();

    % Sequential draw loop. drawrectangle() blocks until the user finishes
    % dragging, so this naturally walks through R1 -> R2 -> R3 -> R4.
    while size(rects, 1) < 4 && ~cancelled && isvalid(modal)
        i = size(rects, 1) + 1;
        titleLbl.Text = sprintf('Region R%d — Click and drag to draw a rectangle', i);
        statusLbl.Text = sprintf('Drag a rectangle for R%d (%d/4)', i, i);
        drawnow;

        try
            roi = drawrectangle(ax, 'Color', [0.2 0.8 0.4], 'LineWidth', 2, ...
                'Label', sprintf('R%d', i), 'LabelAlpha', 0.7);
        catch
            cancelled = true;
            break;
        end

        if ~isvalid(modal), break; end
        if isempty(roi) || ~isvalid(roi), continue; end

        pos = round(roi.Position);
        if numel(pos) ~= 4 || pos(3) < 4 || pos(4) < 4
            delete(roi);
            uialert(modal, 'Rectangle too small — drag a larger box.', 'Tiny ROI');
            continue;
        end

        rects(end+1, :) = pos;  %#ok<AGROW>
        xs = max(1, pos(1)) : min(W, pos(1) + pos(3));
        ys = max(1, pos(2)) : min(H, pos(2) + pos(4));
        regionsC{size(rects,1)} = refImg(ys, xs);

        % Replace the interactive ROI with a static rectangle for the gallery
        delete(roi);
        rectangle(ax, 'Position', pos, 'EdgeColor', [0 0.62 0.46], 'LineWidth', 2);
        text(ax, pos(1)+4, pos(2)+12, sprintf('R%d', size(rects,1)), ...
            'Color', [0 0.62 0.46], 'FontWeight','bold', 'FontSize', 13);
    end

    if cancelled || size(rects, 1) < 4
        out = [];
    else
        out.regions = regionsC;
        out.rects   = rects;
        out.scale   = scaleFactor;
    end
    if isvalid(modal), delete(modal); end


    function doReset()
        rects = zeros(0, 4);
        regionsC = cell(1, 4);
        cla(ax);
        image(ax, repmat(refImg, [1 1 3]));
        ax.YDir = 'reverse'; ax.DataAspectRatio = [1 1 1];
        ax.XLim = [0.5 W+0.5]; ax.YLim = [0.5 H+0.5];
        ax.XTick = []; ax.YTick = [];
    end

    function doCancel()
        cancelled = true;
        % If we're in the middle of drawrectangle, deleting the modal will
        % cause it to error/return.
        if isvalid(modal), delete(modal); end
    end
end

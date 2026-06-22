function out = ROI_selection(imgDir)

    % Script 1: Select Patterns (R1, R2, R3, R4)
    
    % 1. Load the reference image
    scaleFactor = 2; % Increase resolution by 2x (use 3 or 4 for higher)
    refImg = imread([imgDir,'reference.jpg']);
    
    % 1. Convert and Upscale
    if size(refImg, 3) > 1, refImg = rgb2gray(refImg); end
    % Use 'bicubic' or 'lanczos3' for better detail preservation
    refImg = imresize(refImg, scaleFactor, 'lanczos3');
    
    % 2. Create the figure and display the image
    figure('Name', 'ROI Selection Tool');
    imshow(refImg); 
    hold on; % This allows multiple rectangles to be drawn over the image
    title('Select 4 Regions: Click and drag for each');
    
    regions = cell(1, 4);
    rects = zeros(4, 4); % [xmin ymin width height]
    
    for i = 1:4
        % Update title to guide the user
        title(['Select Region R', num2str(i), ' (Click and Drag)']);
        
        % getrect is the "legacy" version that works on all MATLAB versions
        % It returns [xmin ymin width height]
        % rects(i, :) = round(uidraw(viewer,"rectangle")); 
        rects(i, :) = round(getrect); 
        
        % Draw the rectangle on the screen so you know what you've already picked
        rectangle('Position', rects(i, :), 'EdgeColor', 'g', 'LineWidth', 2);
        text(rects(i,1), rects(i,2)-10, ['R', num2str(i)], 'Color', 'g', 'FontWeight', 'bold');
        
        % Crop the template from the image
        regions{i} = imcrop(refImg, rects(i, :));
    end
    
    % 3. Save data for the second script
    % save('DIC_Patterns_1_v2.mat', 'regions', 'rects','scaleFactor');
    disp('Patterns R1-R4 saved successfully. You can now run Script 2.');
    close 'ROI Selection Tool'
    
    out.regions = regions;
    out.rects   = rects;
    out.scale   = scaleFactor;

end
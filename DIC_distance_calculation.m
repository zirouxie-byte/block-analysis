function out = DIC_distance_calculation(imgDir,pattern)

    % Script 2: Perform DIC and Calculate Distances
    
    regions     = pattern.regions;
    scaleFactor = pattern.scale;
    
    %% Count number of images
    % Target only .jpg files in this directory
    jpgFiles = dir(fullfile(imgDir, '*.jpg'));
    
    % Count the number of elements in the structure
    jpgCount = numel(jpgFiles) - 1; % Remove reference
    
    out = zeros(jpgCount,2);

    for i = 1:jpgCount
        
        if i < 10;      imgName = sprintf('000%.i.jpg',i);
        elseif i < 100; imgName = sprintf('00%.i.jpg',i);
        end

        targetImg = imread([imgDir,imgName]);
        
        % 1. Match the Pre-processing of Script 1
        if size(targetImg, 3) > 1, targetImg = rgb2gray(targetImg); end
        targetImg = imresize(targetImg, scaleFactor, 'lanczos3');
        
        % 3. Manually select Search Area
        figure('Name', 'Define Search Area');
        imshow(targetImg);
        title('Drag a box around the area where R1-R4 are located');
        % searchRect = round(getrect); % [xmin ymin width height]
        searchRect = [0 0 size(targetImg, 2) size(targetImg, 1)];
        hold on;
        rectangle('Position', searchRect, 'EdgeColor', 'y', 'LineWidth', 2, 'LineStyle', ':');
        
        % Crop the target image to just the search area
        searchZone = imcrop(targetImg, searchRect);
        
        matchedCentroids = zeros(4, 2); % To store [x, y] centers
        
        figure('Name', 'DIC Results');
        imshow(targetImg); hold on;
        
        for j = 1:4
            template = regions{j};
        
            % FIX: Ensure template is 2D (Grayscale)
            if size(template, 3) > 1
                template = rgb2gray(template);
            end
            
            [tH, tW] = size(template);
            
            % 2. Normalized 2D Cross-Correlation
            c = normxcorr2(template, searchZone);
            
            % 3. Find the peak correlation point
            [max_c, imax] = max(c(:));
            [ypeak, xpeak] = ind2sub(size(c), imax(1));
            
            % 4. Adjust coordinates
            % normxcorr2 padding offset: peak is at (rect + template_size - 1)
            % We calculate the top-left corner of the match:
            match_xmin_local = xpeak - tW + 1;
            match_ymin_local = ypeak - tH + 1;
            
            % Convert local searchZone coordinates back to global Image coordinates
            % Global = Local + SearchRect_Offset
            match_xmin_global = match_xmin_local + searchRect(1);
            match_ymin_global = match_ymin_local + searchRect(2);
        
            % Calculate the center of that matched box
            matchedCentroids(j, :) = [match_xmin_global + tW/2, ...
                                      match_ymin_global + tH/2];
            
            % Draw detected region on the full image
            rectangle('Position', [match_xmin_global, match_ymin_global, tW, tH], ...
                      'EdgeColor', 'g', 'LineWidth', 1);
            text(match_xmin_global, match_ymin_global-5, ['R', num2str(j)], 'Color', 'y');
        end
        
        % 4. Calculate distances in High-Res Pixels
        % Formula: sqrt((x2-x1)^2 + (y2-y1)^2)
        dist12_HR = norm(matchedCentroids(2, :) - matchedCentroids(1, :));
        dist34_HR = norm(matchedCentroids(4, :) - matchedCentroids(3, :));
        
        % 5. Convert back to "Original" Pixel distances
        dist12_Actual = dist12_HR / scaleFactor;
        dist34_Actual = dist34_HR / scaleFactor;
        
        % 6. Display Results
        line(matchedCentroids(1:2,1), matchedCentroids(1:2,2), 'Color', 'r', 'LineWidth', 2);
        line(matchedCentroids(3:4,1), matchedCentroids(3:4,2), 'Color', 'b', 'LineWidth', 2);
        
        % Results display
        fprintf('--- High-Res DIC Results (Scale: %dx) ---\n', scaleFactor);
        fprintf('Distance 1-2: %.4f original pixels\n', dist12_Actual);
        fprintf('Distance 3-4: %.4f original pixels\n', dist34_Actual);

        out(i,1) = dist12_Actual;
        out(i,2) = dist34_Actual;

    end

end
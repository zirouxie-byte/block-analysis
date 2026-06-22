function [Sob_1, Sob_2] = sobol_indices_group(theta, theta_aux, h, output, groups)

%% Sobol Indices

%% 0. DEFINE GROUPS
% Define which parameter indices belong to which independent groups.
% Example: Parameters 1 and 2 are correlated (Group 1). 
% Parameters 3 and 4 are independent (Groups 2 and 3).
% groups = {[1, 2], [3], [4]}; 
n_groups = length(groups);

%% MONTE CARLO ITERATIONS
N = size(theta, 1);         % Number of samples
fo = mean(output);          % mean
D  = (std(output)).^2;      % variance

%% 2. FIRST ORDER INDICES (BY GROUP)
Sob_1 = zeros(n_groups, size(output, 2));

for j = 1:n_groups
    % Pass the specific group's indices to the function
    c_out_1 = f_1_group(output, theta_aux, theta, groups{j}, N, h);
    Dz      = mean(c_out_1)/2;
    Dy      = D - Dz;
    Sob_1(j,:) = Dy ./ D;   % First order index for the GROUP
end

%% 3. SECOND ORDER INDICES (BETWEEN GROUPS)
kk = 1;
Ind = [];
for ii = 1:n_groups-1      % Combination of 2 groups
    for jj = ii+1:n_groups
        Ind(:,kk) = [ii; jj];
        kk = kk+1;
    end
end   

if ~isempty(Ind)
    mm = size(Ind, 2);
    n_out = size(output, 2);
    Sob_2a = zeros(mm, n_out);
    Sob_2  = zeros(mm, n_out);

    for k = 1:mm
        % Pass both groups to form the combined subset
        c_out_2 = f_2_group(output, groups, Ind, theta_aux, theta, N, k, h);
        Dz      = mean(c_out_2)/2;
        Dy      = D - Dz;
        Sob_2a(k,:) = Dy ./ D;
    end

    for k = 1:mm
        % Subtract the first-order effects of the individual groups
        Sob_2(k,:) = Sob_2a(k,:) - Sob_1(Ind(1,k),:) - Sob_1(Ind(2,k),:);
    end
end


function out = calibration_px2dist(dist2px_data)

distanceCommon  = dist2px_data.d';
pixels          = dist2px_data.px';

parameters.pixels    = pixels;
parameters.distances = distanceCommon;
parameters.acc_inst  = 0.01;                      % fixed instrument uncertainty [mm];
parameters.N_samples = 40000;                     % Samples to MCMC
parameters.N_burnin  = 4000;                      % Burn-in period
parameters.print     = 1;                           % Print MCMC samples (1 - Yes, 0 - No)
parameters.jump      = [0.025, 0.002, 0.4, 0.4]; %(tune to get ~35-50% acceptance per parameter)

%% Analysis
out_MCMC      = pixel_disp_fitting(parameters); % posterior for alpha, beta, e_p and e_d
parameters.print = 0;
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

%% Output Results

out.samples = out_MCMC;
out.means   = mean(out_MCMC);
out.sobol1 = Sobol_set1;
out.sobol2 = Sobol_set2;
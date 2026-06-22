function out = calibration_spring(spring_data)

%% Extract data

d       = spring_data.d;
force   = spring_data.f;
sp      = spring_data.sp;

%% Bayesian Distance-to-Force Calibration
%  Model:  d = D + e_d,               e_d ~ N(0, sigma_d^2)
%          F = alpha + beta*d + e_f,  e_f ~ N(0, sigma_f^2)
%          sigma_d = sqrt(sigma_d_r^2 + sigma_inst^2)
%          sigma_f = sqrt(sigma_f_r^2 + sigma_inst^2)
%
%  Sampling: component-wise Metropolis-Hastings on log-transformed params
%  Parameters: theta = [alpha, beta, sigma_f, sigma_f_r]

parameters.distances = d;
parameters.forces    = force;
parameters.acc_inst_d= 0.01;                      % fixed instrument uncertainty [mm];
parameters.acc_inst_f= 0.01;                      % fixed instrument uncertainty [g];
parameters.N_samples = 20000;                     % Samples to MCMC
parameters.N_burnin  = 4000;                      % Burn-in period
parameters.print     = 1;                           % Print MCMC samples (1 - Yes, 0 - No)

%(tune to get ~35-50% acceptance per parameter)
if sp == 1; parameters.jump      = [0.05, 0.006, 2, 0.4];
elseif sp == 2; parameters.jump  = [0.1, 0.01, 2, 0.4];
elseif sp == 3; parameters.jump  = [0.1, 0.01, 2, 0.4];
end

%% Analysis
out2      = disp_foce_fitting(parameters); % posterior for alpha, beta, e_p and e_d
parameters.print     = 0;
out2_aux  = disp_foce_fitting(parameters); % posterior for alpha, beta, e_p and e_d
alpha = out2(:,1);
beta  = out2(:,2);
e_d   = out2(:,3);
e_f   = out2(:,4);

% figure
% plot(alpha,beta,'r.')

%% 

distance_set = 0.050:0.050:0.400; n = length(distance_set);

groups = {[1, 2], [3], [4]};
theta       = out2;
theta_aux   = out2_aux;

R = corrcoef(out2);
disp('Posterior Correlation Matrix:');
disp(R); % Check for correlations before computing Sobol Indices

Sobol_set1 = zeros(3,n);
Sobol_set2 = zeros(3,n);

for j = 1:n

    % The distance for a new pixel is:
    d_new = distance_set(j);                        % distance
    % d_new  = alpha + beta .* (d_new + e_d);       % corresponding force [g]
    f_new  = alpha + beta .* (d_new + e_d) + e_f;   % corresponding force [g]
    
    if distance_set(j) == 250
        figure
        histogram(f_new,'Normalization','pdf')
        xlabel('Force [g]','FontSize',12);
        ylabel('Density','FontSize',12);
        title(['Histogram for a new measurement: ',num2str(d_new),' mm'])
        % xlim([14.5 15.5])
    end

    %% Sobol indices

    % h = @(theta) theta(1) + theta(2).*(d_new + theta(3));
    h = @(theta) theta(1) + theta(2).*(d_new + theta(3)) + theta(4);
    output = f_new;
    [Sobol_set1(:,j), Sobol_set2(:,j)] = sobol_indices_group(theta, theta_aux, h, output, groups);

end

dist_names = cell(n,1);
for j = 1:n; dist_names{j} = num2str(distance_set(j)); end

figure
bar([Sobol_set1; Sobol_set2]','stacked')
set(gca, 'XTick', 1:n);
xticklabels(dist_names)
xlabel('Pixels')
ylabel('Sobol Index Value')
legend('$\{\alpha,\beta\}$', '$\sigma_{d}$', '$\sigma_{f}$', '$\{\alpha,\beta\} - \sigma_{d}$', '$\{\alpha,\beta\} - \sigma_{f}$', '$\sigma_{d} - \sigma_{f}$', 'Interpreter', 'latex');
ylim([0 1])

%% Output Results

out.samples = out2;
out.means   = mean(out2);
out.sobol1 = Sobol_set1;
out.sobol2 = Sobol_set2;
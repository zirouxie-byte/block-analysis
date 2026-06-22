%% Bayesian Pixel-to-Distance Calibration
%  Model:  d = D + e_d,               e_d ~ N(0, sigma_d^2)
%          F = alpha + beta*d + e_f,  e_f ~ N(0, sigma_f^2)
%          sigma_d = sqrt(sigma_d_r^2 + sigma_inst^2)
%          sigma_f = sqrt(sigma_f_r^2 + sigma_inst^2)
%
%  Sampling: component-wise Metropolis-Hastings on log-transformed params
%  Parameters: theta = [alpha, log(beta), log(sigma_f), log(sigma_f_rep), P_true_1...N]

function out=disp_foce_fitting(parameters)

    %% 1. MCMC SETUP -------------------------------------------------------------
    
    %Data
    distances   = parameters.distances;
    forces      = parameters.forces;
    acc_inst_d  = parameters.acc_inst_d;
    acc_inst_f  = parameters.acc_inst_f;
    N_samples   = parameters.N_samples; 
    N_burnin    = parameters.N_burnin;
    jump        = parameters.jump; 
    
    %%%%%%%% PRIOR extracted from data %%%%%%%%%%%
    % alpha  ~ N(0, sigma_alpha)
    % beta   ~ HalfNormal(sigma_beta)
    % sigma_d ~ HalfNormal(sigma of sigma_d)
    % sigma_f ~ HalfNormal(sigma of sigma_f)
    
    dis_std     = cellfun(@std, distances);
    % dis_std = dis_std + acc_inst_d/sqrt(3);
    dis_means   = cellfun(@mean, distances);
    f_std       = cellfun(@std, forces);
    f_means     = cellfun(@mean, forces);
    
    prior = [3, max(f_means./dis_means), 3*max(dis_std), 3*max(f_std)];
    
    % fixed instrument uncertainty [mm]
    sigma_inst.d  = acc_inst_d/sqrt(3);   % fixed instrument uncertainty [mm]
    
    % Proposal standard deviations (tune to get ~35-50% acceptance per parameter)
    prop_std = [jump, dis_std(:)'];
    
    N_zones   = size(distances,1);
    N_params  = 4 + N_zones;        % alpha, log_beta, log_sigma_p, log_sigma_d_rep, D_1..N
    % Initial values: start near data means
    dis_means = dis_means(:)';      % forzar fila
    theta   = [0, log(prior(2)), log(prior(3)), log(prior(4)), dis_means];
    
    % Storage
    chain  = zeros(N_samples, N_params);
    accept = zeros(N_params, 1);
    
    lp_curr = log_posterior(theta, distances, forces, sigma_inst, N_zones, prior);
    
    fprintf('\nRunning MCMC (%d samples + %d burn-in)...\n', N_samples, N_burnin);
    tic;
    
    %% 2. METROPOLIS-HASTINGS LOOP -----------------------------------------------
    for s = 1 : N_samples + N_burnin
    
        % Component-wise updates (one parameter at a time)
        for k = 1:N_params
            theta_prop    = theta;
            theta_prop(k) = theta(k) + prop_std(k)*randn;
    
            lp_prop = log_posterior(theta_prop, distances, forces, sigma_inst, N_zones, prior);
    
            if log(rand) < lp_prop - lp_curr
                theta   = theta_prop;
                lp_curr = lp_prop;
                if s > N_burnin
                    accept(k) = accept(k) + 1;
                end
            end
        end
    
        % Store post burn-in
        if s > N_burnin
            chain(s - N_burnin, :) = theta;
        end
    
        % Progress
        if mod(s, N_burnin) == 0
            fprintf('  Iteration %d / %d\n', s, N_samples + N_burnin);
        end
    end
    
    fprintf('Done. Elapsed: %.1f s\n\n', toc);
    
    %% 3. EXTRACT POSTERIORS -----------------------------------------------------
    alpha_post      = chain(:, 1);
    beta_post       = exp(chain(:, 2));
    sigma_dr_post   = exp(chain(:, 3));
    sigma_fr_post   = exp(chain(:, 4));
    D_post          = chain(:, 5:end);   % latent pixel lengths per zone
    
    % Thin chain (keep every 5th sample to reduce autocorrelation)
    thin        = 5;
    alpha_t     = alpha_post(1:thin:end);
    beta_t      = beta_post(1:thin:end);
    sigma_d_t   = sqrt(sigma_dr_post(1:thin:end).^2 + sigma_inst.d^2);
    sigma_f_t   = sigma_fr_post(1:thin:end);
    % sigma_f_t   = sqrt(sigma_fr_post(1:thin:end).^2 + sigma_inst.f^2);
    
    
    %% 4. PRINT RESULTS ----------------------------------------------------------
    
    fprintf('\nAcceptance rates:\n');
    pnames = {'alpha','beta','sigma_p','sigma_d_rep'};
    for k = 1:4
        fprintf('  %-12s %.1f%%\n', pnames{k}, 100*accept(k)/N_samples);
    end
    
    %% 5. FIGURES ----------------------------------------------------------------
    
    if parameters.print == 1
        % -- Posterior distributions (alpha and beta) --
        figure('Name','Posteriors','Position',[50 50 1100 380]);
        
        subplot(1,4,1)
        histogram(alpha_t, 60, 'FaceColor',[0.22 0.48 0.74], 'FaceAlpha',0.75, 'Normalization','pdf');
        hold on;
        xline(mean(alpha_t), 'k-', 'LineWidth',1.8);
        xlabel('\alpha  [g]','FontSize',12);
        ylabel('Density','FontSize',12);
        title('\alpha  posterior','FontSize',13);
        legend('Posterior','Mean','Location','best');
        grid on;
        
        subplot(1,4,2)
        histogram(beta_t, 60, 'FaceColor',[0.18 0.63 0.33], 'FaceAlpha',0.75, 'Normalization','pdf');
        hold on;
        xline(mean(beta_t), 'k-', 'LineWidth',1.8);
        xlabel('\beta  [g/mm]','FontSize',12);
        ylabel('Density','FontSize',12);
        title('\beta  posterior  (calibration factor)','FontSize',13);
        legend('Posterior','Mean','Location','best');
        grid on;
        
        subplot(1,4,3)
        histogram(sigma_d_t, 60, 'FaceColor',[0.84 0.49 0.18], 'FaceAlpha',0.75, 'Normalization','pdf');
        hold on;
        xline(mean(sigma_d_t), 'k-', 'LineWidth',1.8);
        xlabel('\sigma_d  [mm]','FontSize',12);
        ylabel('Density','FontSize',12);
        title('\sigma_d  posterior','FontSize',13);
        legend('Posterior','Mean','Location','best');
        grid on;
        
        subplot(1,4,4)
        histogram(sigma_f_t, 60, 'FaceColor',[0.84 0.49 0.18], 'FaceAlpha',0.75, 'Normalization','pdf');
        hold on;
        xline(mean(sigma_f_t), 'k-', 'LineWidth',1.8);
        xlabel('\sigma_f  [g]','FontSize',12);
        ylabel('Density','FontSize',12);
        title('\sigma_f  posterior','FontSize',13);
        legend('Posterior','Mean','Location','best');
        grid on;
    end
    
    dis_mu  = cellfun(@mean, distances);
    dis_std = sqrt(cellfun(@std, distances).^2+sigma_inst.d^2);
    
    f_mu =cellfun(@mean, forces);
    f_std=cellfun(@std, forces);
    % f_std=sqrt(cellfun(@std, forces).^2+sigma_inst.f^2);
    
    % Monte Carlo for new predictions
    dist = linspace(min(dis_mu),max(dis_mu),100);
    forc_5  = zeros(1, length(dist));
    forc_95 = zeros(1, length(dist));
    for j = 1:length(dist)
        e_d    = sqrt(sigma_dr_post.^2 + sigma_inst.d^2) .* randn(N_samples, 1);
        e_f    = sigma_fr_post .* randn(N_samples, 1);
        % e_f    = sqrt(sigma_fr_post.^2 + sigma_inst.f^2) .* randn(N_samples, 1);
        forc  = alpha_post + beta_post .* (dist(j) + e_d) + e_f;
        forc_5(j)  = quantile(forc, 0.05);
        forc_95(j) = quantile(forc, 0.95);
    end
    
    if parameters.print == 1
        figure
        hold on
        plot(dist,forc_5,'-b')
        plot(dist,forc_95,'-b')
        errorbar(dis_mu, f_mu, f_std, f_std, dis_std, dis_std,'o')
        xlabel('Displacement [mm]')
        ylabel('Force [g]')
        legend('5% exceedance','95% exceedance','observed values (mean and std)')
    end

    out = [alpha_post beta_post e_d e_f];
    
    % prediction of a new displacement d_new based on a new pixel p_new is:
    % d_new  = alpha_post + beta_post .* (p_new + e_p) + e_d;
    % d_new will be a vector from which the point statistic can be obtained.

end

%% LOCAL FUNCTION ------------------------------------------------------------
function lp = log_posterior(theta, distances, forces, sigma_inst, N_zones, prior)
% Evaluates log-posterior (up to a constant) for the calibration model.
% Log-transforms: theta(2)=log(beta), theta(3)=log(sigma_d_rep), theta(4)=log(sigma_f_rep)
% Jacobian correction (+theta(k)) included for each log-transformed parameter.

    alpha       = theta(1);
    beta        = exp(theta(2));
    sigma_d_rep = exp(theta(3));
    sigma_f_rep = exp(theta(4));
    D_true      = theta(5:end);
    sigma_d     = sqrt(sigma_d_rep^2 + sigma_inst.d^2);
    sigma_f     = sigma_f_rep;
    % sigma_f     = sqrt(sigma_f_rep^2 + sigma_inst.f^2);

    % Log-priors (Jacobians for log-transforms add theta(k))
    lp = -0.5*(alpha/prior(1))^2;                            % alpha  ~ N(0, 0.1)
    lp = lp - 0.5*(beta/prior(2))^2        + theta(2);       % beta   ~ HalfNormal(0.05)
    lp = lp - 0.5*(sigma_d_rep/prior(3))^2 + theta(3);       % sigma_dr ~ HalfNormal(5)
    lp = lp - 0.5*(sigma_f_rep/prior(4))^2 + theta(4);       % sigma_fr ~ HalfNormal(0.02)

    % Log-likelihood
    for i = 1:N_zones
        F_i = alpha + beta * D_true(i);
        lp  = lp ...
            + sum(-0.5 * ((distances{i}    - D_true(i)) / sigma_d).^2) ...
            - numel(distances{i})    * log(sigma_d) ...
            + sum(-0.5 * ((forces{i} - F_i       ) / sigma_f).^2) ...
            - numel(forces{i}) * log(sigma_f);
    end
end


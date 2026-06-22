function out = MLE(Dat)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Function - Compute the MLE estimate
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Authors:
%%% Rafael Ruiz         - University of Michigan - Dearborn (US)
%%% Jesus Pereira       - University of Michigan - Dearborn (US)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% INPUTS

% 

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% OUTPUTS

% out

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Read input data

x           = Dat.x;                % Inputs (deformations)
y           = Dat.y;                % Outputs (Forces)
theta_nom   = Dat.theta_nom;        % Vector of nominal model parameters
lb          = Dat.lb;               % Lower limit for theta (constrains for optimization only for MLE)
ub          = Dat.ub;               % Upper limit for theta (constrains for optimization only for MLE)
index       = Dat.index;            % Indices of the model parameters to be updated
error       = Dat.error;            % i=1 multiplicative model error / i=0 additive model error

%% Variable definition

N = length(index);          % Number of parameters to update
M = length(x);              % Number of experimental observations

%% MLE

lbb        = lb(1,index);   % Lower bound for variable to be updated
ubb        = ub(1,index);   % Upper bound for variable to be updated

% Objective function - MLE
fun        = @(xx) J_error_MLE(xx,x,y,theta_nom,error,index);

% Optimization problem - MLE
options = optimoptions('fmincon','Display', 'iter-detailed', 'MaxIterations', 200);
[theta_opt,fval,exitflag,output,lambda,grad_MLE,hessian] = fmincon(fun,theta_nom(1,index),[],[],[],[],lbb,ubb,[],options);

theta_MLE           = theta_nom;    % MLE estimate
theta_MLE(1,index)  = theta_opt;

J       = J_error_MLE(theta_opt,x,y,theta_nom,error,index);
BIC_MLE = - M/2*( log(2*pi*exp(1)) + log(J) ) - 1/2*N*log(M);   % Bayesian Information Criterion (MLE)

%% Outputs
out.grad_MLE  = grad_MLE;   % Optimization gradient for MLE estimate
out.theta_MLE = theta_MLE;
out.BIC_MLE   = BIC_MLE;
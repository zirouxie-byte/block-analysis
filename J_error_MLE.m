function out = J_error_MLE(teta,x,y,theta0,i,index)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Function - Likelihood function
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Author:
%%% Rafael Ruiz         - University of Michigan - Dearborn (US)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% INPUTS

% teta          % New model parameters
% x             % Inputs (experimental data)
% y             % Outputs (experimental data)
% theta0        % Nominal model parameters
% i             % Model error (i=1 multiplicative / i=0 additive)
% index         % Parameters to update

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% OUTPUTS

% out           % Evaluated likelihood function

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

theta           = theta0;
theta(1,index)  = teta;

if i==1
    aux = ( log(y./H(theta,x,y)) ).^2;
else
    aux =  ( y - H(theta,x,y) ).^2;
end

%% Outputs

out = mean(aux);
clc; clear all; close all;

%% Image path

imgDir = 'D:\Matlab_Codes\Pixel_to_Distance\Hydrogels and Pictures\Image - Test\Agarose Marks\';

%% Calibration - Spring

spring_data         = load_spring_data(1);
spring_calibration  = calibration_spring(spring_data);

%% Calibration - Pixel 2 Distance

dist2px_data = load_px2dist_data(imgDir);
dist2px_calibration = calibration_px2dist(dist2px_data);

%% Determine deformation (DIC)

pattern     = ROI_selection(imgDir);
distance    = DIC_distance_calculation(imgDir,pattern);

% distance_2 = zeros(10,2);
% 
% for i = 1:10
%     imgIdx = i;
%     imFile = fullfile(imgDir, sprintf('%04d.jpg', imgIdx));
%     I = imread(imFile);
% 
%     figure(1); clf;
%     imshow(I, 'InitialMagnification', 'fit');
% 
%     % 1. Measure Spring
%     disp('Click the TOP moving bar then the TOP bottom bar of the spring');
%     [xs,ys] = ginput(2);
%     distance_2(i,1) = sqrt((xs(1)-xs(2))^2 + (ys(1)-ys(2))^2);
% 
%     % 2. Measure Hydrogel
%     disp('Click the LEFT and RIGHT edges of the hydrogel bead');
%     [xh,yh] = ginput(2);
%     distance_2(i,2) = sqrt((xh(1)-xh(2))^2 + (yh(1)-yh(2))^2);
% end

%% Convert px->mm and px->force

data = unit_coversion(distance,spring_calibration,dist2px_calibration);

%% Compute unknown stiffness (and elastic modulus) from data fitting
close all

figure
subplot(1,2,1)
plot(data.d_s,data.f_s,'r-o')
xlabel('Deformation [mm]'); ylabel('Force [g]'); title('Data - Spring')
subplot(1,2,2)
plot(data.d_g,data.f_g,'b-o')
xlabel('Deformation [mm]'); ylabel('Force [g]'); title('Data - Gel')

% MANUAL INPUT FOR HYDROGEL CROSS-SECTION (mm)
width_g     = 24.0;
thickness_g = 5.38;
length_g    = 7.304; % UPDATE TO PICTURE DETECTION (load_px2dist_data)
A_g = width_g*thickness_g;

strain_g = data.d_g/length_g;
stress_g = data.f_g*10/1000/A_g;  % Stress in MPa

% Dat.x           = data.d_g;     % Inputs (deformation - mm)
% Dat.y           = data.f_g;     % Outputs (force - g)
Dat.x           = strain_g;     % Inputs (strain)
Dat.y           = stress_g;     % Outputs (stress - MPa)
Dat.lb          = [0];          % Lower limit for theta (constrains for optimization only for MLE)
Dat.ub          = [1e10];       % Upper limit for theta (constrains for optimization only for MLE)
Dat.error       = 0;            % i=1 multiplicative model error / i=0 additive model error
Dat.theta_nom   = spring_calibration.means(2);        % Vector of nominal model parameters
Dat.index       = [1];            % Indices of the model parameters to be updated

fit_results = MLE(Dat);

E_gel = fit_results.theta_MLE % [MPa]

X = strain_g;
Y = stress_g;
Y_pred = (strain_g-strain_g(1))*fit_results.theta_MLE + stress_g(1);

figure
plot(X,Y,'b-o')
hold on
plot(X,Y_pred,'k--')
legend('Data',sprintf('Linear Fit - E = %.2f kPa',E_gel*1000))
ylabel('Stress [MPa]'); xlabel('Strain [mm/mm]')
xlim([0 0.2])
% To be defined
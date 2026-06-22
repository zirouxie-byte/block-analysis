function out = load_spring_data(sp)

%% Load Experimental Data

% Distance vector (d) stored as a cell array for each row entry
d = {0.050; 0.100; 0.150; 0.200; 0.250; 0.300; 0.350; 0.400};

% Force data for SP1 (each cell contains the 3 trial repetitions for that row)
force_sp1{1} = [2.02, 2.20, 2.07];
force_sp1{2} = [4.14, 4.30, 4.10];
force_sp1{3} = [6.32, 6.25, 6.08];
force_sp1{4} = [8.33, 8.17, 8.01];
force_sp1{5} = [10.32, 10.13, 9.93];
force_sp1{6} = [12.27, 12.08, 11.94];
force_sp1{7} = [14.15, 14.13, 14.03];
force_sp1{8} = [16.06, 16.15, 16.11];

% Force data for SP2 (each cell contains the 3 trial repetitions for that row)
force_sp2{1} = [1.73, 1.79, 1.89];
force_sp2{2} = [3.43, 3.54, 3.67];
force_sp2{3} = [5.13, 5.44, 5.40];
force_sp2{4} = [6.86, 7.32, 7.04];
force_sp2{5} = [8.66, 9.11, 8.69];
force_sp2{6} = [10.33, 10.78, 10.39];
force_sp2{7} = [11.96, 12.46, 12.17];
force_sp2{8} = [13.58, 14.09, 13.91];

% Force data for SP3 (each cell contains the 3 trial repetitions for that row)
force_sp3{1} = [1.98, 2.07, 2.22];
force_sp3{2} = [3.83, 4.12, 4.30];
force_sp3{3} = [5.80, 6.32, 6.33];
force_sp3{4} = [7.73, 8.45, 8.25];
force_sp3{5} = [9.74, 10.49, 10.20];
force_sp3{6} = [11.82, 12.40, 12.10];
force_sp3{7} = [13.86, 14.25, 14.12];
force_sp3{8} = [15.92, 16.21, 16.17];

if sp == 1; force = force_sp1;
elseif sp == 2; force = force_sp2;
elseif sp == 3; force = force_sp3;
end

%% Outputs

out.d = d;
out.f = force;
out.sp = sp;

end
function out = unit_coversion(distance,spring_calibration,dist2px_calibration)

    alpha_dist2force = spring_calibration.means(1);
    beta_dist2force  = spring_calibration.means(2);
    
    alpha_px2dist = dist2px_calibration.means(1);
    beta_px2dist = dist2px_calibration.means(2);
    
    dist_mm = distance*beta_px2dist + alpha_px2dist;
    def_px = distance - distance(1,:);
    def_spring_mm   = def_px(:,1)*beta_px2dist + alpha_px2dist;
    def_gel_mm      = def_px(:,2)*beta_px2dist + alpha_px2dist;
    
    force_spring_g  = def_spring_mm*beta_dist2force + alpha_dist2force;
    force_gel_g     = force_spring_g;

    out.f_g = -force_gel_g;
    out.f_s = -force_spring_g;
    out.d_g = -def_gel_mm;
    out.d_s = -def_spring_mm;
    % out.L0_g = dist_mm(1,2);
    % out.L0_s = dist_mm(1,1);

end
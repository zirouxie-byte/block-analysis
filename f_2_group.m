function c_out_2 = f_2_group(output, groups, Ind, samples_aux, samples, N, k, h)
    
    % Evaluates variance when keeping TWO GROUPS from 'samples'
    J = Ind(1,k); 
    K = Ind(2,k);
    
    % Combine the indices of the two groups
    combined_idx = [groups{J}, groups{K}];
    
    c_out_2 = zeros(N, size(output,2));
    for i = 1:N
        theta = samples_aux(i, :);                         % Start with all aux
        theta(combined_idx) = samples(i, combined_idx);    % Overwrite both groups
        c_out_2(i,:) = (output(i,:) - h(theta)).^2;
    end
end
function c_out_1 = f_1_group(output, samples_aux, samples, group_idx, N, h)
    
    % Evaluates variance when keeping a GROUP from 'samples' 
    % and the rest from 'samples_aux'
    c_out_1 = zeros(N, size(output,2));
    
    for i = 1:N
        theta = samples_aux(i, :);                   % Start with all aux
        theta(group_idx) = samples(i, group_idx);    % Overwrite group with primary samples
        c_out_1(i,:) = (output(i,:) - h(theta)).^2;
    end
end
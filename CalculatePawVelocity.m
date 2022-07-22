% CalculatePawVelocity.m
% Sarah West
% 7/22/22

% Calculates paw velocity from DeepLabCut position extractions saved as
% Matlab matrices. Runs with RunAnalysis.
% Inputs: parameters.data -- matrix of extracted DLC data.
%         parameters.columns_to_use -- structure with fields for each body
%         part, with values equaling the column numbers of parameters.data
%         corresponding to that body part's x position, y position, and
%         likelihood.

function [parameters] = CalculatePawVelocity(parameters)

    MessageToUser('Calculating ', parameters);

    % If smoothing factor not given, make it = 1;
    if isfield(parameters, 'smoothing_factor')
        smoothing_factor = parameters.smoothing_factor;
    else
        smoothing_factor = 1;
    end

    % For each body part of interest
    body_parts = fieldnames(parameters.columns_to_use);
    for parti = 1:numel(body_parts)
        body_part = body_parts{parti};

        % Pull out relevant data.
        xposition = parameters.data(:, parameters.columns_to_use.(body_part)(1));
        yposition = parameters.data(:, parameters.columns_to_use.(body_part)(2));
        likelihood = parameters.data(:, parameters.columns_to_use.(body_part)(3));

        % If likelihood is below the likelihood threshold, remove
        % corresponding position points.
        indices = likelihood < parameters.likelihood_threshold;
        xposition(indices) = NaN;
        yposition(indices) = NaN;

        % Smooth position data. 
        xposition = movmean(xposition, smoothing_factor, 'omitnan');
        yposition = movmean(yposition, smoothing_factor, 'omitnan');

        % Now calculate velocity.
        xvelocity = movmean(diff(xposition), smoothing_factor, 'omitnan');
        yvelocity = movmean(diff(yposition), smoothing_factor, 'omitnan');
        total_velocity = sqrt(xvelocity .^ 2 + yvelocity .^ 2);

        % Downsample to match fluorescence frames per second, if necessary.
        % (This only works right now if the ratio is an integer).
        ratio = parameters.body_fps / parameters.fps;
        if ratio ~= 1 && numel(likelihood) ~= parameters.frames + parameters.skip/parameters.channelNumber
  
            old_total_velocity = total_velocity;
            old_xvelocity = xvelocity;
            old_yvelocity = yvelocity;

            remainder = rem(size(total_velocity,1), ratio);
            
            % Reshape for averaging
            holder_x = reshape(xvelocity(1:end - remainder)', ratio, (size(xvelocity,1) - remainder)/ratio);
            holder_y = reshape(yvelocity(1:end - remainder)', ratio, (size(yvelocity,1) - remainder)/ratio);
            holder_total = reshape(total_velocity(1:end - remainder)', ratio, (size(total_velocity,1) - remainder)/ratio);
            
            % Average 
            xvelocity = mean(holder_x, 1);
            yvelocity = mean(holder_y, 1);
            total_velocity = mean(holder_total, 1);

            % Take mean of any remainders and add as last point. Also flip
            % vectors to keep dimensions consistent.
            xvelocity = [xvelocity mean(old_xvelocity(end - remainder + 1 :end))]';
            yvelocity = [yvelocity mean(old_yvelocity(end - remainder + 1 :end))]';
            total_velocity = [total_velocity mean(old_total_velocity(end - remainder + 1 :end))]';

        else
            % Add a 0 to the beginning of velocities to keep them the
            % correct lenghth post diff.
            xvelocity = [0; xvelocity];
            yvelocity = [0; yvelocity];
            total_velocity = [0; total_velocity];

        end

        % Remove skipped frames.
        xvelocity = xvelocity(parameters.skip/parameters.channelNumber + 1 : end);
        yvelocity = yvelocity(parameters.skip/parameters.channelNumber + 1 : end);
        total_velocity = total_velocity(parameters.skip/parameters.channelNumber + 1 : end);

        % Put into output structure.
        velocity.(body_part).x = xvelocity;
        velocity.(body_part).y = yvelocity;
        velocity.(body_part).total = total_velocity;

    end

    % Put velocity into output structure. 
    parameters.velocity = velocity;

end
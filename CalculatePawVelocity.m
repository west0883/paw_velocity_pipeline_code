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

    maximumOutlierCount = parameters.maximumOutlierCount;

    % If smoothing factor not given, make it = 1;
    if isfield(parameters, 'position_smoothing_factor')
        position_smoothing_factor = parameters.position_smoothing_factor;
    else
        position_smoothing_factor = 1;
    end

    if isfield(parameters, 'velocity_smoothing_factor')
        velocity_smoothing_factor = parameters.velocity_smoothing_factor;
    else
        velocity_smoothing_factor = 1;
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

        %%%%%%% POSITION %%%%%
        % Remove outliers from position
        if isfield(parameters, 'removeOutliers') && parameters.removeOutliers 
            
            % don't remove if the number of non-NaNs is a certain level over
            % the maximum outliers or less 
            if (sum(~isnan(xposition)) < 10 * maximumOutlierCount) | sum(~isnan(yposition)) < 10 * maximumOutlierCount
                % do nothing 
            else
                x_outlier_indices = find(isoutlier(xposition, 'gesd', 'MaxNumOutliers', maximumOutlierCount));
                y_outlier_indices = find(isoutlier(yposition, 'gesd', 'MaxNumOutliers', maximumOutlierCount));
            end

            % Remove each set of outliers from each vector 
            xposition([x_outlier_indices; y_outlier_indices]) = NaN;
            yposition([x_outlier_indices; y_outlier_indices]) = NaN;
        end 

        % Smooth position data. 
        xposition = movmean(xposition, position_smoothing_factor, 'omitnan');
        yposition = movmean(yposition, position_smoothing_factor, 'omitnan');

        % Remove means from position data (now they're displacement
        % vectors)
        xposition = xposition - mean(xposition, 'omitnan');
        yposition = yposition - mean(yposition, 'omitnan');

        % total position magnitude
        total_position_magnitude = sqrt(xposition .^ 2 + yposition .^ 2);

        % total position angle (in radians)
        total_position_angle = atan(yposition./xposition);

        % add/subtract radians to get the angle into the correct quadrant
        % based on if xposition and/or yposition are negative. 
        % add/subtract radians to get the angle into the correct quadrant
        % based on if xvelocity and/or yvelocity are negative. 
        negx = xposition < 0; 
        negy = yposition < 0; 
        posx = xposition > 0;
        posy = yposition > 0; 

        % if both are positive, change nothing (quadrant 1 to 1)

        % if x is positive, y is negative, subtract from 2pi (quad 4)
        xposyneg = posx & negy; 
        total_position_angle(xposyneg) = 2 * pi - total_position_angle(xposyneg);

        % if x is negative, y is postive, swing from quadrant 1 to 2 
            % subtract from pi radians
        xnegypos = negx & posy; 
        total_position_angle(xnegypos) = pi - total_position_angle(xnegypos);

        %%%%%% VELOCITY %%%%%
        % Now calculate velocity.
        xvelocity = diff(xposition);
        yvelocity = diff(yposition);

        % Remove outliers from velocity
        if isfield(parameters, 'removeOutliers') && parameters.removeOutliers 
       
            % don't remove if the number of non-NaNs is a certain level over
            % the maximum outliers or less 
            if (sum(~isnan(xvelocity)) < 10 * maximumOutlierCount) | sum(~isnan(yvelocity)) < 10 * maximumOutlierCount
                % do nothing 
            else
                x_outlier_indices = find(isoutlier(xvelocity, 'gesd', 'MaxNumOutliers', maximumOutlierCount));
                y_outlier_indices = find(isoutlier(yvelocity, 'gesd', 'MaxNumOutliers', maximumOutlierCount));
                
                % Remove each set of outliers from each vector 
                xvelocity([x_outlier_indices; y_outlier_indices]) = NaN;
                yvelocity([x_outlier_indices; y_outlier_indices]) = NaN;
            end 
        end 

        % Smooth velocity 
        xvelocity = movmean(xvelocity, velocity_smoothing_factor, 'omitnan');
        yvelocity = movmean(yvelocity, velocity_smoothing_factor, 'omitnan');
    
        % total velocity magnitude
        total_velocity_magnitude = sqrt(xvelocity .^ 2 + yvelocity .^ 2);

        % total veloctiy angle (in radians)
        total_velocity_angle = atan(yvelocity./xvelocity);

        % add/subtract radians to get the angle into the correct quadrant
        % based on if xvelocity and/or yvelocity are negative. 
        negx = xvelocity < 0; 
        negy = yvelocity < 0; 
        posx = xvelocity > 0;
        posy = yvelocity > 0; 

        % if both are positive, change nothing (quadrant 1 to 1)

        % if x is positive, y is negative, subtract from 2pi (quad 4)
        xposyneg = posx & negy; 
        total_velocity_angle(xposyneg) = 2 * pi - total_velocity_angle(xposyneg);

        % if x is negative, y is postive, swing from quadrant 1 to 2 
            % subtract from pi radians
        xnegypos = negx & posy; 
        total_velocity_angle(xnegypos) = pi - total_velocity_angle(xnegypos);

        % if both are negative, swing from quadrant 1 to quadrant 3
            % add to pi radians
        xnegyneg = negx & negy; 
        total_velocity_angle(xnegyneg) = pi + total_velocity_angle(xnegyneg);
 
        %%%%%% DOWNSAMPLE BOTH %%%%%
        % Downsample to match fluorescence frames per second, if necessary.
        % (This only works right now if the ratio is an integer).
        ratio = parameters.body_fps / parameters.fps;
        if ratio ~= 1 && numel(likelihood) ~= parameters.frames + parameters.skip/parameters.channelNumber
  
            old_total_velocity_magnitude = total_velocity_magnitude;
            old_total_velocity_angle = total_velocity_angle;
            old_xvelocity = xvelocity;
            old_yvelocity = yvelocity;
            old_total_position_magnitude = total_position_magnitude;
            old_total_position_angle = total_position_angle;
            old_xposition = xposition;
            old_yposition = yposition;
        
            remainder = rem(size(total_velocity_magnitude,1), ratio);
            
            % Reshape for averaging
            holder_x = reshape(xvelocity(1:end - remainder)', ratio, (size(xvelocity,1) - remainder)/ratio);
            holder_y = reshape(yvelocity(1:end - remainder)', ratio, (size(yvelocity,1) - remainder)/ratio);
            holder_total_magnitude = reshape(total_velocity_magnitude(1:end - remainder)', ratio, (size(total_velocity_magnitude,1) - remainder)/ratio);
            holder_total_angle = reshape(total_velocity_angle(1:end - remainder)', ratio, (size(total_velocity_angle,1) - remainder)/ratio);
            holder_xp = reshape(xposition(1:end - remainder - 1)', ratio, (size(xposition,1) - 1 - remainder)/ratio);
            holder_yp = reshape(yposition(1:end - remainder - 1)', ratio, (size(yposition,1) - 1 - remainder)/ratio);
            holder_total_magnitude_position = reshape(total_position_magnitude(1:end - remainder - 1)', ratio, (size(total_position_magnitude, 1) - 1 - remainder)/ratio);
            holder_total_angle_position = reshape(total_position_angle(1:end - remainder - 1)', ratio, (size(total_position_angle, 1) - 1 - remainder)/ratio);
            
            % Average 
            xvelocity = mean(holder_x, 1, 'omitnan');
            yvelocity = mean(holder_y, 1);
            total_velocity_magnitude = mean(holder_total_magnitude, 1, 'omitnan');
            total_velocity_angle = mean(holder_total_angle, 1, 'omitnan');
            xposition = mean(holder_xp, 1, 'omitnan');
            yposition = mean(holder_yp, 1, 'omitnan');
            total_position_magnitude = mean(holder_total_magnitude_position, 1, 'omitnan');
            total_position_angle = mean(holder_total_angle_position, 1, 'omitnan');

            % Take mean of any remainders and add as last point. Also flip
            % vectors to keep dimensions consistent.
            xvelocity = [xvelocity mean(old_xvelocity(end - remainder + 1 :end), 'omitnan')]';
            yvelocity = [yvelocity mean(old_yvelocity(end - remainder + 1 :end), 'omitnan')]';
            total_velocity_magnitude = [total_velocity_magnitude mean(old_total_velocity_magnitude(end - remainder + 1 :end), 'omitnan')]';
            total_velocity_angle = [total_velocity_angle mean(old_total_velocity_angle(end - remainder + 1 :end), 'omitnan')]';
            xposition = [xposition mean(old_xposition(end - remainder + 1 :end), 'omitnan')]';
            yposition = [yposition mean(old_yposition(end - remainder + 1 :end), 'omitnan')]';
            total_position_magnitude = [total_position_magnitude mean(old_total_position_magnitude(end - remainder + 1 :end), 'omitnan')]';
            total_position_angle = [total_position_angle mean(old_total_position_angle(end - remainder + 1 :end), 'omitnan')]';
        
        else
            % Add a 0 to the beginning of velocities to keep them the
            % correct lenghth post diff.
            xvelocity = [0; xvelocity];
            yvelocity = [0; yvelocity];
            total_velocity_magnitude = [0; total_velocity_magnitude];
            total_velocity_angle = [0; total_velocity_angle];
            xposition = [0; xposition];
            yposition = [0; yposition];
            total_position_magnitude = [0; total_position_magnitude];
            total_position_angle = [0; total_position_angle];

        end

        % Remove skipped frames.
        xvelocity = xvelocity(parameters.skip/parameters.channelNumber + 1 : end);
        yvelocity = yvelocity(parameters.skip/parameters.channelNumber + 1 : end);
        total_velocity_magnitude = total_velocity_magnitude(parameters.skip/parameters.channelNumber + 1 : end);
        total_velocity_angle = total_velocity_angle(parameters.skip/parameters.channelNumber + 1 : end);
        xposition = xposition(parameters.skip/parameters.channelNumber + 1 : end);
        yposition = yposition(parameters.skip/parameters.channelNumber + 1 : end);
        total_position_magnitude = total_position_magnitude(parameters.skip/parameters.channelNumber + 1 : end);
        total_position_angle = total_position_angle(parameters.skip/parameters.channelNumber + 1 : end);

        % Put into output structure.
        velocity.(body_part).x = xvelocity;
        velocity.(body_part).y = yvelocity;
        velocity.(body_part).total_magnitude = total_velocity_magnitude;
        velocity.(body_part).total_angle = total_velocity_angle;
        position.(body_part).x = xposition;
        position.(body_part).y = yposition;
        position.(body_part).total_magnitude = total_position_magnitude;
        position.(body_part).total_angle = total_position_angle;

    end

    % Put velocity & cleaned positions into output structure. 
    parameters.velocity = velocity;
    parameters.position = position;

end
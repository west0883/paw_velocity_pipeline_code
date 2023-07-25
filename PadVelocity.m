% PadVelocity.m
% Sarah West
% 5/26/23

% Converts the short position & velocity behavior stacks. 

function [parameters] = PadVelocity(parameters)

    MessageToUser('Checking ', parameters);

    input_data = parameters.input_data;

    % If less than frames
    if size(input_data.FL.total_magnitude, 1) < parameters.frames

        output_data = input_data;

        % Pad 
        short_number = parameters.frames - size(output_data.FL.total_magnitude, 1);

        body_parts = parameters.loop_variables.body_parts;
        % for each body part
        for parti = 1:numel(body_parts)
            body_part = body_parts{parti};
            output_data.(body_part).total_magnitude = [output_data.(body_part).total_magnitude; NaN(short_number, 1)];
            %output_data.(body_part).total_angle = [output_data.(body_part).total_angle; NaN(short_number, 1)]; 
            output_data.(body_part).x = [output_data.(body_part).x; NaN(short_number, 1)]; 
            output_data.(body_part).y = [output_data.(body_part).y; NaN(short_number, 1)]; 
        end

        % Tell user.
        if short_number ~= 0
            disp(['Stack short by ' num2str(short_number) ' frames.']);
        end

        parameters.output_data = output_data;

    else 
        % Don't need to re-save the data 
        parameters.dont_save = true;

        % Make the output data the same as the input, just to be sage
        parameters.output_data = input_data;

    end 
end 
% CalculateTotalMagnitude.m
% Sarah West
% 7/24/23

function [ parameters] = CalculateTotalMagnitude(parameters)

        MessageToUser('Calculating ', parameters);

        data = parameters.data;
        total_magnitude = sqrt(data.x .^ 2 + data.y .^ 2);
        
        data_with_total_magnitude = data; 
        data_with_total_magnitude.total_magnitude = total_magnitude;

        parameters.data_with_total_magnitude = data_with_total_magnitude;


end 
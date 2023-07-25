% missing_body_data.m
% Sarah West
% 6/17/22

% A script that finds stacks that don't have body data & creates vectors of
% NaN for the paw velocity.

% Number of frames in recording (after the "skip" number of frames).
parameters.frames = 6000;

% Initialize list of missing stacks (cell of mouse, day, stack number as
% columns, each stack is own row)
missing_data = cell(1, 3);

% Directory/filename you're looking at for each potentially missing stack.
parameters.input_filename = {[parameters.dir_exper 'behavior\body\normalized\paw velocity normalized with total magnitude\'], 'mouse', '\', 'day', '\', 'velocity', 'stack', '.mat'};

% Output filename
parameters.output_directory =  {[parameters.dir_exper 'behavior\body\normalized\paw velocity normalized with total magnitude\'], 'mouse', '\', 'day', '\'};
parameters.output_filename = {'velocity', 'stack', '.mat'};

% for position data, too 
parameters.output_directory_position =  {[parameters.dir_exper 'behavior\body\normalized\paw position normalized with total magnitude\'], 'mouse', '\', 'day', '\'};
parameters.output_filename_position = {'position', 'stack', '.mat'};

% Directory/filename for where to save list of missing data.
parameters.missing_data_filename =  [parameters.dir_exper '\behavior\body\missing_body_data.mat'];

% Initialize counter for cells.
counter = 0;

%% Run through mice_all, search all paw velocity calculated.
parameters.loop_list.iterators = {
               'mouse', {'loop_variables.mice_all(:).name'}, 'mouse_iterator'; 
               'day', {'loop_variables.mice_all(', 'mouse_iterator', ').days(:).name'}, 'day_iterator';
               'condition', {'loop_variables.conditions'}, 'condition_iterator';
               'stack', {'getfield(loop_variables, {1}, "mice_all", {',  'mouse_iterator', '}, "days", {', 'day_iterator', '}, ', 'loop_variables.conditions_stack_locations{', 'condition_iterator', '})'}, 'stack_iterator'; 
               };

looping_output_list = LoopGenerator(parameters.loop_list, parameters.loop_variables); 

% For each element of looping_output_list, 
for itemi = 1:size(looping_output_list,1)

    % Get keywords, like in RunAnalysis
    parameters.keywords = [parameters.loop_list.iterators(:,1); parameters.loop_list.iterators(:,3)];
    
    % Get values, like in RunAnalysis
    parameters.values = cell(size(parameters.keywords));
    for i = 1: numel(parameters.keywords)
        parameters.values{i} = looping_output_list(itemi).(cell2mat(parameters.keywords(i)));
    end

    % Get the filename 
    filestring = CreateStrings(parameters.input_filename, parameters.keywords, parameters.values);

    % Check if that file exists. If not, add it to missing_data
    if ~isfile(filestring)
        counter = counter + 1; 
        missing_data(counter, :) = [parameters.values(1:2)' parameters.values(4)];

    end 
end

% Save list of missing data.
save(parameters.missing_data_filename, 'missing_data');

%% Make missing data stacks into vectors of NaNs.

load(parameters.missing_data_filename, 'missing_data');

% Make new keywords list for CreateStrings
parameters.keywords = {'mouse', 'day', 'stack'};

% Make the vector of NaNs (with a variable name that matches the other files 
% in output folder). (frames x 1)
% for each body part,
body_parts = {'FR', 'FL', 'HL', 'tail', 'nose', 'eye'};
for parti = 1:numel(body_parts)
    body_part = body_parts{parti};
    velocity.(body_part).x = NaN(parameters.frames, 1);
    velocity.(body_part).y = NaN(parameters.frames, 1);
    velocity.(body_part).total_magnitude = NaN(parameters.frames, 1);
    velocity.(body_part).total_angle = NaN(parameters.frames, 1);
end

% replicate for positions
position = velocity;

% For each entry in missing_data,
for itemi = 1:size(missing_data,1)
     
    % Make directory & filenames
    dir_string = CreateStrings(parameters.output_directory, parameters.keywords, missing_data(itemi, :));
    filestring = CreateStrings(parameters.output_filename, parameters.keywords, missing_data(itemi, :));

    % Make output directory, if it doesn't already exist.
    if ~exist(dir_string, 'dir')
        mkdir(dir_string);
    end

    % Save the NaN vector under the name of the missing data stack.
    save([dir_string filestring], 'velocity');

    % repeat for position
    % Make directory & filenames
    dir_string_position = CreateStrings(parameters.output_directory_position, parameters.keywords, missing_data(itemi, :));
    filestring_position = CreateStrings(parameters.output_filename_position, parameters.keywords, missing_data(itemi, :));

    % Make output directory, if it doesn't already exist.
    if ~exist(dir_string_position, 'dir')
        mkdir(dir_string_position);
    end

    % Save the NaN vector under the name of the missing data stack.
    save([dir_string_position filestring_position], 'position');
end




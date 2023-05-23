% create_mice_all_no_missing_bodydata.m
% Sarah West
% 7/22/22


% Load list of missing data (all other mice)
load('Y:\Sarah\Analysis\Experiments\Random Motorized Treadmill\behavior\body\missing_data.mat');
list_1 = missing_data;

% Load list of missing data (mouse 1099)
load('Y:\Sarah\Analysis\Experiments\Random Motorized Treadmill\behavior\body\missing_data.mat');
list_2 = missing_data;

% concatenate the 2 lists 
missing_data = [list_1; list_2];

% Load mice_all
load('Y:\Sarah\Analysis\Experiments\Random Motorized Treadmill\mice_all.mat');

% Make the list to search through
parameters.loop_list.iterators = {
               'mouse', {'loop_variables.mice_all(:).name'}, 'mouse_iterator'; 
               'day', {'loop_variables.mice_all(', 'mouse_iterator', ').days(:).name'}, 'day_iterator';
               'condition', {'loop_variables.conditions'}, 'condition_iterator';
               'stack', {'getfield(loop_variables, {1}, "mice_all", {',  'mouse_iterator', '}, "days", {', 'day_iterator', '}, ', 'loop_variables.conditions_stack_locations{', 'condition_iterator', '})'}, 'stack_iterator'; 
               };

looping_output_list = LoopGenerator(parameters.loop_list, parameters.loop_variables); 

% Make a new mice_all
mice_all_no_missing_data = parameters.mice_all; %mice_all;

% For each item in looping output list,
for itemi = 1:size(looping_output_list,1)

    % Get this list of loading and saving string-creating parameters.keywords and
    % variables
    
    % Keywords should be the names of each iterator, which are in the
    % first column of iterators cell. Also include the iterator names.
    parameters.keywords = [parameters.loop_list.iterators(:,1); parameters.loop_list.iterators(:,3)];

    % Values are the corresponding values in the looping output list
    % for each keyword's field.
    parameters.values = cell(size(parameters.keywords));
    for i = 1: numel(parameters.keywords)
        parameters.values{i} = looping_output_list(itemi).(cell2mat(parameters.keywords(i)));
    end

    % See if this stack is in the missing data

    % Compare if elements in equivalent positions match.
    elementwise_logical = strcmp(repmat(parameters.values(1:end/2)', size(missing_data, 1), 1), missing_data(:,1:4));

    % See if entire rows match. 
    row_logical = all(elementwise_logical, 2);
    indices = find(row_logical);
    
    % If a row matches,
    if ~isempty(indices)

        disp(strjoin(parameters.values(1:end/2), ', '));

        % Figure out if motorized or spontaneous
        if strcmp(parameters.values{3}, 'motorized')
            stacks_field = 'stacks';
        else
            stacks_field = 'spontaneous';
        end

        % Get out relevent cell array of stack names
        these_stacks =  mice_all_no_missing_data(parameters.values{5}).days(parameters.values{6}).(stacks_field);

        % Get index of where this stack is in these_stacks
        index = strcmp(these_stacks, parameters.values{4});

        % Remove stack 
        mice_all_no_missing_data(parameters.values{5}).days(parameters.values{6}).(stacks_field)(index) = [];

    end
end

% Save new version of mice_all with no missing data 
save('Y:\Sarah\Analysis\Experiments\Random Motorized Treadmill\behavior\body\mice_all_no_missing_data.mat', 'mice_all_no_missing_data');
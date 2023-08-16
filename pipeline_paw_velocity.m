% pipeline_paw_velocity.m
% Sarah West
% 7/22/22

% Extracts paw velocity from DeepLabCut output files.

%% Initial setup
% Put all needed paramters in a structure called "parameters", which you
% can then easily feed into your functions. 
clear all; 

% Output Directories

% Create the experiment name. This is used to name the output folder. 
parameters.experiment_name='Random Motorized Treadmill';

% Output directory name bases
parameters.dir_base='Y:\Sarah\Analysis\Experiments\';
parameters.dir_exper=[parameters.dir_base parameters.experiment_name '\']; 

% *********************************************************

% (DON'T EDIT). Load the "mice_all" variable you've created with "create_mice_all.m"
load([parameters.dir_exper 'mice_all.mat']);

% Add mice_all to parameters structure.
parameters.mice_all = mice_all; 

% ****Change here if there are specific mice, days, and/or stacks you want to work with****
parameters.mice_all = parameters.mice_all;
% 

% Give the number of digits that should be included in each stack number.
parameters.digitNumber=2; 

% *************************************************************************
% Parameters

% Sampling frequency of  body, in fps.
parameters.body_fps = 40;

% Sampling frequency of collected brain data (per channel), in Hz or frames per
% second.
parameters.fps= 20; 

% Number of channels from brain data (need this to calculate correct
% "skip" time length).
parameters.channelNumber = 2;

% Number of frames you recorded from brain and want to keep (don't make chunks longer than this)  
% (after skipped frames are removed)
parameters.frames = 6000; 

% Number of initial brain frames to skip, allows for brightness/image
% stabilization of camera. Need this to know how much to skip in the
% behavior.
parameters.skip = 1200; 

% Load names of motorized periods
load([parameters.dir_exper 'periods_nametable.mat']);
periods_motorized = periods;

% Load names of spontaneous periods
load([parameters.dir_exper 'periods_nametable_spontaneous.mat']);
periods_spontaneous = periods(1:6, :);
clear periods; 

% Create a shared motorized & spontaneous list.
periods_bothConditions = [periods_motorized; periods_spontaneous]; 
parameters.periods_bothConditions = periods_bothConditions;
parameters.periods_motorized = periods_motorized;
parameters.periods_spontaneous = periods_spontaneous;

% Loop variables.
parameters.loop_variables.mice_all = parameters.mice_all;
parameters.loop_variables.conditions =   {'motorized'; 'spontaneous'};
parameters.loop_variables.conditions_stack_locations =  {'stacks'; 'spontaneous'};
parameters.loop_variables.body_parts = {'FR', 'FL', 'HL', 'tail', 'nose', 'eye'};
parameters.loop_variables.xys = {'x', 'y'};
parameters.loop_variables.velocity_directions = {'x', 'y' , 'total_magnitude'}; % 'total_angle'
parameters.loop_variables.data_types = {'velocity', 'position'};
parameters.loop_variables.periods = periods_bothConditions.condition;
parameters.loop_variables.mean_stds = {'average', 'std_dev'};

%% Import DeepLabCut paw/body extraction data. 
% Calls ImportDLCPupilData.m, but that function doesn't really do anything,
% as RunAnalysis can import it in with a load function.

% Always clear loop list first. 
if isfield(parameters, 'loop_list')
parameters = rmfield(parameters,'loop_list');
end

% Iterators
parameters.loop_list.iterators = {
               'mouse', {'loop_variables.mice_all(:).name'}, 'mouse_iterator'; 
               'day', {'loop_variables.mice_all(', 'mouse_iterator', ').days(:).name'}, 'day_iterator';
               'stack_name', { 'dir("Y:\Sarah\Data\Random Motorized Treadmill\', 'day', '\', 'mouse', '\body\body*filtered.csv").name'}, 'stack_name_iterator'; 
               };

% Abort analysis if there's no corresponding file.
parameters.load_abort_flag = true; 

% Input values
parameters.loop_list.things_to_load.import_in.dir = {'Y:\Sarah\Data\Random Motorized Treadmill\', 'day', '\', 'mouse', '\body\'};
parameters.loop_list.things_to_load.import_in.filename= {'stack_name'}; 
parameters.loop_list.things_to_load.import_in.variable= {'trial_in'}; 
parameters.loop_list.things_to_load.import_in.level = 'stack_name';
parameters.loop_list.things_to_load.import_in.load_function = @importdata;

% Output
parameters.loop_list.things_to_save.import_out.dir = {[parameters.dir_exper 'behavior\body\extracted tracking\'], 'mouse', '\', 'day', '\'};
parameters.loop_list.things_to_save.import_out.filename= {'trial', 'stack_name', '.mat'};
parameters.loop_list.things_to_save.import_out.variable= {'trial'}; 
parameters.loop_list.things_to_save.import_out.level = 'stack_name';

RunAnalysis({@ImportDLCPupilData}, parameters)

%% Calculate velocity by stack.
% Always clear loop list first. 
if isfield(parameters, 'loop_list')
parameters = rmfield(parameters,'loop_list');
end

% Iterators
parameters.loop_list.iterators = {
               'mouse', {'loop_variables.mice_all(:).name'}, 'mouse_iterator'; 
               'day', {'loop_variables.mice_all(', 'mouse_iterator', ').days(:).name'}, 'day_iterator';
               'condition', {'loop_variables.conditions'}, 'condition_iterator';
               'stack', {'getfield(loop_variables, {1}, "mice_all", {',  'mouse_iterator', '}, "days", {', 'day_iterator', '}, ', 'loop_variables.conditions_stack_locations{', 'condition_iterator', '})'}, 'stack_iterator'; 
               };

% Remove outlier positions?
% (removed too many of what looked like okay points when applied to position, now trying velocity)
parameters.removeOutliers = true;

% Columns for each body part (x position, y position, likelihood).
parameters.columns_to_use.FR = 8:10;
parameters.columns_to_use.FL = 11:13;
parameters.columns_to_use.HL = 14:16;
parameters.columns_to_use.tail = 17:19;
parameters.columns_to_use.nose = 2:4;
parameters.columns_to_use.eye = 5:7;

% Likelihood minimum threshold.
parameters.likelihood_threshold = 0.3;

% Number of time points to use in a moving mean (applied to position data).
parameters.position_smoothing_factor = 5; 

% Number of time points to use in a moving mean (applied to calculated velocities).
parameters.velocity_smoothing_factor = 5; 

parameters.maximumOutlierCount = 250;

% Input 
parameters.loop_list.things_to_load.data.dir = {[parameters.dir_exper 'behavior\body\extracted tracking\'], 'mouse', '\', 'day', '\'};
parameters.loop_list.things_to_load.data.filename= {'trialbody', 'stack', '*.mat'}; % Has a variable middle part to the name
parameters.loop_list.things_to_load.data.variable= {'trial.data'}; 
parameters.loop_list.things_to_load.data.level = 'stack';

% Output
parameters.loop_list.things_to_save.velocity.dir = {[parameters.dir_exper 'behavior\body\not normalized\paw velocity\'], 'mouse', '\', 'day', '\'};
parameters.loop_list.things_to_save.velocity.filename= {'velocity', 'stack', '.mat'};
parameters.loop_list.things_to_save.velocity.variable= {'velocity'}; 
parameters.loop_list.things_to_save.velocity.level = 'stack';

parameters.loop_list.things_to_save.position.dir = {[parameters.dir_exper 'behavior\body\not normalized\paw position\'], 'mouse', '\', 'day', '\'};
parameters.loop_list.things_to_save.position.filename= {'position', 'stack', '.mat'};
parameters.loop_list.things_to_save.position.variable= {'position'}; 
parameters.loop_list.things_to_save.position.level = 'stack';

RunAnalysis({@CalculatePawVelocity}, parameters);

%% Find max velocity and position in each direction per day
% % Only use x and y, will have to re-calculate total magnitude after
% % normalization.
% % Concatenate the max velocity in each day (Max is taken after each concatenation, 
% % but only the last is saved.)
% 
% if isfield(parameters, 'loop_list')
% parameters = rmfield(parameters,'loop_list');
% end
% 
% % Iterators   
% % Both motorized & spontaneous stacks are concatenated together.
% parameters.loop_list.iterators = {
%                'data_type', {'loop_variables.data_types'}, 'data_types_iterator';
%                'body_part', {'loop_variables.body_parts'}, 'body_part_iterator';
%                'xy', {'loop_variables.xys'}, 'xy_iterator'; 
%                'mouse', {'loop_variables.mice_all(:).name'}, 'mouse_iterator'; 
%                'day', {'loop_variables.mice_all(', 'mouse_iterator', ').days(:).name'}, 'day_iterator';
%                'stack', {'[loop_variables.mice_all(',  'mouse_iterator', ').days(', 'day_iterator', ').stacks; loop_variables.mice_all(',  'mouse_iterator', ').days(', 'day_iterator', ').spontaneous]'}, 'stack_iterator';
%                  };
% 
% parameters.concatDim = 1;
% parameters.concatenation_level = 'stack';
% parameters.evaluation_instructions = {{};
%                                       {'data_evaluated = max(abs([max(parameters.data) min(parameters.data)]));'}};
% 
% % Input
% parameters.loop_list.things_to_load.data.dir = {[parameters.dir_exper 'behavior\body\not normalized\paw '], 'data_type', '\','mouse', '\', 'day', '\'};
% parameters.loop_list.things_to_load.data.filename = {'data_type', 'stack', '.mat'};
% parameters.loop_list.things_to_load.data.variable = {'data_type', '.', 'body_part', '.', 'xy'}; 
% parameters.loop_list.things_to_load.data.level = 'stack';
% 
% % Outputs
% parameters.loop_list.things_to_save.data_evaluated.dir = {[parameters.dir_exper 'behavior\body\not normalized\paw '], 'data_type', '\', 'mouse', '\', 'day', '\maxes\'};
% parameters.loop_list.things_to_save.data_evaluated.filename = {'day_max_', 'body_part', '_', 'xy', '.mat'};
% parameters.loop_list.things_to_save.data_evaluated.variable = {'max_', 'data_type'}; 
% parameters.loop_list.things_to_save.data_evaluated.level = 'day';
% 
% parameters.loop_list.things_to_rename = {{'concatenated_data', 'data'}};
% 
% RunAnalysis({@ConcatenateData, @EvaluateOnData}, parameters);
% 
% parameters = rmfield(parameters, 'concatenation_level');
% 
% %% Find mean of the daily maximums 
% % concatenate & average across days 
% if isfield(parameters, 'loop_list')
% parameters = rmfield(parameters,'loop_list');
% end
% 
% % Iterators   
% % Both motorized & spontaneous stacks are concatenated together.
% parameters.loop_list.iterators = {
%                'data_type', {'loop_variables.data_types'}, 'data_types_iterator';
%                'body_part', {'loop_variables.body_parts'}, 'body_part_iterator';
%                'xy', {'loop_variables.xys'}, 'xy_iterator'; 
%                'mouse', {'loop_variables.mice_all(:).name'}, 'mouse_iterator'; 
%                'day', {'loop_variables.mice_all(', 'mouse_iterator', ').days(:).name'}, 'day_iterator';
%                };
% 
% parameters.concatDim = 1;
% parameters.concatenation_level = 'day';
% parameters.averageDim = 1;
% 
% parameters.evaluation_instructions = {{};
%                                      {'data_evaluated = rmoutliers(parameters.data, "median");'}};
% % Inputs 
% % daily maximum
% parameters.loop_list.things_to_load.data.dir = {[parameters.dir_exper 'behavior\body\not normalized\paw '], 'data_type', '\', 'mouse', '\', 'day', '\maxes\'};
% parameters.loop_list.things_to_load.data.filename = {'day_max_', 'body_part', '_', 'xy', '.mat'};
% parameters.loop_list.things_to_load.data.variable = {'max_', 'data_type'}; 
% parameters.loop_list.things_to_load.data.level = 'day';
% 
% % Ouputs
% % per mouse average maximum 
% parameters.loop_list.things_to_save.average.dir = {[parameters.dir_exper 'behavior\body\not normalized\paw '], 'data_type', '\', 'mouse', '\across day maxes\'};
% parameters.loop_list.things_to_save.average.filename = {'average_max_', 'body_part', '_', 'xy', '.mat'};
% parameters.loop_list.things_to_save.average.variable = {'average_max'}; 
% parameters.loop_list.things_to_save.average.level = 'mouse';
% % daily maximums concatenated 
% parameters.loop_list.things_to_save.concatenated_data.dir = {[parameters.dir_exper 'behavior\body\not normalized\paw '], 'data_type', '\', 'mouse', '\across day maxes\'};
% parameters.loop_list.things_to_save.concatenated_data.filename = {'all_day_maxes_', 'body_part', '_', 'xy', '.mat'};
% parameters.loop_list.things_to_save.concatenated_data.variable = {'all_day_maxes'}; 
% parameters.loop_list.things_to_save.concatenated_data.level = 'mouse';
% 
% parameters.loop_list.things_to_rename = {{'concatenated_data', 'data'}
%                                          {'data_evaluated', 'data'}
%                                           };
%     
% RunAnalysis({@ConcatenateData, @EvaluateOnData, @AverageData}, parameters);
% 
% %% Normalize velocities with max by day
% % Always clear loop list first. 
% % Use mice_all_nomissing_data
% if isfield(parameters, 'loop_list')
% parameters = rmfield(parameters,'loop_list');
% end
% 
% % Iterators   
% % Both motorized & spontaneous stacks are concatenated together.
% parameters.loop_list.iterators = {
%                'data_type', {'loop_variables.data_types'}, 'data_types_iterator';
%                'mouse', {'loop_variables.mice_all(:).name'}, 'mouse_iterator'; 
%                'day', {'loop_variables.mice_all(', 'mouse_iterator', ').days(:).name'}, 'day_iterator';
%                'stack', {'[loop_variables.mice_all(',  'mouse_iterator', ').days(', 'day_iterator', ').stacks; loop_variables.mice_all(',  'mouse_iterator', ').days(', 'day_iterator', ').spontaneous]'}, 'stack_iterator';
%                'body_part', {'loop_variables.body_parts'}, 'body_part_iterator';
%                'xy', {'loop_variables.xys'}, 'xy_iterator';               
%                };
% 
% parameters.evaluation_instructions = {{['multiplier = parameters.max_for_mouse ./ parameters.max_for_day;'...
%                                         'data_evaluated = parameters.data ./ multiplier;']}};
% 
% % Inputs
% % average max diameter for all days 
% parameters.loop_list.things_to_load.max_for_mouse.dir = {[parameters.dir_exper 'behavior\body\not normalized\paw '], 'data_type', '\', 'mouse', '\across day maxes\'};
% parameters.loop_list.things_to_load.max_for_mouse.filename = {'average_max_', 'body_part', '_', 'xy', '.mat'};
% parameters.loop_list.things_to_load.max_for_mouse.variable = {'average_max'}; 
% parameters.loop_list.things_to_load.max_for_mouse.level = 'xy';
% % max diameter of this day
% parameters.loop_list.things_to_load.max_for_day.dir = {[parameters.dir_exper 'behavior\body\not normalized\paw '], 'data_type', '\', 'mouse', '\', 'day', '\maxes\'};
% parameters.loop_list.things_to_load.max_for_day.filename = {'day_max_', 'body_part', '_', 'xy', '.mat'};
% parameters.loop_list.things_to_load.max_for_day.variable = {'max_', 'data_type'}; 
% parameters.loop_list.things_to_load.max_for_day.level = 'xy';
% % timeseries of velocities
% parameters.loop_list.things_to_load.data.dir = {[parameters.dir_exper 'behavior\body\not normalized\paw '], 'data_type', '\','mouse', '\', 'day', '\'};
% parameters.loop_list.things_to_load.data.filename = {'data_type', 'stack', '.mat'};
% parameters.loop_list.things_to_load.data.variable = {'data_type', '.', 'body_part', '.', 'xy'}; 
% parameters.loop_list.things_to_load.data.level = 'stack';
% 
% % Ouputs
% parameters.loop_list.things_to_save.data_evaluated.dir = {[parameters.dir_exper 'behavior\body\normalized with zscore\paw '], 'data_type', ' normalized\', 'mouse', '\', 'day', '\'};
% parameters.loop_list.things_to_save.data_evaluated.filename = {'data_type', 'stack', '.mat'};
% parameters.loop_list.things_to_save.data_evaluated.variable = {'data_type', '.', 'body_part', '.', 'xy'}; 
% parameters.loop_list.things_to_save.data_evaluated.level = 'stack';
% 
% RunAnalysis({@EvaluateOnData}, parameters);


%% Find average & std velocity and position per day
% Only use x and y, will have to re-calculate total magnitude after
% normalization.
% Concatenate the max velocity in each day (Max is taken after each concatenation, 
% but only the last is saved.)

if isfield(parameters, 'loop_list')
parameters = rmfield(parameters,'loop_list');
end

% Iterators   
% Both motorized & spontaneous stacks are concatenated together.
parameters.loop_list.iterators = {
               'data_type', {'loop_variables.data_types'}, 'data_types_iterator';
               'body_part', {'loop_variables.body_parts'}, 'body_part_iterator';
               'xy', {'loop_variables.xys'}, 'xy_iterator'; 
               'mouse', {'loop_variables.mice_all(:).name'}, 'mouse_iterator'; 
               'day', {'loop_variables.mice_all(', 'mouse_iterator', ').days(:).name'}, 'day_iterator';
               'stack', {'[loop_variables.mice_all(',  'mouse_iterator', ').days(', 'day_iterator', ').stacks; loop_variables.mice_all(',  'mouse_iterator', ').days(', 'day_iterator', ').spontaneous]'}, 'stack_iterator';
                 };

parameters.concatDim = 1;
parameters.concatenation_level = 'stack';
parameters.averageDim = 1;
parameters.evaluation_instructions = {{}; {};
                                      {'data_evaluated = (parameters.data - mean(parameters.data, 1, "omitnan")) ./ std(parameters.data, [],  1, "omitnan");'}};

% Input
parameters.loop_list.things_to_load.data.dir = {[parameters.dir_exper 'behavior\body\not normalized\paw '], 'data_type', '\','mouse', '\', 'day', '\'};
parameters.loop_list.things_to_load.data.filename = {'data_type', 'stack', '.mat'};
parameters.loop_list.things_to_load.data.variable = {'data_type', '.', 'body_part', '.', 'xy'}; 
parameters.loop_list.things_to_load.data.level = 'stack';

% Outputs
% average
parameters.loop_list.things_to_save.average.dir = {[parameters.dir_exper 'behavior\body\not normalized\paw '], 'data_type', '\', 'mouse', '\', 'day', '\averages\'};
parameters.loop_list.things_to_save.average.filename = {'day_average_', 'body_part', '_', 'xy', '.mat'};
parameters.loop_list.things_to_save.average.variable = {'average_', 'data_type'}; 
parameters.loop_list.things_to_save.average.level = 'day';
% std_dev
parameters.loop_list.things_to_save.std_dev.dir = {[parameters.dir_exper 'behavior\body\not normalized\paw '], 'data_type', '\', 'mouse', '\', 'day', '\averages\'};
parameters.loop_list.things_to_save.std_dev.filename = {'day_std_dev_', 'body_part', '_', 'xy', '.mat'};
parameters.loop_list.things_to_save.std_dev.variable = {'std_dev_', 'data_type'}; 
parameters.loop_list.things_to_save.std_dev.level = 'day';


parameters.loop_list.things_to_rename = {{'concatenated_data', 'data'}};
                                           

RunAnalysis({@ConcatenateData, @AverageData}, parameters);

parameters = rmfield(parameters, 'concatenation_level');

%% Apply zscore 
% % Normalize velocities with the average and std found in previous step
% Always clear loop list first. 
% Use mice_all_nomissing_data
if isfield(parameters, 'loop_list')
parameters = rmfield(parameters,'loop_list');
end

% Iterators   
% Both motorized & spontaneous stacks are concatenated together.
parameters.loop_list.iterators = {
               'data_type', {'loop_variables.data_types'}, 'data_types_iterator';
               'mouse', {'loop_variables.mice_all(:).name'}, 'mouse_iterator'; 
               'day', {'loop_variables.mice_all(', 'mouse_iterator', ').days(:).name'}, 'day_iterator';
               'stack', {'[loop_variables.mice_all(',  'mouse_iterator', ').days(', 'day_iterator', ').stacks; loop_variables.mice_all(',  'mouse_iterator', ').days(', 'day_iterator', ').spontaneous]'}, 'stack_iterator';
               'body_part', {'loop_variables.body_parts'}, 'body_part_iterator';
               'xy', {'loop_variables.xys'}, 'xy_iterator';               
               };

parameters.evaluation_instructions = {{'data_evaluated = (parameters.data - parameters.average) ./ parameters.std_dev;'}};

% Inputs
% average of day 
parameters.loop_list.things_to_load.average.dir = {[parameters.dir_exper 'behavior\body\not normalized\paw '], 'data_type', '\', 'mouse', '\', 'day', '\averages\'};
parameters.loop_list.things_to_load.average.filename = {'day_average_', 'body_part', '_', 'xy', '.mat'};
parameters.loop_list.things_to_load.average.variable = {'average_', 'data_type'}; 
parameters.loop_list.things_to_load.average.level = 'day';
% std_dev of day
parameters.loop_list.things_to_load.std_dev.dir = {[parameters.dir_exper 'behavior\body\not normalized\paw '], 'data_type', '\', 'mouse', '\', 'day', '\averages\'};
parameters.loop_list.things_to_load.std_dev.filename = {'day_std_dev_', 'body_part', '_', 'xy', '.mat'};
parameters.loop_list.things_to_load.std_dev.variable = {'std_dev_', 'data_type'}; 
parameters.loop_list.things_to_load.std_dev.level = 'day';
% timeseries of velocities
parameters.loop_list.things_to_load.data.dir = {[parameters.dir_exper 'behavior\body\not normalized\paw '], 'data_type', '\','mouse', '\', 'day', '\'};
parameters.loop_list.things_to_load.data.filename = {'data_type', 'stack', '.mat'};
parameters.loop_list.things_to_load.data.variable = {'data_type', '.', 'body_part', '.', 'xy'}; 
parameters.loop_list.things_to_load.data.level = 'stack';

% Ouputs
parameters.loop_list.things_to_save.data_evaluated.dir = {[parameters.dir_exper 'behavior\body\normalized with zscore\paw '], 'data_type', ' normalized\', 'mouse', '\', 'day', '\'};
parameters.loop_list.things_to_save.data_evaluated.filename = {'data_type', 'stack', '.mat'};
parameters.loop_list.things_to_save.data_evaluated.variable = {'data_type', '.', 'body_part', '.', 'xy'}; 
parameters.loop_list.things_to_save.data_evaluated.level = 'stack';

RunAnalysis({@EvaluateOnData}, parameters);

%% Calculate total magnitude from normalized velocities
if isfield(parameters, 'loop_list')
parameters = rmfield(parameters,'loop_list');
end

% Iterators   
% Both motorized & spontaneous stacks are concatenated together.
parameters.loop_list.iterators = {
               'data_type', {'loop_variables.data_types'}, 'data_types_iterator';
               'mouse', {'loop_variables.mice_all(:).name'}, 'mouse_iterator'; 
               'day', {'loop_variables.mice_all(', 'mouse_iterator', ').days(:).name'}, 'day_iterator';
               'stack', {'[loop_variables.mice_all(',  'mouse_iterator', ').days(', 'day_iterator', ').stacks; loop_variables.mice_all(',  'mouse_iterator', ').days(', 'day_iterator', ').spontaneous]'}, 'stack_iterator';
               'body_part', {'loop_variables.body_parts'}, 'body_part_iterator';             
               };
% Input
parameters.loop_list.things_to_load.data.dir = {[parameters.dir_exper 'behavior\body\normalized with zscore\paw '], 'data_type',  ' normalized\', 'mouse', '\', 'day', '\'};
parameters.loop_list.things_to_load.data.filename = {'data_type', 'stack', '.mat'};
parameters.loop_list.things_to_load.data.variable = {'data_type', '.', 'body_part'}; 
parameters.loop_list.things_to_load.data.level = 'stack';

% Output
% Put in same place
parameters.loop_list.things_to_save.data_with_total_magnitude.dir = {[parameters.dir_exper 'behavior\body\normalized with zscore\paw '], 'data_type',  ' normalized with total magnitude\', 'mouse', '\', 'day', '\'};
parameters.loop_list.things_to_save.data_with_total_magnitude.filename = {'data_type', 'stack', '.mat'};
parameters.loop_list.things_to_save.data_with_total_magnitude.variable = {'data_type', '.', 'body_part'}; 
parameters.loop_list.things_to_save.data_with_total_magnitude.level = 'stack';

RunAnalysis({@CalculateTotalMagnitude}, parameters);

%% Pad short stacks with NaNs.
% Sometimes the behavior cameras were 50-100 frames short, but we still
% want the data that DID get collected. Without this, the segmentation
% steps will throw errors. 

% Not running with RunAnalysis because you don't have to load each of them
% to check their length. --> ***this didn't work, convert to uusing
% RunAnalysis***

% Folder/filenames you're checking.

% Always clear loop list first. 
if isfield(parameters, 'loop_list')
parameters = rmfield(parameters,'loop_list');
end

parameters.loop_list.iterators = {
               'mouse', {'loop_variables.mice_all(:).name'}, 'mouse_iterator'; 
               'day', {'loop_variables.mice_all(', 'mouse_iterator', ').days(:).name'}, 'day_iterator';
               'condition', {'loop_variables.conditions'}, 'condition_iterator';
               'stack', {'getfield(loop_variables, {1}, "mice_all", {',  'mouse_iterator', '}, "days", {', 'day_iterator', '}, ', 'loop_variables.conditions_stack_locations{', 'condition_iterator', '})'}, 'stack_iterator'; 
               'data_type', {'loop_variables.data_types'}, 'data_type_iterator';
               };

% Inputs
parameters.loop_list.things_to_load.input_data.dir = {[parameters.dir_exper 'behavior\body\normalized with zscore\paw '], 'data_type',' normalized with total magnitude\', 'mouse', '\', 'day', '\'};
parameters.loop_list.things_to_load.input_data.filename= {'data_type', 'stack', '.mat'};
parameters.loop_list.things_to_load.input_data.variable= {'data_type'}; 
parameters.loop_list.things_to_load.input_data.level = 'data_type';

% Outputs (will overwrite the short stacks)
parameters.loop_list.things_to_save.output_data.dir = {[parameters.dir_exper 'behavior\body\normalized with zscore\paw '], 'data_type',' normalized with total magnitude\', 'mouse', '\', 'day', '\'};
parameters.loop_list.things_to_save.output_data.filename= {'data_type', 'stack', '.mat'};
parameters.loop_list.things_to_save.output_data.variable= {'data_type'}; 
parameters.loop_list.things_to_save.output_data.level = 'data_type';

RunAnalysis({@PadVelocity}, parameters);

%% If a stack of paw velocity is missing, a vector of NaNs is created.
% This is so the instances stay properly aligned with fluorescence data
% Checks in \body\normalized velocity\, puts into \body\normalized velocity

% Maybe this is where I wanted the no missing data? Not sure. It should be
% accounted for in mice_all.


% Always clear loop list first. 
if isfield(parameters, 'loop_list')
parameters = rmfield(parameters,'loop_list');
end 

% change to do with all body parts, with positions
missing_body_data


%% Motorized: Segment by behavior
% Always clear loop list first. 
if isfield(parameters, 'loop_list')
parameters = rmfield(parameters,'loop_list');
end

% Iterators
parameters.loop_list.iterators = {'mouse', {'loop_variables.mice_all(:).name'}, 'mouse_iterator'; 
               'day', {'loop_variables.mice_all(', 'mouse_iterator', ').days(:).name'}, 'day_iterator';
                   'stack', {'loop_variables.mice_all(',  'mouse_iterator', ').days(', 'day_iterator', ').stacks'}, 'stack_iterator';
                   'body_part', {'loop_variables.body_parts'}, 'body_part_iterator';
                   'velocity_direction', {'loop_variables.velocity_directions'}, 'velocity_direction_iterator' };
 
parameters.loop_variables.periods_nametable = periods_motorized; 

% Skip any files that don't exist (spontaneous or problem files)
parameters.load_abort_flag = true; 

% Dimension of different time range pairs.
parameters.rangePairs = 1; 

% 
parameters.segmentDim = 1;
parameters.concatDim = 2;

% Input values. 
% Extracted timeseries.
parameters.loop_list.things_to_load.timeseries.dir = {[parameters.dir_exper 'behavior\body\normalized with zscore\paw velocity normalized with total magnitude\'], 'mouse', '\', 'day', '\'};
parameters.loop_list.things_to_load.timeseries.filename= {'velocity', 'stack', '.mat'};
parameters.loop_list.things_to_load.timeseries.variable= {'velocity.', 'body_part', '.', 'velocity_direction'}; 
parameters.loop_list.things_to_load.timeseries.level = 'stack';
% Time ranges
parameters.loop_list.things_to_load.time_ranges.dir = {[parameters.dir_exper 'behavior\motorized\period instances table format\'], 'mouse', '\', 'day', '\'};
parameters.loop_list.things_to_load.time_ranges.filename= {'all_periods_', 'stack', '.mat'};
parameters.loop_list.things_to_load.time_ranges.variable= {'all_periods.time_ranges'}; 
parameters.loop_list.things_to_load.time_ranges.level = 'stack';

% Output Values
parameters.loop_list.things_to_save.segmented_timeseries.dir = {[parameters.dir_exper 'behavior\body\normalized with zscore\segmented velocities\'], 'body_part', '\', 'velocity_direction', '\motorized\', 'mouse', '\', 'day', '\'};
parameters.loop_list.things_to_save.segmented_timeseries.filename= {'segmented_timeseries_', '_', 'stack', '.mat'};
parameters.loop_list.things_to_save.segmented_timeseries.variable= {'segmented_timeseries'}; 
parameters.loop_list.things_to_save.segmented_timeseries.level = 'velocity_direction';

RunAnalysis({@SegmentTimeseriesData}, parameters);

%% Spontaneous: Segment by behavior
% Always clear loop list first. 
if isfield(parameters, 'loop_list')
parameters = rmfield(parameters,'loop_list');
end

% Iterators
parameters.loop_list.iterators = {'mouse', {'loop_variables.mice_all(:).name'}, 'mouse_iterator'; 
               'day', {'loop_variables.mice_all(', 'mouse_iterator', ').days(:).name'}, 'day_iterator';
                   'stack', {'loop_variables.mice_all(',  'mouse_iterator', ').days(', 'day_iterator', ').spontaneous'}, 'stack_iterator';
                   'body_part', {'loop_variables.body_parts'}, 'body_part_iterator';
                   'velocity_direction', {'loop_variables.velocity_directions'}, 'velocity_direction_iterator';
                   'period', {'loop_variables.periods_spontaneous{:}'}, 'period_iterator'};

parameters.loop_variables.periods_spontaneous = periods_spontaneous.condition; 

% Skip any files that don't exist (motorized or problem files)
parameters.load_abort_flag = true; 

% Dimension of different time range pairs.
parameters.rangePairs = 1; 

% 
parameters.segmentDim = 1;
parameters.concatDim = 2;

% Input values. 
% Extracted timeseries.
parameters.loop_list.things_to_load.timeseries.dir = {[parameters.dir_exper 'behavior\body\normalized with zscore\paw velocity normalized with total magnitude\'], 'mouse', '\', 'day', '\'};
parameters.loop_list.things_to_load.timeseries.filename= {'velocity', 'stack', '.mat'};
parameters.loop_list.things_to_load.timeseries.variable= {'velocity.', 'body_part', '.', 'velocity_direction'}; 
parameters.loop_list.things_to_load.timeseries.level = 'stack';
% Time ranges
parameters.loop_list.things_to_load.time_ranges.dir = {[parameters.dir_exper 'behavior\spontaneous\segmented behavior periods\'], 'mouse', '\', 'day', '\'};
parameters.loop_list.things_to_load.time_ranges.filename= {'behavior_periods_', 'stack', '.mat'};
parameters.loop_list.things_to_load.time_ranges.variable= {'behavior_periods.', 'period'}; 
parameters.loop_list.things_to_load.time_ranges.level = 'stack';

% Output Values
% (Convert to cell format to be compatible with motorized in below code)
parameters.loop_list.things_to_save.segmented_timeseries.dir = {[parameters.dir_exper 'behavior\body\normalized with zscore\segmented velocities\'], 'body_part', '\', 'velocity_direction', '\spontaneous\', 'mouse', '\', 'day', '\'};
parameters.loop_list.things_to_save.segmented_timeseries.filename= {'segmented_timeseries__', 'stack', '.mat'};
parameters.loop_list.things_to_save.segmented_timeseries.variable= {'segmented_timeseries{', 'period_iterator', ', 1}'}; 
parameters.loop_list.things_to_save.segmented_timeseries.level = 'velocity_direction';

RunAnalysis({@SegmentTimeseriesData}, parameters);

%% %% Look for stacks when number of instances don't match those of fluorescence.
% (Just do motorized rest, that's the one you're having problems with).
% Don't need to load, so don't use RunAnalysis.
% Only need to run 1 body part & velocity direction (FL, total magnitude).
% if isfield(parameters, 'loop_list')
% parameters = rmfield(parameters,'loop_list');
% end
% 
% parameters.loop_list.iterators = {
%                'mouse', {'loop_variables.mice_all(:).name'}, 'mouse_iterator'; 
%                'day', {'loop_variables.mice_all(', 'mouse_iterator', ').days(:).name'}, 'day_iterator';
%                'condition', {'loop_variables.conditions'}, 'condition_iterator';
%                'stack', {'getfield(loop_variables, {1}, "mice_all", {',  'mouse_iterator', '}, "days", {', 'day_iterator', '}, ', 'loop_variables.conditions_stack_locations{', 'condition_iterator', '})'}, 'stack_iterator';
%                };
% 
% % If using a sub-structure, need to use regular loading
% parameters.use_substructure = true; 
% 
% parameters.checkingDim = 2;
% parameters.check_againstDim = 3;
% 
% % Input values
% parameters.loop_list.things_to_check.dir = {[parameters.dir_exper 'behavior\body\normalized with zscore\segmented velocities\FL\x\'], 'condition', '\', 'mouse', '\', 'day', '\'};
% parameters.loop_list.things_to_check.filename= {'segmented_timeseries__', 'stack', '.mat'};  
% parameters.loop_list.things_to_check.variable = {'segmented_timeseries'};
% 
% parameters.loop_list.check_against.dir = {[parameters.dir_exper 'fluorescence analysis\segmented timeseries\'], 'condition', '\', 'mouse', '\', 'day', '\'};
% parameters.loop_list.check_against.filename= {'segmented_timeseries_', 'stack', '.mat'};  
% parameters.loop_list.check_against.variable = {'segmented_timeseries'};
% 
% % Output
% parameters.loop_list.mismatched_data.dir = {[parameters.dir_exper 'behavior\body\']};
% parameters.loop_list.mismatched_data.filename= {'mismatched_data.mat'};
% 
% CheckSizes2(parameters);

%% Notes for removal.
% For these, can get rid of last instances and will match

% load the mismatch info
load('Y:\Sarah\Analysis\Experiments\Random Motorized Treadmill\behavior\body\mismatched_data.mat');

% For each mismatch,
for itemi = 2:size(mismatched_data, 1)

    mouse = mismatched_data{itemi, 1};
    day = mismatched_data{itemi, 2};
    condition = mismatched_data{itemi, 3};
    stack = mismatched_data{itemi, 4};
    period_index = mismatched_data{itemi, 5};
    
    disp([mouse ', ' day ', ' condition ', ' stack ', ' period_index]);
   
    % load the flourescence data 
    load(['Y:\Sarah\Analysis\Experiments\Random Motorized Treadmill\fluorescence analysis\segmented timeseries\' condition '\' mouse '\' day '\segmented_timeseries_' stack '.mat'])
    fluor = segmented_timeseries;

    % find number of instances you should have
    % if empty, make it set = 0 (because 3rd dim will be 1)
    if  ~isempty(fluor{period_index})
        correct_num = size(fluor{period_index}, 3);
    else
        correct_num = 0;
    end   

    % tell user the calculated correct number
    disp(num2str(correct_num));
    
    % For each body part
    for bodyparti = 1:numel(parameters.loop_variables.body_parts) 
        bodypart = parameters.loop_variables.body_parts{bodyparti};
        disp(bodypart);
        
        % For each velocity direction,
        for directioni = 1:numel(parameters.loop_variables.velocity_directions)
            direction = parameters.loop_variables.velocity_directions{directioni};
            disp(direction);

            % Load velocity
            load(['Y:\Sarah\Analysis\Experiments\Random Motorized Treadmill\behavior\body\normalized with zscore\segmented velocities\' bodypart '\' direction '\' condition '\' mouse '\' day '\segmented_timeseries__' stack '.mat'])
            velocity_original = segmented_timeseries;
           
            % Shorten the number of instances to match fluorescence
            velocity_new = velocity_original;
            velocity_new{period_index} = velocity_original{period_index}(:, 1:correct_num);

            % Convert back to saving variable name
            segmented_timeseries = velocity_new; 
           
            % Save in same place
            save(['Y:\Sarah\Analysis\Experiments\Random Motorized Treadmill\behavior\body\normalized with zscore\segmented velocities\' bodypart '\' direction '\' condition '\' mouse '\' day '\segmented_timeseries__' stack '.mat'], 'segmented_timeseries')
            
            % Save the original
            save(['Y:\Sarah\Analysis\Experiments\Random Motorized Treadmill\behavior\body\normalized with zscore\segmented velocities\' bodypart '\' direction '\' condition '\' mouse '\' day '\segmented_timeseries__' stack '_original.mat'], 'velocity_original')
        end 
    end 
end 

%% Concatenate within behavior (spon & motorized independently) 
% Always clear loop list first. 
if isfield(parameters, 'loop_list')
parameters = rmfield(parameters,'loop_list');
end

% Iterators
parameters.loop_list.iterators = {
               'condition', {'loop_variables.conditions'}, 'condition_iterator';
               'body_part', {'loop_variables.body_parts'}, 'body_part_iterator';
               'velocity_direction', {'loop_variables.velocity_directions'}, 'velocity_direction_iterator';
               'mouse', {'loop_variables.mice_all(:).name'}, 'mouse_iterator'; 
               'day', {'loop_variables.mice_all(', 'mouse_iterator', ').days(:).name'}, 'day_iterator';
               'stack', {'getfield(loop_variables, {1}, "mice_all", {',  'mouse_iterator', '}, "days", {', 'day_iterator', '}, ', 'loop_variables.conditions_stack_locations{', 'condition_iterator', '})'}, 'stack_iterator'; 
               };

% Dimension to concatenate the timeseries across.
parameters.concatDim = 2; 
parameters.concatenate_across_cells = false; 

% Clear any reshaping instructions 
if isfield(parameters, 'reshapeDims')
    parameters = rmfield(parameters,'reshapeDims');
end

% Input Values
parameters.loop_list.things_to_load.data.dir = {[parameters.dir_exper 'behavior\body\normalized with zscore\segmented velocities\'], 'body_part', '\', 'velocity_direction', '\', 'condition', '\', 'mouse', '\', 'day', '\'};
parameters.loop_list.things_to_load.data.filename= {'segmented_timeseries__', 'stack', '.mat'};
parameters.loop_list.things_to_load.data.variable= {'segmented_timeseries'}; 
parameters.loop_list.things_to_load.data.level = 'stack';

% Output values
parameters.loop_list.things_to_save.concatenated_data.dir = {[parameters.dir_exper 'behavior\body\normalized with zscore\concatenated velocity\'], 'body_part', '\', 'velocity_direction', '\', 'condition', '\', 'mouse', '\'};
parameters.loop_list.things_to_save.concatenated_data.filename= {'concatenated_velocity_all_periods.mat'};
parameters.loop_list.things_to_save.concatenated_data.variable= {'velocity'}; 
parameters.loop_list.things_to_save.concatenated_data.level = 'mouse';

RunAnalysis({@ConcatenateData}, parameters);

%% Concatenate spon & motorized into same cell array.
if isfield(parameters, 'loop_list')
parameters = rmfield(parameters,'loop_list');
end

% Is so you can use a single loop for calculations. 
parameters.loop_list.iterators = {
               'body_part', {'loop_variables.body_parts'}, 'body_part_iterator';
               'velocity_direction', {'loop_variables.velocity_directions'}, 'velocity_direction_iterator';
               'mouse', {'loop_variables.mice_all(:).name'}, 'mouse_iterator'; 
               'condition', 'loop_variables.conditions', 'condition_iterator';
                };

% Tell it to concatenate across cells, not within cells. 
parameters.concatenate_across_cells = true; 
parameters.concatDim = 1;
parameters.concatenation_level = 'condition';

% Input Values 
parameters.loop_list.things_to_load.data.dir = {[parameters.dir_exper 'behavior\body\normalized with zscore\concatenated velocity\'], 'body_part', '\', 'velocity_direction', '\', 'condition', '\', 'mouse', '\'};
parameters.loop_list.things_to_load.data.filename= {'concatenated_velocity_all_periods.mat'};
parameters.loop_list.things_to_load.data.variable= {'velocity'}; 
parameters.loop_list.things_to_load.data.level = 'condition';

% Output values
parameters.loop_list.things_to_save.concatenated_data.dir = {[parameters.dir_exper 'behavior\body\normalized with zscore\concatenated velocity\'], 'body_part', '\', 'velocity_direction', '\both conditions\', 'mouse', '\'};
parameters.loop_list.things_to_save.concatenated_data.filename= {'concatenated_velocity_all_periods.mat'};
parameters.loop_list.things_to_save.concatenated_data.variable= {'velocity_all'}; 
parameters.loop_list.things_to_save.concatenated_data.level = 'mouse';

RunAnalysis({@ConcatenateData}, parameters);

parameters.concatenate_across_cells = false;

%% Roll paw velocity timeseries
% Makes it easier to remove already-found correlation & behavior instances 
% Always clear loop list first. 
if isfield(parameters, 'loop_list')
parameters = rmfield(parameters,'loop_list');
end

% Iterators
parameters.loop_list.iterators = {
               'body_part', {'loop_variables.body_parts'}, 'body_part_iterator';
               'velocity_direction', {'loop_variables.velocity_directions'}, 'velocity_direction_iterator';
               'mouse', {'loop_variables.mice_all(:).name'}, 'mouse_iterator'; 
               'period', {'loop_variables.periods'}, 'period_iterator';
                };
parameters.loop_variables.mice_all = parameters.mice_all;
parameters.loop_variables.periods = periods_bothConditions.condition;

% Dimension to roll across (time dimension). Will automatically add new
% data to the last + 1 dimension. 
parameters.rollDim = 1; 

% Window and step sizes (in frames)
parameters.windowSize = 20;
parameters.stepSize = 5; 

% Input 
parameters.loop_list.things_to_load.data.dir = {[parameters.dir_exper 'behavior\body\normalized with zscore\concatenated velocity\'], 'body_part', '\', 'velocity_direction', '\both conditions\', 'mouse', '\'};
parameters.loop_list.things_to_load.data.filename= {'concatenated_velocity_all_periods.mat'};
parameters.loop_list.things_to_load.data.variable= {'velocity_all{', 'period_iterator', '}'}; 
parameters.loop_list.things_to_load.data.level = 'mouse';

% Output
parameters.loop_list.things_to_save.data_rolled.dir = {[parameters.dir_exper 'behavior\body\normalized with zscore\rolled concatenated velocity\'], 'body_part', '\', 'velocity_direction', '\both conditions\', 'mouse', '\'};
parameters.loop_list.things_to_save.data_rolled.filename= {'velocity_rolled.mat'};
parameters.loop_list.things_to_save.data_rolled.variable= {'velocity_rolled{', 'period_iterator', ',1}'}; 
parameters.loop_list.things_to_save.data_rolled.level = 'mouse';

parameters.loop_list.things_to_save.roll_number.dir = {[parameters.dir_exper 'behavior\body\normalized with zscore\rolled concatenated velocity\'], 'body_part', '\', 'velocity_direction', '\both conditions\', 'mouse', '\'};
parameters.loop_list.things_to_save.roll_number.filename= {'velocity_rolled_rollnumber.mat'};
parameters.loop_list.things_to_save.roll_number.variable= {'roll_number{', 'period_iterator', ',1}'}; 
parameters.loop_list.things_to_save.roll_number.level = 'mouse';

RunAnalysis({@RollData}, parameters);

%% Take mean velocity per roll 
% **** fix this --> isn't putting things in the right place ***

if isfield(parameters, 'loop_list')
parameters = rmfield(parameters,'loop_list');
end

% Iterators
parameters.loop_list.iterators = {
               'body_part', {'loop_variables.body_parts'}, 'body_part_iterator';
               'velocity_direction', {'loop_variables.velocity_directions'}, 'velocity_direction_iterator';
               'mouse', {'loop_variables.mice_all(:).name'}, 'mouse_iterator'; 
               'period', {'loop_variables.periods'}, 'period_iterator';
                };

% Permute data so instances are in last dimension 
parameters.DimOrder = [1, 3, 2];

% Dimension to average across 
parameters.averageDim  = 1; 

% Load & put in the "true" roll number there's supposed to be.
load([parameters.dir_exper 'behavior\spontaneous\rolled concatenated velocity\1087\velocity_rolled_rollnumber.mat'], 'roll_number'); 
parameters.roll_number = roll_number;
clear roll_number;

parameters.useSqueeze = false;

% Evaluation instructions (removes first dimension that alwas = 1)
parameters.evaluation_instructions = {{}; {};{ 'z = size(parameters.data);'...
                                               'data_evaluated = reshape(parameters.data,[z(2:end) 1]);'}};
  
% Input
parameters.loop_list.things_to_load.data.dir = {[parameters.dir_exper 'behavior\body\normalized with zscore\rolled concatenated velocity\'], 'body_part', '\', 'velocity_direction', '\both conditions\', 'mouse', '\'};
parameters.loop_list.things_to_load.data.filename= {'velocity_rolled.mat'};
parameters.loop_list.things_to_load.data.variable= {'velocity_rolled{', 'period_iterator', ',1}'}; 
parameters.loop_list.things_to_load.data.level = 'mouse';
% roll number 
parameters.loop_list.things_to_load.roll_number.dir = {[parameters.dir_exper]};
parameters.loop_list.things_to_load.roll_number.filename= {'roll_number.mat'};
parameters.loop_list.things_to_load.roll_number.variable= {'roll_number{', 'period_iterator', ',1}'}; 
parameters.loop_list.things_to_load.roll_number.level = 'start';

% Output 
parameters.loop_list.things_to_save.data_evaluated.dir = {[parameters.dir_exper 'behavior\body\normalized with zscore\value per roll velocity\'], 'body_part', '\', 'velocity_direction', '\', 'mouse', '\'};
parameters.loop_list.things_to_save.data_evaluated.filename= {'velocity_averaged_by_instance.mat'};
parameters.loop_list.things_to_save.data_evaluated.variable= {'velocity_averaged_by_instance{', 'period_iterator', ',1}'}; 
parameters.loop_list.things_to_save.data_evaluated.level = 'mouse';

parameters.loop_list.things_to_rename = {{'data_permuted', 'data'}; 
                                         { 'average', 'data'}};

RunAnalysis({@PermuteData, @AverageData, @EvaluateOnData}, parameters);

%% Velocity for fluorescence PLSR
% Instead of rolling velocity, reshape so each time point is its own instance
% (Is for fluorescence PLSR)

% Put into same cell array, to match other formatting

% Always clear loop list first. 
if isfield(parameters, 'loop_list')
parameters = rmfield(parameters,'loop_list');
end

% Iterators
parameters.loop_list.iterators = {
               'body_part', {'loop_variables.body_parts'}, 'body_part_iterator';
               'velocity_direction', {'loop_variables.velocity_directions'}, 'velocity_direction_iterator';
               'mouse', {'loop_variables.mice_all(:).name'}, 'mouse_iterator'; 
               'period', {'loop_variables.periods'}, 'period_iterator';
                };


% one column, timepoints of each instance are together 
parameters.evaluation_instructions = {{'data_evaluated = transpose(reshape(parameters.data, [], 1));'}};
% Input 
parameters.loop_list.things_to_load.data.dir = {[parameters.dir_exper 'behavior\body\normalized with zscore\concatenated velocity\'], 'body_part', '\', 'velocity_direction', '\both conditions\', 'mouse', '\'};
parameters.loop_list.things_to_load.data.filename= {'concatenated_velocity_all_periods.mat'};
parameters.loop_list.things_to_load.data.variable= {'velocity_all{', 'period_iterator', '}'}; 
parameters.loop_list.things_to_load.data.level = 'mouse';

% Output
parameters.loop_list.things_to_save.data_evaluated.dir = {[parameters.dir_exper 'behavior\body\normalized with zscore\velocity for fluorescence PLSR\'], 'body_part', '\', 'velocity_direction', '\',  'mouse', '\'};
parameters.loop_list.things_to_save.data_evaluated.filename= {'velocity_forFluorescence.mat'};
parameters.loop_list.things_to_save.data_evaluated.variable= {'velocity_forFluorescence{', 'period_iterator', ', 1}'}; 
parameters.loop_list.things_to_save.data_evaluated.level = 'mouse';

RunAnalysis({@EvaluateOnData}, parameters);


%% 
% shortening instructions 
parameters.shorten_dimensions = '41:end, :, :';
%% Velocity for fluorescence PLSR
% Instead of rolling velocity, reshape so each time point is its own instance
% (Is for fluorescence PLSR)

% Put into same cell array, to match other formatting

% Always clear loop list first. 
if isfield(parameters, 'loop_list')
parameters = rmfield(parameters,'loop_list');
end

% Iterators
parameters.loop_list.iterators = {
               'body_part', {'loop_variables.body_parts'}, 'body_part_iterator';
               'velocity_direction', {'loop_variables.velocity_directions'}, 'velocity_direction_iterator';
               'mouse', {'loop_variables.mice_all(:).name'}, 'mouse_iterator'; 
               'period', {'loop_variables.periods'}, 'period_iterator';
                };


% one column, timepoints of each instance are together 
parameters.evaluation_instructions = {{'data_evaluated = transpose(reshape(parameters.data, [], 1));'}};
% Input 
parameters.loop_list.things_to_load.data.dir = {[parameters.dir_exper 'behavior\body\normalized with zscore\concatenated velocity\'], 'body_part', '\', 'velocity_direction', '\both conditions\', 'mouse', '\'};
parameters.loop_list.things_to_load.data.filename= {'concatenated_velocity_all_periods.mat'};
parameters.loop_list.things_to_load.data.variable= {'velocity_all{', 'period_iterator', '}'}; 
parameters.loop_list.things_to_load.data.level = 'mouse';

% Output
parameters.loop_list.things_to_save.data_evaluated.dir = {[parameters.dir_exper 'behavior\body\normalized with zscore\velocity for fluorescence PLSR\'], 'body_part', '\', 'velocity_direction', '\',  'mouse', '\'};
parameters.loop_list.things_to_save.data_evaluated.filename= {'velocity_forFluorescence.mat'};
parameters.loop_list.things_to_save.data_evaluated.variable= {'velocity_forFluorescence{', 'period_iterator', ', 1}'}; 
parameters.loop_list.things_to_save.data_evaluated.level = 'mouse';

RunAnalysis({@EvaluateOnData}, parameters);

%% Velocity for fluorescence PLSR WARNING PERIODS
% Shorten certain periods first

% Put into same cell array, to match other formatting

% Always clear loop list first. 
if isfield(parameters, 'loop_list')
parameters = rmfield(parameters,'loop_list');
end

% Iterators
parameters.loop_list.iterators = {
               'body_part', {'loop_variables.body_parts'}, 'body_part_iterator';
               'velocity_direction', {'loop_variables.velocity_directions'}, 'velocity_direction_iterator';
               'mouse', {'loop_variables.mice_all(:).name'}, 'mouse_iterator'; 
               'period', {'loop_variables.periods'}, 'period_iterator';
                };

parameters.shorten_dimensions = '41:end, :, :';

% one column, timepoints of each instance are together 
parameters.evaluation_instructions = {{};
                                      {'data_evaluated = transpose(reshape(parameters.data, [], 1));'}};
% Input 
% indices to shorten.
parameters.loop_list.things_to_load.indices_to_shorten.dir = {[parameters.dir_exper 'PLSR Warning Periods\']};
parameters.loop_list.things_to_load.indices_to_shorten.filename= {'indices_to_shorten.mat'};
parameters.loop_list.things_to_load.indices_to_shorten.variable= {'indices_to_shorten_original_index'}; 
parameters.loop_list.things_to_load.indices_to_shorten.level = 'start';
% data
parameters.loop_list.things_to_load.data.dir = {[parameters.dir_exper 'behavior\body\normalized with zscore\concatenated velocity\'], 'body_part', '\', 'velocity_direction', '\both conditions\', 'mouse', '\'};
parameters.loop_list.things_to_load.data.filename= {'concatenated_velocity_all_periods.mat'};
parameters.loop_list.things_to_load.data.variable= {'velocity_all{', 'period_iterator', '}'}; 
parameters.loop_list.things_to_load.data.level = 'mouse';

% Output
parameters.loop_list.things_to_save.data_evaluated.dir = {[parameters.dir_exper 'behavior\body\normalized with zscore\velocity for fluorescence PLSR Warning Periods\'], 'body_part', '\', 'velocity_direction', '\',  'mouse', '\'};
parameters.loop_list.things_to_save.data_evaluated.filename= {'velocity_forFluorescence.mat'};
parameters.loop_list.things_to_save.data_evaluated.variable= {'velocity_forFluorescence{', 'period_iterator', ', 1}'}; 
parameters.loop_list.things_to_save.data_evaluated.level = 'mouse';

parameters.loop_list.things_to_rename = {{'data_shortened', 'data'}};

RunAnalysis({@ShortenFluorescenceWarningPeriods, @EvaluateOnData}, parameters);

%% Take the normalization means, Calculate a mean for each mouse

% Always clear loop list first. 
if isfield(parameters, 'loop_list')
parameters = rmfield(parameters,'loop_list');
end

% Iterators   
% Both motorized & spontaneous stacks are concatenated together.
parameters.loop_list.iterators = {
               'data_type', {'loop_variables.data_types'}, 'data_types_iterator';
               'body_part', {'loop_variables.body_parts'}, 'body_part_iterator';
               'xy', {'loop_variables.xys'}, 'xy_iterator'; 
               'mouse', {'loop_variables.mice_all(:).name'}, 'mouse_iterator'; 
               'day', {'loop_variables.mice_all(', 'mouse_iterator', ').days(:).name'}, 'day_iterator'};

parameters.concatDim = 1;
parameters.concatenation_level = 'day';
parameters.averageDim = 1;

% Inputs
% average
parameters.loop_list.things_to_load.data.dir = {[parameters.dir_exper 'behavior\body\not normalized\paw '], 'data_type', '\', 'mouse', '\', 'day', '\averages\'};
parameters.loop_list.things_to_load.data.filename = {'day_average_', 'body_part', '_', 'xy', '.mat'};
parameters.loop_list.things_to_load.data.variable = {'average_', 'data_type'}; 
parameters.loop_list.things_to_load.data.level = 'day';

% Outputs
% average of averages
parameters.loop_list.things_to_save.average.dir = {[parameters.dir_exper 'behavior\body\not normalized\paw '], 'data_type', '\', 'mouse', '\all days\averages\'};
parameters.loop_list.things_to_save.average.filename = {'mouse_average_', 'body_part', '_', 'xy', '.mat'};
parameters.loop_list.things_to_save.average.variable = {'average_', 'data_type'}; 
parameters.loop_list.things_to_save.average.level = 'mouse';

parameters.loop_list.things_to_rename = {{'concatenated_data', 'data'}};
RunAnalysis({@ConcatenateData, @AverageData}, parameters)

%% repeat for std devs 

% Always clear loop list first. 
if isfield(parameters, 'loop_list')
parameters = rmfield(parameters,'loop_list');
end

% Iterators   
% Both motorized & spontaneous stacks are concatenated together.
parameters.loop_list.iterators = {
               'data_type', {'loop_variables.data_types'}, 'data_types_iterator';
               'body_part', {'loop_variables.body_parts'}, 'body_part_iterator';
               'xy', {'loop_variables.xys'}, 'xy_iterator'; 
               'mouse', {'loop_variables.mice_all(:).name'}, 'mouse_iterator'; 
               'day', {'loop_variables.mice_all(', 'mouse_iterator', ').days(:).name'}, 'day_iterator'};

parameters.concatDim = 1;
parameters.concatenation_level = 'day';
parameters.averageDim = 1;

% Inputs
% std_dev
parameters.loop_list.things_to_load.data.dir = {[parameters.dir_exper 'behavior\body\not normalized\paw '], 'data_type', '\', 'mouse', '\', 'day', '\averages\'};
parameters.loop_list.things_to_load.data.filename = {'day_std_dev_', 'body_part', '_', 'xy', '.mat'};
parameters.loop_list.things_to_load.data.variable = {'std_dev_', 'data_type'}; 
parameters.loop_list.things_to_load.data.level = 'day';

% Outputs
% average of stds
parameters.loop_list.things_to_save.average.dir = {[parameters.dir_exper 'behavior\body\not normalized\paw '], 'data_type', '\', 'mouse', '\all days\stds\'};
parameters.loop_list.things_to_save.average.filename = {'mouse_std_dev_', 'body_part', '_', 'xy', '.mat'};
parameters.loop_list.things_to_save.average.variable = {'std_dev_', 'data_type'}; 
parameters.loop_list.things_to_save.average.level = 'mouse';

parameters.loop_list.things_to_rename = {{'concatenated_data', 'data'}};
RunAnalysis({@ConcatenateData, @AverageData}, parameters)

%% Calculate a normalization mean across mice
% Always clear loop list first. 
if isfield(parameters, 'loop_list')
parameters = rmfield(parameters,'loop_list');
end

% Iterators   
% Both motorized & spontaneous stacks are concatenated together.
parameters.loop_list.iterators = {
               'data_type', {'loop_variables.data_types'}, 'data_types_iterator';
               'body_part', {'loop_variables.body_parts'}, 'body_part_iterator';
               'xy', {'loop_variables.xys'}, 'xy_iterator'; 
               'mouse', {'loop_variables.mice_all(:).name'}, 'mouse_iterator'; 
                };

parameters.concatDim = 1;
parameters.concatenation_level = 'mouse';
parameters.averageDim = 1;

% Inputs
parameters.loop_list.things_to_load.data.dir = {[parameters.dir_exper 'behavior\body\not normalized\paw '], 'data_type', '\', 'mouse', '\all days\averages\'};
parameters.loop_list.things_to_load.data.filename = {'mouse_average_', 'body_part', '_', 'xy', '.mat'};
parameters.loop_list.things_to_load.data.variable = {'average_', 'data_type'}; 
parameters.loop_list.things_to_load.data.level = 'mouse';

% Outputs
% average of averages
parameters.loop_list.things_to_save.average.dir = {[parameters.dir_exper 'behavior\body\not normalized\paw '], 'data_type', '\averages across mice\'};
parameters.loop_list.things_to_save.average.filename = {'average_', 'body_part', '_', 'xy', '.mat'};
parameters.loop_list.things_to_save.average.variable = {'average_', 'data_type'}; 
parameters.loop_list.things_to_save.average.level = 'xy';

parameters.loop_list.things_to_rename = {{'concatenated_data', 'data'}};
RunAnalysis({@ConcatenateData, @AverageData}, parameters)

%% repeat for standard devs

% Always clear loop list first. 
if isfield(parameters, 'loop_list')
parameters = rmfield(parameters,'loop_list');
end

% Iterators   
% Both motorized & spontaneous stacks are concatenated together.
parameters.loop_list.iterators = {
               'data_type', {'loop_variables.data_types'}, 'data_types_iterator';
               'body_part', {'loop_variables.body_parts'}, 'body_part_iterator';
               'xy', {'loop_variables.xys'}, 'xy_iterator'; 
               'mouse', {'loop_variables.mice_all(:).name'}, 'mouse_iterator'; 
                };

parameters.concatDim = 1;
parameters.concatenation_level = 'mouse';
parameters.averageDim = 1;

% Inputs
parameters.loop_list.things_to_load.data.dir = {[parameters.dir_exper 'behavior\body\not normalized\paw '], 'data_type', '\', 'mouse', '\all days\stds\'};
parameters.loop_list.things_to_load.data.filename = {'mouse_std_dev_', 'body_part', '_', 'xy', '.mat'};
parameters.loop_list.things_to_load.data.variable = {'std_dev_', 'data_type'}; 
parameters.loop_list.things_to_load.data.level = 'mouse';

% Outputs
% average of stds
parameters.loop_list.things_to_save.average.dir = {[parameters.dir_exper 'behavior\body\not normalized\paw '], 'data_type', '\std_devs across mice\'};
parameters.loop_list.things_to_save.average.filename = {'std_dev_', 'body_part', '_', 'xy', '.mat'};
parameters.loop_list.things_to_save.average.variable = {'std_dev_', 'data_type'}; 
parameters.loop_list.things_to_save.average.level = 'xy';

parameters.loop_list.things_to_rename = {{'concatenated_data', 'data'}};
RunAnalysis({@ConcatenateData, @AverageData}, parameters)

%% Calculate averages & stds for total magnitudes
% use the already-found values from above

% Always clear loop list first. 
if isfield(parameters, 'loop_list')
parameters = rmfield(parameters,'loop_list');
end

% Iterators   
% Both motorized & spontaneous stacks are concatenated together.
parameters.loop_list.iterators = {
               'data_type', {'loop_variables.data_types'}, 'data_types_iterator';
               'body_part', {'loop_variables.body_parts'}, 'body_part_iterator';
               'mean_std', {'loop_variables.mean_stds'}, 'body_part_iterator';
                };

parameters.evaluation_instructions = {{'x = parameters.x;'...
                                       'y = parameters.y;'... 
                                       'data_evaluated = sqrt(x^2 + y ^2);'}};

% Inputs
% x 
parameters.loop_list.things_to_load.x.dir = {[parameters.dir_exper 'behavior\body\not normalized\paw '], 'data_type', '\', 'mean_std', 's across mice\'};
parameters.loop_list.things_to_load.x.filename = {'mean_std', '_', 'body_part', '_x.mat'};
parameters.loop_list.things_to_load.x.variable = {'mean_std', '_', 'data_type'}; 
parameters.loop_list.things_to_load.x.level = 'mean_std';
% y 
parameters.loop_list.things_to_load.y.dir = {[parameters.dir_exper 'behavior\body\not normalized\paw '], 'data_type', '\', 'mean_std', 's across mice\'};
parameters.loop_list.things_to_load.y.filename = {'mean_std', '_', 'body_part', '_y.mat'};
parameters.loop_list.things_to_load.y.variable = {'mean_std', '_', 'data_type'}; 
parameters.loop_list.things_to_load.y.level = 'mean_std';

% Outputs
parameters.loop_list.things_to_save.data_evaluated.dir = {[parameters.dir_exper 'behavior\body\not normalized\paw '], 'data_type', '\', 'mean_std', 's across mice\'};
parameters.loop_list.things_to_save.data_evaluated.filename = {'mean_std', '_', 'body_part', '_total_magnitude.mat'};
parameters.loop_list.things_to_save.data_evaluated.variable = {'mean_std', '_', 'data_type'}; 
parameters.loop_list.things_to_save.data_evaluated.level = 'mean_std';

RunAnalysis({@EvaluateOnData}, parameters);

%% put them all together for easier loading 
% stds you'll need later:
parameters.loop_variables.later_stds = {'tail_total_magnitude'
 'nose_total_magnitude'
 'FL_total_magnitude'
 'HL_total_magnitude'
 'FL_x'};

% Always clear loop list first. 
if isfield(parameters, 'loop_list')
parameters = rmfield(parameters,'loop_list');
end

% Iterators   
parameters.loop_list.iterators = {
               'later_std', {'loop_variables.later_stds'}, 'later_std_iterator';
                };
parameters.evaluation_instructions = {{'data_evaluated = parameters.data;'}};

% Inputs 
parameters.loop_list.things_to_load.data.dir = {[parameters.dir_exper 'behavior\body\not normalized\paw velocity\std_devs across mice\']};
parameters.loop_list.things_to_load.data.filename = {'std_dev_', 'later_std', '.mat'};
parameters.loop_list.things_to_load.data.variable = {'std_dev_velocity'}; 
parameters.loop_list.things_to_load.data.level = 'later_std';

% Outputs 
parameters.loop_list.things_to_save.data_evaluated.dir = {[parameters.dir_exper 'behavior\body\not normalized\paw velocity\std_devs across mice\']};
parameters.loop_list.things_to_save.data_evaluated.filename = {'stds_together.mat'};
parameters.loop_list.things_to_save.data_evaluated.variable = {'stds_together.', 'later_std'}; 
parameters.loop_list.things_to_save.data_evaluated.level = 'end';

RunAnalysis({@EvaluateOnData}, parameters);

%% rename the fields

load('Y:\Sarah\Analysis\Experiments\Random Motorized Treadmill\behavior\body\not normalized\paw velocity\std_devs across mice\stds_together.mat')
old = stds_together;
clear stds_together;
stds_together.tail = old.tail_total_magnitude;
stds_together.nose = old.nose_total_magnitude;
stds_together.FL = old.FL_total_magnitude;
stds_together.HL = old.HL_total_magnitude;
stds_together.x = old.FL_x;
save('Y:\Sarah\Analysis\Experiments\Random Motorized Treadmill\behavior\body\not normalized\paw velocity\std_devs across mice\stds_together.mat', 'stds_together')
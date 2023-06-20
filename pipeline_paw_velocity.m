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
parameters.loop_variables.body_parts =  {'FR', 'FL', 'HL', 'tail', 'nose', 'eye'};
parameters.loop_variables.velocity_directions = {'x', 'y', 'total_magnitude', 'total_angle'};
parameters.loop_variables.data_types = {'velocity', 'position'};
parameters.loop_variables.periods = periods_bothConditions.condition;

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
parameters.loop_list.things_to_save.velocity.dir = {[parameters.dir_exper 'behavior\body\paw velocity\'], 'mouse', '\', 'day', '\'};
parameters.loop_list.things_to_save.velocity.filename= {'velocity', 'stack', '.mat'};
parameters.loop_list.things_to_save.velocity.variable= {'velocity'}; 
parameters.loop_list.things_to_save.velocity.level = 'stack';

parameters.loop_list.things_to_save.position.dir = {[parameters.dir_exper 'behavior\body\paw position\'], 'mouse', '\', 'day', '\'};
parameters.loop_list.things_to_save.position.filename= {'position', 'stack', '.mat'};
parameters.loop_list.things_to_save.position.variable= {'position'}; 
parameters.loop_list.things_to_save.position.level = 'stack';

RunAnalysis({@CalculatePawVelocity}, parameters);

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
parameters.loop_list.things_to_load.input_data.dir = {[parameters.dir_exper 'behavior\body\paw '], 'data_type','\', 'mouse', '\', 'day', '\'};
parameters.loop_list.things_to_load.input_data.filename= {'data_type', 'stack', '.mat'};
parameters.loop_list.things_to_load.input_data.variable= {'data_type'}; 
parameters.loop_list.things_to_load.input_data.level = 'data_type';

% Outputs (will overwrite the short stacks)
parameters.loop_list.things_to_save.output_data.dir = {[parameters.dir_exper 'behavior\body\paw '], 'data_type','\', 'mouse', '\', 'day', '\'};
parameters.loop_list.things_to_save.output_data.filename= {'data_type', 'stack', '.mat'};
parameters.loop_list.things_to_save.output_data.variable= {'data_type'}; 
parameters.loop_list.things_to_save.output_data.level = 'data_type';

RunAnalysis({@PadVelocity}, parameters);

%% If a stack of paw velocity is missing, a vector of NaNs is created.
% This is so the instances stay properly aligned with fluorescence data
% Checks in \body\paw velocity\, puts into \body\paw velocity

% Maybe this is where I wanted the no missing data? Not sure. It should be
% accounted for in mice_all.

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
parameters.loop_list.things_to_load.timeseries.dir = {[parameters.dir_exper 'behavior\body\paw velocity\'], 'mouse', '\', 'day', '\'};
parameters.loop_list.things_to_load.timeseries.filename= {'velocity', 'stack', '.mat'};
parameters.loop_list.things_to_load.timeseries.variable= {'velocity.', 'body_part', '.', 'velocity_direction'}; 
parameters.loop_list.things_to_load.timeseries.level = 'stack';
% Time ranges
parameters.loop_list.things_to_load.time_ranges.dir = {[parameters.dir_exper 'behavior\motorized\period instances table format\'], 'mouse', '\', 'day', '\'};
parameters.loop_list.things_to_load.time_ranges.filename= {'all_periods_', 'stack', '.mat'};
parameters.loop_list.things_to_load.time_ranges.variable= {'all_periods.time_ranges'}; 
parameters.loop_list.things_to_load.time_ranges.level = 'stack';

% Output Values
parameters.loop_list.things_to_save.segmented_timeseries.dir = {[parameters.dir_exper 'behavior\body\segmented velocities\'], 'body_part', '\', 'velocity_direction', '\motorized\', 'mouse', '\', 'day', '\'};
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
parameters.loop_list.things_to_load.timeseries.dir = {[parameters.dir_exper 'behavior\body\paw velocity\'], 'mouse', '\', 'day', '\'};
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
parameters.loop_list.things_to_save.segmented_timeseries.dir = {[parameters.dir_exper 'behavior\body\segmented velocities\'], 'body_part', '\', 'velocity_direction', '\spontaneous\', 'mouse', '\', 'day', '\'};
parameters.loop_list.things_to_save.segmented_timeseries.filename= {'segmented_timeseries__', 'stack', '.mat'};
parameters.loop_list.things_to_save.segmented_timeseries.variable= {'segmented_timeseries{', 'period_iterator', ', 1}'}; 
parameters.loop_list.things_to_save.segmented_timeseries.level = 'velocity_direction';

RunAnalysis({@SegmentTimeseriesData}, parameters);

%% %% Look for stacks when number of instances don't match those of fluorescence.
% (Just do motorized rest, that's the one you're having problems with).
% Don't need to load, so don't use RunAnalysis.
% Only need to run 1 body part & velocity direction (FL, total magnitude).
if isfield(parameters, 'loop_list')
parameters = rmfield(parameters,'loop_list');
end

parameters.loop_list.iterators = {
               'mouse', {'loop_variables.mice_all(:).name'}, 'mouse_iterator'; 
               'day', {'loop_variables.mice_all(', 'mouse_iterator', ').days(:).name'}, 'day_iterator';
               'condition', {'loop_variables.conditions'}, 'condition_iterator';
               'stack', {'getfield(loop_variables, {1}, "mice_all", {',  'mouse_iterator', '}, "days", {', 'day_iterator', '}, ', 'loop_variables.conditions_stack_locations{', 'condition_iterator', '})'}, 'stack_iterator';
               };

% If using a sub-structure, need to use regular loading
parameters.use_substructure = true; 

parameters.checkingDim = 2;
parameters.check_againstDim = 3;

% Input values
parameters.loop_list.things_to_check.dir = {[parameters.dir_exper 'behavior\body\segmented velocities\FL\total_magnitude\'], 'condition', '\', 'mouse', '\', 'day', '\'};
parameters.loop_list.things_to_check.filename= {'segmented_timeseries__', 'stack', '.mat'};  
parameters.loop_list.things_to_check.variable = {'segmented_timeseries'};

parameters.loop_list.check_against.dir = {[parameters.dir_exper 'fluorescence analysis\segmented timeseries\'], 'condition', '\', 'mouse', '\', 'day', '\'};
parameters.loop_list.check_against.filename= {'segmented_timeseries_', 'stack', '.mat'};  
parameters.loop_list.check_against.variable = {'segmented_timeseries'};

% Output
parameters.loop_list.mismatched_data.dir = {[parameters.dir_exper 'behavior\body\']};
parameters.loop_list.mismatched_data.filename= {'mismatched_data.mat'};

CheckSizes2(parameters);

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
            load(['Y:\Sarah\Analysis\Experiments\Random Motorized Treadmill\behavior\body\segmented velocities\' bodypart '\' direction '\' condition '\' mouse '\' day '\segmented_timeseries__' stack '.mat'])
            velocity_original = segmented_timeseries;
           
            % Shorten the number of instances to match fluorescence
            velocity_new = velocity_original;
            velocity_new{period_index} = velocity_original{period_index}(1:correct_num);

            % Convert back to saving variable name
            segmented_timeseries = velocity_new; 
           
            % Save in same place
            save(['Y:\Sarah\Analysis\Experiments\Random Motorized Treadmill\behavior\body\segmented velocities\' bodypart '\' direction '\' condition '\' mouse '\' day '\segmented_timeseries__' stack '.mat'], 'segmented_timeseries')
            
            % Save the original
            save(['Y:\Sarah\Analysis\Experiments\Random Motorized Treadmill\behavior\body\segmented velocities\' bodypart '\' direction '\' condition '\' mouse '\' day '\segmented_timeseries__' stack '_original.mat'], 'velocity_original')
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
parameters.loop_list.things_to_load.data.dir = {[parameters.dir_exper 'behavior\body\segmented velocities\'], 'body_part', '\', 'velocity_direction', '\', 'condition', '\', 'mouse', '\', 'day', '\'};
parameters.loop_list.things_to_load.data.filename= {'segmented_timeseries__', 'stack', '.mat'};
parameters.loop_list.things_to_load.data.variable= {'segmented_timeseries'}; 
parameters.loop_list.things_to_load.data.level = 'stack';

% Output values
parameters.loop_list.things_to_save.concatenated_data.dir = {[parameters.dir_exper 'behavior\body\concatenated velocity\'], 'body_part', '\', 'velocity_direction', '\', 'condition', '\', 'mouse', '\'};
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
parameters.loop_list.things_to_load.data.dir = {[parameters.dir_exper 'behavior\body\concatenated velocity\'], 'body_part', '\', 'velocity_direction', '\', 'condition', '\', 'mouse', '\'};
parameters.loop_list.things_to_load.data.filename= {'concatenated_velocity_all_periods.mat'};
parameters.loop_list.things_to_load.data.variable= {'velocity'}; 
parameters.loop_list.things_to_load.data.level = 'condition';

% Output values
parameters.loop_list.things_to_save.concatenated_data.dir = {[parameters.dir_exper 'behavior\body\concatenated velocity\'], 'body_part', '\', 'velocity_direction', '\both conditions\', 'mouse', '\'};
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
parameters.loop_list.things_to_load.data.dir = {[parameters.dir_exper 'behavior\body\concatenated velocity\'], 'body_part', '\', 'velocity_direction', '\both conditions\', 'mouse', '\'};
parameters.loop_list.things_to_load.data.filename= {'concatenated_velocity_all_periods.mat'};
parameters.loop_list.things_to_load.data.variable= {'velocity_all{', 'period_iterator', '}'}; 
parameters.loop_list.things_to_load.data.level = 'mouse';

% Output
parameters.loop_list.things_to_save.data_rolled.dir = {[parameters.dir_exper 'behavior\body\rolled concatenated velocity\'], 'body_part', '\', 'velocity_direction', '\both conditions\', 'mouse', '\'};
parameters.loop_list.things_to_save.data_rolled.filename= {'velocity_rolled.mat'};
parameters.loop_list.things_to_save.data_rolled.variable= {'velocity_rolled{', 'period_iterator', ',1}'}; 
parameters.loop_list.things_to_save.data_rolled.level = 'mouse';

parameters.loop_list.things_to_save.roll_number.dir = {[parameters.dir_exper 'behavior\body\rolled concatenated velocity\'], 'body_part', '\', 'velocity_direction', '\both conditions\', 'mouse', '\'};
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
parameters.loop_list.things_to_load.data.dir = {[parameters.dir_exper 'behavior\body\rolled concatenated velocity\'], 'body_part', '\', 'velocity_direction', '\both conditions\', 'mouse', '\'};
parameters.loop_list.things_to_load.data.filename= {'velocity_rolled.mat'};
parameters.loop_list.things_to_load.data.variable= {'velocity_rolled{', 'period_iterator', ',1}'}; 
parameters.loop_list.things_to_load.data.level = 'mouse';
% roll number 
parameters.loop_list.things_to_load.roll_number.dir = {[parameters.dir_exper]};
parameters.loop_list.things_to_load.roll_number.filename= {'roll_number.mat'};
parameters.loop_list.things_to_load.roll_number.variable= {'roll_number{', 'period_iterator', ',1}'}; 
parameters.loop_list.things_to_load.roll_number.level = 'start';

% Output 
parameters.loop_list.things_to_save.data_evaluated.dir = {[parameters.dir_exper 'behavior\body\value per roll velocity\'], 'body_part', '\', 'velocity_direction', '\', 'mouse', '\'};
parameters.loop_list.things_to_save.data_evaluated.filename= {'velocity_averaged_by_instance.mat'};
parameters.loop_list.things_to_save.data_evaluated.variable= {'velocity_averaged_by_instance{', 'period_iterator', ',1}'}; 
parameters.loop_list.things_to_save.data_evaluated.level = 'mouse';

parameters.loop_list.things_to_rename = {{'data_permuted', 'data'}; 
                                         { 'average', 'data'}};

RunAnalysis({@PermuteData, @AverageData, @EvaluateOnData}, parameters);


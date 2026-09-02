function output = dataset_indvec_ForwardStep_JM()
% DATASET_INDVEC_FORWARDSTEP_JM
% Modified version of dataset_indvec.m
% Includes pre-stimulus timepoints and classifies AVA responses.
%
% Function checks for AVA low-fall state ("not-reversal") preceding stimulus.
% Outputs:
%   1) traces: AVA onsets & AVA low-fall states
%   2) ind_vec: AVA_low, AVA_high, hit, miss, hit/miss with AVA_low
%   3) trigger_vector: stimulus-triggered and spontaneous AVA onsets
%
% Data must be in 'WBstruct_head_data_extracted.mat' with variable 'Results'.
%
% Saved Output:
%   hit_miss_trials.mat (struct with worm data)

%% Parameters
parameters.total_time         = 1890;   % recording duration (s)
parameters.baseline           = 450;    % baseline duration (s)
parameters.afterAVA           = 30;     % (unused in current code)
parameters.critical_end_point = 8.5;    % response window (s)
parameters.min_win            = -60;    % pre-stimulus window (s)
parameters.max_win            = 30;     % post-stimulus window (s)
parameters.stimdelay          = 0;      % stimulus delay (s)
parameters.beforeAVA          = -2;     % AVA pre-onset check window (s)

%% Initialize Output
output = struct('wormID', [], 'trigger_vector', [], 'ind_vec', [], 'beh_anno', []);

%% Load Data
load('WBstruct_head_data_extracted.mat', 'Results')

%% Process Each Worm
for i = 1:length(Results)

    % --- Basic Info ---
    flnm       = strsplit(Results(i).filename,'_');
    wormID     = strcat(flnm{1},'_',flnm{2});
    FrRate     = Results(i).fps;
    Neurons    = convert_cells_to_char(Results(i).NeuronNames);
    AVAL_ID    = find(strcmp(Neurons,'AVAL'));
    aval_trace = Results(i).traceColoring(:,AVAL_ID);

    % --- AVA states ---
    AVAstate_lowfall = double(aval_trace == 1 | aval_trace == 4)'; 
    AVAstate_rise    = double(aval_trace == 2)'; 
    AVA_onsets       = [0 diff(AVAstate_rise) > 0]; % rising edges

    traces = struct( ...
        'AVA_onsets', [], ...
        'AVAstate_lowfall', [] );

    % --- Stimulus Info ---
    stim        = Results(i).stimulus.switchtimes;
    upshifts    = round(stim(1:2:end) * FrRate); % frames
    num_stim_up = length(upshifts);

    % --- Trial Extraction ---
    for l = 1:num_stim_up
        selStim  = upshifts(l) + parameters.stimdelay * FrRate;
        winStart = selStim + parameters.min_win * FrRate;
        winEnd   = selStim + parameters.max_win * FrRate;

        traces.AVA_onsets       = [traces.AVA_onsets; AVA_onsets(round(winStart:winEnd))];
        traces.AVAstate_lowfall = [traces.AVAstate_lowfall; AVAstate_lowfall(round(winStart:winEnd))];
    end

    % --- Trial Classification ---
    stim_point = abs(parameters.min_win * FrRate);
    beforeAVA  = round(parameters.beforeAVA * FrRate);

    indvec = struct('AVA_low', [], 'AVA_high', [], 'hit', [], 'miss', [], ...
                    'avaLowHit', [], 'avaLowMiss', []);

    for k = 1:size(traces.AVAstate_lowfall, 1)
        if all(traces.AVAstate_lowfall(k, stim_point + beforeAVA : stim_point))
            indvec.AVA_low  = [indvec.AVA_low; k];
        else
            indvec.AVA_high = [indvec.AVA_high; k];
        end
    end

    % --- Hit/Miss Classification ---
    AVA_first_onsets = zeros(size(traces.AVA_onsets(:, stim_point-1:end)));

    for p = 1:size(traces.AVA_onsets, 1)
        idx = find(traces.AVA_onsets(p, stim_point-1:end), 1, 'first');
        if ~isempty(idx)
            AVA_first_onsets(p, idx) = 1;
        end
    end

    crit_end = parameters.critical_end_point * FrRate;

    for z = 1:size(AVA_first_onsets, 1)
        if any(AVA_first_onsets(z, 1:crit_end))
            indvec.hit  = [indvec.hit; z];
        else
            indvec.miss = [indvec.miss; z];
        end
    end

    % --- Combined categories ---
    indvec.avaLowHit  = intersect(indvec.AVA_low, indvec.hit);
    indvec.avaLowMiss = intersect(indvec.AVA_low, indvec.miss);

    % --- Trigger Vectors ---
    trig_vector = struct('ava_hit', [], 'ava_hit_low', [], ...
                         'trials_hit', [], 'trials_miss', [], ...
                         'trials_hit_AVAlow', [], 'trials_miss_AVAlow', [], ...
                         'ava_rest', []);

    trig_vector_temp = NaN(size(AVA_first_onsets,1),1);

    for x = 1:size(AVA_first_onsets,1)
        idx = find(AVA_first_onsets(x,:),1);
        if ~isempty(idx)
            trig_vector_temp(x) = idx;
        end
    end

    trig_vector_temp = trig_vector_temp + upshifts' - 1;

    trig_vector.ava_hit      = trig_vector_temp(indvec.hit)';
    trig_vector.ava_hit_low  = trig_vector_temp(indvec.avaLowHit);
    trig_vector.trials_hit   = upshifts(indvec.hit);
    trig_vector.trials_miss  = upshifts(indvec.miss);
    trig_vector.trials_hit_AVAlow  = upshifts(indvec.avaLowHit);
    trig_vector.trials_miss_AVAlow = upshifts(indvec.avaLowMiss);

    % --- Spontaneous AVA onsets ---
    allOnsets = find(AVA_onsets)';
    ava_control = setdiff(allOnsets, trig_vector.ava_hit_low);
    ava_control = ava_control(ava_control > parameters.baseline*FrRate & ...
                              ava_control < (parameters.total_time - 30)*FrRate);

    for s = 1:length(ava_control)
        idx_range = (ava_control(s) + round(parameters.beforeAVA * FrRate)) : (ava_control(s)-1);
        if all(AVAstate_lowfall(idx_range))
            trig_vector.ava_rest = [trig_vector.ava_rest, ava_control(s)];
        end
    end

    % --- Save Worm Output ---
    output(i).wormID        = wormID;
    output(i).trigger_vector= trig_vector;
    output(i).ind_vec       = indvec;
    output(i).beh_anno      = aval_trace';
end

%% Save Final Output
save hit_miss_trials output;

end

%% --- PARAMETERS (user-defined) ---
hz = 10;                     % Sampling rate (Hz)
speed_threshold = 0.3;       % Max speed threshold (mm/s) for tracking error
bin_size_sec = 5;            % Bin size in seconds
prewin_sec = 60;             % Pre-trigger window (sec)
postwin_sec = 30;            % Post-trigger window (sec)
stimulus_delay_sec = 7;     % Stimulus delay (sec)
critical_window_sec = 8.5;   % Time window for considering a hit (sec)
trig_win_sec = 30;           % Window around reversal onset for triggered speed
trigger_interval = 90;       % Interval between triggers (sec)
trigger_end = 1800;          % Last trigger time (sec)
baseline = 450;              % time to consider for baseline 
smooth_window = 30;          % Smoothing window (frames)
preres_start_sec = 64;       % Start of preresponse window (sec)
preres_end_sec = 68.5;       % End of preresponse window (sec)
start_window_start_sec = 60; % Start of start value window (sec)
start_window_end_sec = 63;   % End of start value window (sec)
trials= 16;
perm_parameter=1000;
before_stimulus=2;%sec

%% --- FILE LOADING ---
table_rec = dir("*TablePosRecord.txt");
beh_anno = csvread('manual_annotation.csv');
load('response_annotation.mat');

%% --- INITIALIZATION ---
num_files = length(table_rec);
bin_frame = bin_size_sec * hz;
prewin = prewin_sec * hz;
postwin = postwin_sec * hz;
winsize = (prewin_sec + postwin_sec) * hz;
stimulus_delay = stimulus_delay_sec * hz;
critical_window = critical_window_sec * hz;
trig_win = trig_win_sec * hz;
start_win = [start_window_start_sec, start_window_end_sec] * hz;
preres_win = [preres_start_sec, preres_end_sec] * hz;
lnbase = baseline * hz; % amount of Baseline-values before stimulus, which will be shown in plot; IN frames (e.g. 300 for 30s before stimulus)
trigger_times = (baseline:trigger_interval:trigger_end);
triggers = (trigger_times + stimulus_delay_sec) * hz;
timevec = [1:winsize]/hz -prewin_sec;
total_time = baseline + (prewin_sec +postwin_sec)* trials ;   % in seconds
frames = total_time * hz;
shifts = [lnbase:winsize:frames];

% Output variables
hit_speed = []; miss_speed = []; all_stimtrig_speed = [];
hit_rev_onset = []; miss_rev_onset = []; all_stimtrig_revonset = [];
hit_turn_onset = []; miss_turn_onset = []; all_stimtrig_turnonset = [];
all_response = []; hit_rev_trig_speed = []; rev_rest_trig_speed = [];
hit_revs = []; Output=struct(); Output.revOnsets=[];
reversals=[]; rev_onsets=[]; rev_onset_frames=[]; 
All_trials_beh=[]; All_randomtrig_trials=[];
%% --- MAIN LOOP ---
for i = 1:num_files
    disp(table_rec(i).name)
    stage_pos = readtable(table_rec(i).name);
    X = table2array(stage_pos(:,2));
    Y = table2array(stage_pos(:,3));
    
    % Position and speed
    speed = NaN(18900,1);
    diff_x = diff(X); diff_y = diff(Y);
    dis = sqrt(diff_x.^2 + diff_y.^2);
    speed(1:length(dis)) = dis / (1/hz);
    
    speed(speed > speed_threshold) = NaN;
    speed(isnan(beh_anno(:,i))) = NaN;
    speed(beh_anno(:,i) == 1) = NaN;  % Remove reversals
    
    % Behavior annotations
    anno = beh_anno(:,i);
    rev=anno;rev(anno>1)=0;rev(isnan(rev))=0;
    turn=anno;turn(anno<=1)=0;turn(anno>1)=1;

    rev_onset=diff(rev')>0; rev_onset=[0 rev_onset];
    turn_onset=diff(turn')>0;turn_onset=[0 turn_onset];
    rev_onsets(i,:)=rev_onset;
    reversals(i,:)=rev';
    
    rev_onset(isnan(rev)) = NaN;
    turn_onset(isnan(turn)) = NaN;
    rev_onset_frames = find(rev_onset == 1);
    
    AllSpeed(i,:) = speed';
    Avg_baseline_speed(i,1) = nanmean(speed(1:baseline*hz));
    Avg_speed(i,1) = nanmean(speed);
    std_speed(i,1) = nanstd(speed);
    
    % Binning
    num_bins = floor(length(speed) / bin_frame);
    for b = 1:num_bins
        idx = (b-1)*bin_frame+1 : b*bin_frame;
        binned_speed_persec(i,b) = nanmean(speed(idx));
        binned_revonsets(i,b) = nansum(rev_onset(idx));
        binned_turnonsets(i,b) = nansum(turn_onset(idx));
    end
       
    % Trigger averaging
    stimtrig_speed = []; stimtrig_revonsets = []; stimtrig_turnonsets = [];
    hit_rev = []; beh_perworm=[];random_trigger=[];
    random_trigger_point=randi([prewin_sec*hz+1, frames-postwin_sec*hz], 1, 16);
    for j = 1:length(triggers)
        if triggers(j) + postwin <= length(speed)
            win_range = triggers(j) - prewin + 1 : triggers(j) + postwin;
            stimtrig_speed(j,:) = speed(win_range)';
            stimtrig_revonsets(j,:) = rev_onset(win_range)';
            stimtrig_turnonsets(j,:) = turn_onset(win_range)';
            beh_perworm(j,:)=beh_anno(win_range)';
            random_trigger(j,:)=rev_onsets(i,random_trigger_point(j)-prewin_sec*hz+1:random_trigger_point(j)+postwin_sec*hz);
            if any(stimtrig_revonsets(j, prewin+1 : prewin + critical_window))
                onset_idx = find(stimtrig_revonsets(j, prewin+1 : prewin + critical_window + 1), 1);
                hit_rev(end+1) = triggers(j) + onset_idx;
            end
        end
    end
     
    Output(i).revOnsets=stimtrig_revonsets;
    
    hit_revs = [hit_revs, hit_rev];
    rev_rest = setdiff(rev_onset_frames, hit_rev);
    
    % Triggered speed for hit and rest reversals
    for c = 1:length(hit_rev)
        idx = hit_rev(c) - trig_win + 1 : hit_rev(c) + trig_win;
        if all(idx > 0 & idx <= length(speed))
            hit_rev_trig_speed(end+1,:) = speed(idx)';
        end
    end
    
    for d = 1:length(rev_rest)
        idx = rev_rest(d) - trig_win + 1 : rev_rest(d) + trig_win;
        if all(idx > 0 & idx <= length(speed))
            rev_rest_trig_speed(end+1,:) = speed(idx)';
        end
    end
    
    % Sorting hit/miss trials
    hits = find(response(i,:) == 1);
    miss = find(response(i,:) == 0);
    
    hit_speed = [hit_speed; stimtrig_speed(hits,:)];
    miss_speed = [miss_speed; stimtrig_speed(miss,:)];
    all_stimtrig_speed = [all_stimtrig_speed; stimtrig_speed];
    all_response = [all_response; response(i,:)'];
    
    hit_rev_onset = [hit_rev_onset; stimtrig_revonsets(hits,:)];
    miss_rev_onset = [miss_rev_onset; stimtrig_revonsets(miss,:)];
    all_stimtrig_revonset = [all_stimtrig_revonset; stimtrig_revonsets];
    
    hit_turn_onset = [hit_turn_onset; stimtrig_turnonsets(hits,:)];
    miss_turn_onset = [miss_turn_onset; stimtrig_turnonsets(miss,:)];
    all_stimtrig_turnonset = [all_stimtrig_turnonset; stimtrig_turnonsets];
    
    All_trials_beh=[All_trials_beh; beh_perworm];
    All_randomtrig_trials=[All_randomtrig_trials;random_trigger];
end

%% --- POSTPROCESSING ---
% speed
hit_start_value = nanmean(hit_speed(:,start_win(1):start_win(2)), 2);
miss_start_value = nanmean(miss_speed(:,start_win(1):start_win(2)), 2);

hit_preres_value = nanmean(hit_speed(:,preres_win(1):preres_win(2)), 2);
miss_preres_value = nanmean(miss_speed(:,preres_win(1):preres_win(2)), 2);

Avg_speed = nanmean(smoothdata(AllSpeed, 2, 'movmean', smooth_window, 'omitnan'));
std_speed = std(AllSpeed, 0, 'omitnan');

% reversals onset
where_nan=isnan(all_stimtrig_revonset);
where_no_nan=find(sum(where_nan,2)==0);
Full_track_stimtrig_trials=all_stimtrig_revonset(where_no_nan,:);
Full_track_stimtrig_beh=All_trials_beh(where_no_nan,:);
Full_track_stimtrig_trials_turns=all_stimtrig_turnonset(where_no_nan,:);
% Full_track_stimtrig_speed=All_stimtrig_speed(where_no_nan,:);
random_trig_trials=All_randomtrig_trials(where_no_nan,:);

first_reversal_onsets = zeros(size(Full_track_stimtrig_trials(:, prewin+1:end)));
first_reversal_onsets_down = zeros(size(Full_track_stimtrig_trials(:, 1:prewin)));
first_rev_frame=[];
for p = 1: size(Full_track_stimtrig_trials ,1)
    
    first_rev_frame=[first_rev_frame,find(Full_track_stimtrig_trials(p, prewin+1:end) , 1, 'first')];   
    first_reversal_onsets(p,find(Full_track_stimtrig_trials(p, prewin+1:end) , 1, 'first')) = 1;
%     first_reversal_onsets(p,find(Full_track_stimtrig_trials(p, 645:end) , 1, 'first')) = 1;

    first_reversal_onsets_down(p,find(Full_track_stimtrig_trials(p, 1:prewin) , 1, 'first')) = 1;

end
no_rev_trials=find(sum(first_reversal_onsets,2)==0);
rev_trials=find(sum(first_reversal_onsets,2)==1);
turn_trials=find(sum(Full_track_stimtrig_trials_turns(:,prewin+1:prewin+critical_window_sec*hz),2)>=1);


%% calculating cumulative probability of reversal onset with random cntrl
upshifts = {};
downshifts = {};
Avg_cumulative_prob_upshift=[];Avg_cumulative_prob_downshift=[];
Quant=struct();rand_trial_cntrl=[];
response=NaN(num_files,trials);

for w=1:length(Output)
    Quant(w).revOnsets_upshift = Output(w).revOnsets(:,(prewin_sec*hz+1:end));
    Quant(w).revOnsets_downshift = Output(w).revOnsets(:,1:prewin_sec*hz);
    
    is_nan_up=isnan(Quant(w).revOnsets_upshift);
    not_nan_up=find(sum(is_nan_up,2)==0);
    
    Quant(w).fullTrack_rev_Onsets_upshift=Quant(w).revOnsets_upshift(not_nan_up,:);
    
    is_nan_down=isnan(Quant(w).revOnsets_downshift);
    not_nan_down=find(sum(is_nan_down,2)==0);
    
    Quant(w).fullTrack_rev_Onsets_downshift=Quant(w).revOnsets_downshift(not_nan_down,:);
    
    response(w,:)=sum(Quant(w).revOnsets_upshift(:,1:critical_window_sec*hz),2);
    pre_rev(w,:)=sum(Output(w).revOnsets(:,prewin-before_stimulus*hz:prewin),2);
    post_rev(w,:)=sum(Quant(w).revOnsets_upshift(:,:),2);
    
    cumulative_prob(w).revOnset_upshift= cumsum(Quant(w).revOnsets_upshift,2);
    cumulative_prob(w).revOnset_downshift= cumsum(Quant(w).revOnsets_downshift,2);
    
%     Avg_cumulative_prob_upshift(w,:)=nanmean(cumulative_prob(w).revOnset_upshift,1);
%     Avg_cumulative_prob_downshift(w,:)=nanmean(cumulative_prob(w).revOnset_downshift,1);
%     Avg_cumulative_prob_upshift=[Avg_cumulative_prob_upshift;cumulative_prob(w).revOnset_upshift];
%     Avg_cumulative_prob_downshift=[Avg_cumulative_prob_downshift;cumulative_prob(w).revOnset_downshift];
    
    exclusion=[];
    for t = 1: trials
        upshifts{t} = [shifts(1,t)+1 : shifts(1,t)+300];
        downshifts{t} = [shifts(1,t)+301 : shifts(1,t)+ 900];
        upshift_frames= cell2mat(upshifts);
        downshift_frames= cell2mat(downshifts);
        exclusion=[exclusion,shifts(t)-(postwin_sec*hz):shifts(t)];
    end
    
    exclusion_window=[upshift_frames,exclusion];
    
    
    %randomised trial control
    
    perm_window_ind= ~ismember([1:(total_time-postwin_sec)*hz],exclusion_window); %exclude 30s around stim and also at the end 30 sec for the random triger point
    perm_window = find(perm_window_ind==1);
    rand_trial_rev_onset=[];
    Avg_rand_trial_revoset=[];
    Avg_rand_trial_revOnset=[];
    rand_trial_riseOnset_prob=[];
    for j=1:perm_parameter
          rand_trial_trig_ind = randperm(size(perm_window,2) , length(upshifts));
          rand_trial_trig_point=perm_window(rand_trial_trig_ind);
          for y=1:length(rand_trial_trig_point)
    
          rand_trial_rev_onset(y,:)= nanmean(rev_onsets(:,(rand_trial_trig_point(y)+1:(rand_trial_trig_point(y)+postwin_sec*hz))));
          end
    
         Avg_rand_trial_revoset(j,:)= mean(rand_trial_rev_onset);
    end
    Avg_rand_trial_revOnset=mean(Avg_rand_trial_revoset);
    
    % save the cumsum of  avg
    rand_trial_cntrl(w,:)= cumsum(Avg_rand_trial_revOnset,2);
end

response(response>=1)=1;
response(pre_rev>=1)=2;
% response(response==0&post_rev>=1)=NaN;


%% --- SAVE OUTPUTS (using csvwrite) ---

% Define output file names
hit_file = 'hit_speed.csv';
miss_file = 'miss_speed.csv';

% Save to CSV
csvwrite(hit_file, hit_speed);
csvwrite(miss_file, miss_speed);

disp(['Saved hit speed to ', hit_file]);
disp(['Saved miss speed to ', miss_file]);

%%
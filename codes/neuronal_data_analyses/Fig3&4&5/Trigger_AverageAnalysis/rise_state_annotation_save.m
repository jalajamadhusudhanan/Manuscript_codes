
%%
load('WBstruct_head_data_extracted.mat', 'Results');

minimum_window = -60 ; %in sec
maximum_window = 30; %in sec
prestimulus_period = 450; %in sec
Interpolation_windowsize = 9450;%CHANGE!!! depending on the recording frame rate/fps
permutation_parameter = 1000; % randomization factor
stimulus_period= 30; %sec
total_time=1890;
critical_window_sec=8.5;
trials= 16;
frame_rate = Interpolation_windowsize/total_time;
stimulus = Results(1).stimulus.switchtimes;
upshifts= stimulus(1:2:length(stimulus));
downshifts= stimulus(2:2:length(stimulus));
Output=struct(); Output.revOnsets=[];
neuron_rise_onsets=[]; trials_rise_onsets=[]; first_onsets=[];
All_trace_rise_state=[];All_trace_onsets=[];

for i=1:length(Results)
% traces_rise_state=[];trace_onsets =[];
% 
% 
% prestimulus_period= 1:prestimulus_period*frame_rate;
% 
% Neuron = get_neuron_id('AVAL',i);
% trace = Results(i).deltaFOverF_bc(:,Neuron);  
% trace_rise_state =  Results(i).traceColoring(:,Neuron);
% 
% % trace_rise_state(trace_rise_state~=2)=0;
% % trace_rise_state(trace_rise_state==2)=1;
% trace_rise_state(trace_rise_state==1)=0;
% trace_rise_state(trace_rise_state>1)=1;
% trace_rise_state= trace_rise_state';
% tr_state_rise=trace_rise_state;
% 
% x_orig = linspace(0, 1, length(tr_state_rise));
% x_int = linspace(0, 1, Interpolation_windowsize); % BUG FIX 1: was linspace(1,1,...) — all-ones vector makes interp1 fail
% 
% traces_rise_state = round(interp1(x_orig, tr_state_rise, x_int));
% All_trace_rise_state(i,:)=traces_rise_state;

All_trace_rise_state=load('All_AVA_rise_state.csv')
traces_rise_state=All_trace_rise_state(i,:);
trace_onsets = (diff(traces_rise_state,1,2) > 0);    
trace_onsets = [0 trace_onsets];
All_trace_onsets(i,:)=trace_onsets;

 trials_rise_onsets=[];
  for t = 1:length(upshifts)
        
        window_start = upshifts(t)*frame_rate+minimum_window*frame_rate;
        window_end = upshifts(t)*frame_rate+maximum_window*frame_rate;
        trials_rise_onsets(t,:)= trace_onsets(window_start+1:window_end);
       
        % BUG FIX 2: search over the post-stimulus portion of the trial window
        % (frames prewin_sec*hz+1 to end), not an ill-defined row-count fraction
        prewin_frames = abs(minimum_window) * frame_rate;
        first_onset = find(trials_rise_onsets(t, prewin_frames+1:end), 1, 'first');

        if ~isempty(first_onset)
             first_onsets=[first_onsets;first_onset];
        else
            first_onsets=[first_onsets;NaN];
        end
  end

Output(i).revOnsets=trials_rise_onsets;
neuron_rise_onsets= [neuron_rise_onsets;trials_rise_onsets];

end
% csvwrite('All_AVA_rise_state.csv',All_trace_rise_state)
% csvwrite('All_AVA_stimtrig_trials.csv',neuron_rise_onsets);

%%
load('hit_miss_trials.mat', 'output');
response_mat = NaN(length(output), trials);

for i = 1:length(output)
    response_mat(i, output(i).ind_vec.avaLowHit)  = 1;
    response_mat(i, output(i).ind_vec.avaLowMiss) = 0;
end

figure()
pcolor([response_mat response_mat(:,end); response_mat(end,:) response_mat(end,end)])
axis ij

% %% post processing (not needed)
% hz = Interpolation_windowsize/total_time;                     % Sampling rate (Hz)
% prewin_sec = 60;             % Pre-trigger window (sec)
% postwin_sec = 30;            % Post-trigger window (sec)
% stimulus_delay_sec = 0;     % Stimulus delay (sec)
% critical_window_sec = 8.5;   % Time window for considering a hit (sec)
% trig_win_sec = 30;           % Window around reversal onset for triggered speed
% trigger_interval = 90;       % Interval between triggers (sec)
% trigger_end = 1800;          % Last trigger time (sec)
% baseline = 450;              % time to consider for baseline 
% smooth_window = 15;          % Smoothing window (frames)
% perm_parameter=1000;
% before_stimulus=2;%sec
% 
% prewin = prewin_sec * hz;
% 
% first_reversal_onsets = zeros(size(neuron_rise_onsets(:, prewin+1:end)));
% first_reversal_onsets_down = zeros(size(neuron_rise_onsets(:, 1:prewin)));
% first_rev_frame=[];
% for p = 1: size(neuron_rise_onsets ,1)
%     
%     first_rev_frame=[first_rev_frame,find(neuron_rise_onsets(p, prewin+1:end) , 1, 'first')];   
%     first_reversal_onsets(p,find(neuron_rise_onsets(p, prewin+1:end) , 1, 'first')) = 1;
% 
%     first_reversal_onsets_down(p,find(neuron_rise_onsets(p, 1:prewin) , 1, 'first')) = 1;
% 
% end
% no_rev_trials=find(sum(first_reversal_onsets,2)==0);
% rev_trials=find(sum(first_reversal_onsets,2)==1);
% 
% Quant=struct();
% response=NaN(length(Results),trials);
% pre_rev=NaN(length(Results),trials);
% for w=1:length(Results)
%     Quant(w).revOnsets_upshift = Output(w).revOnsets(:,round(prewin_sec*hz)+1:end);
%     
%     
%     is_nan_up=isnan(Quant(w).revOnsets_upshift);
%     not_nan_up=find(sum(is_nan_up,2)==0);
%     
%     Quant(w).fullTrack_rev_Onsets_upshift=Quant(w).revOnsets_upshift(not_nan_up,:);
%     
%     response(w,:)=sum(Quant(w).revOnsets_upshift(:,1:critical_window_sec*hz),2);
%     pre_rev(w,:)=sum(Output(w).revOnsets(:,prewin-(before_stimulus*hz):prewin),2);
%     post_rev(w,:)=sum(Quant(w).revOnsets_upshift(:,:),2);
%        
% end
% 
% response(response>=1)=1;
% % response(pre_rev>=1)=2;
% % response(pre_rev>=1)=NaN;
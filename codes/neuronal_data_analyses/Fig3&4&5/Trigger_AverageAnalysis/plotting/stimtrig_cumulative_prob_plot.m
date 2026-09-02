% plot the cumulative probability of rise onsets 
% Need the data_extracted.mat 'Results' struct
function[]=stimtrig_cumulative_prob_plot(neuron_name)
load('WBstruct_head_data_extracted.mat', 'Results');
minimum_window = -60 ; %in sec
maximum_window = 30; %in sec
prestimulus_period = 450; %in sec
Interpolation_windowsize = 9450;%CHANGE!!! depending on the recording frame rate/fps
permutation_parameter = 1000; % randomization factor
stimulus_period= 30; %sec
total_time=1890;
stimulus = Results(1).stimulus.switchtimes;
upshifts= stimulus(1:2:length(stimulus));
downshifts= stimulus(2:2:length(stimulus));
neuron_rise_onsets=[]; trials_rise_onsets=[]; first_onsets=[];
% first_onsets=NaN(length(upshifts),length(Results));
for i=1:length(Results)
trace_rise_state=[];

frame_rate = Interpolation_windowsize/total_time;
prestimulus_period= 1:prestimulus_period*frame_rate;

Neuron = get_neuron_id(neuron_name,i);
trace = Results(i).deltaFOverF_bc(:,Neuron);  
trace_rise_state =  Results(i).traceColoring(:,Neuron);

trace_rise_state(trace_rise_state~=2)=0;
trace_rise_state(trace_rise_state==2)=1;
% trace_rise_state(trace_rise_state==1)=0;
% trace_rise_state(trace_rise_state>1)=1;
trace_rise_state= trace_rise_state';

% interpolate traces
tr_state_rise = trace_rise_state; 

x_orig = linspace(0, 1, length(tr_state_rise));
x_int = linspace(0,1, Interpolation_windowsize);

%interpolated traces and round AVA and RIS state traces to get rid of
%anything that is not 1 or 0

trace_rise_state = round (interp1(x_orig,tr_state_rise, x_int));
All_trace_rise_state(i,:)=trace_rise_state;
trace_onsets = (diff(trace_rise_state,1,2) > 0);    
trace_onsets = [0 trace_onsets];
 
% use this block in case we go from 0 to +90 sec  
 exclude_window=[]; trials_rise_onsets=[];
  for t = 1:length(upshifts);
        
        window_start = upshifts(t)*frame_rate+minimum_window*frame_rate;
        window_end = upshifts(t)*frame_rate+maximum_window*frame_rate;
        trials_rise_onsets(t,:)= trace_onsets(window_start+1:window_end);
       
        %finding the first onset
        first_onset=find(trials_rise_onsets(t,(length(trials_rise_onsets)*2/3)+1:end) , 1, 'first');
if ~isempty(first_onset)
     first_onsets=[first_onsets;first_onset];
else
    first_onsets=[first_onsets;NaN];
end
% for randomisation exclude the window -30 to +30 (stimulus period) around the stimulus 
 exclude_window =[exclude_window, (window_start-stimulus_period*frame_rate):(window_start+stimulus_period*frame_rate)];
  end
neuron_rise_onsets= [neuron_rise_onsets;trials_rise_onsets];

first_reversal_onsets = zeros(size(neuron_rise_onsets(:, 301:end)));
first_reversal_onsets_down = zeros(size(neuron_rise_onsets(:, 1:300)));
for p = 1: size(neuron_rise_onsets ,1)
    
    first_reversal_onsets(p,find(neuron_rise_onsets(p, 301:end) , 1, 'first')) = 1;

    first_reversal_onsets_down(p,find(neuron_rise_onsets(p, 1:300) , 1, 'first')) = 1;

end


 % randomised trial control   
 total_length=Interpolation_windowsize;
%  permutation_window= ~ismember([1:total_length-round(stimulus_period*frame_rate)],exclude_window); %exclude 30s around stim and also at the end 30 sec for the random triger point
 permutation_window= [1:total_length-round(stimulus_period*frame_rate)-1]; %exclude 30s around stim and also at the end 30 sec for the random triger point
%  permutation_window_indices = find(permutation_window==1);
permutation_window_indices = permutation_window;
 random_trials_rise_onsets=[];
 All_random_trial_rise_onsets=[];
 Avg_rand_trial_riseOnset=[];
 random_trials_rise_onset_prob=[];
for j=1:permutation_parameter
      random_trials_trigger_indices = randperm(size(permutation_window_indices,2) , length(upshifts));
      random_trials_trigger_points=permutation_window_indices(random_trials_trigger_indices);
      for y=1:length(random_trials_trigger_points)
          %take the rise onsets vector around the random trigger point as
          %big as the stimulus period
      random_trials_rise_onsets(y,:)= trace_onsets(random_trials_trigger_points(y):(random_trials_trigger_points(y)+round(stimulus_period*frame_rate)));
      end
     All_random_trial_rise_onsets= [All_random_trial_rise_onsets;random_trials_rise_onsets];
end 
%Average after all permutations
Average_random_trials_rise_onset_vector = mean(All_random_trial_rise_onsets);

end

%calculating cumulative probability
upshift_cumulative_prob=cumsum(first_reversal_onsets,2); 
  
downshift_cumulative_prob=cumsum(first_reversal_onsets_down,2);

Average_rise_onset = mean(upshift_cumulative_prob); 
Average_rise_onset_down = mean(downshift_cumulative_prob); 
%save ramdom trial 
random_trials_cumulative_prob = cumsum(Average_random_trials_rise_onset_vector,2);

% up_down_diff= upshift_cumulative_prob-random_trials_cumulative_prob(1:length(upshift_cumulative_prob));
% diff_up=[0 diff(upshift_cumulative_prob)];
% diff_down=[0 diff(downshift_cumulative_prob)];


% plot the average of all datasets

figure()

timeline_1 = linspace( 0, 30, size(upshift_cumulative_prob,2));
timeline_2 = linspace( 0, 60, size(downshift_cumulative_prob,2));
timeline_3 = linspace( 0, 30, size(random_trials_cumulative_prob,2));
StDev_up = std(upshift_cumulative_prob);
SEM_up = StDev_up/size(upshift_cumulative_prob,2);
StDev_down = std(downshift_cumulative_prob);
SEM_down = StDev_down/size(downshift_cumulative_prob,2);




jbfill(timeline_2,Average_rise_onset_down+SEM_down,Average_rise_onset_down -SEM_down,[0.6602    0.8164    0.5547],[0.6602    0.8164    0.5547],0.1);
hold on
p1=plot(timeline_2,Average_rise_onset_down,'LineWidth', 1.5, 'Color', [0.6602    0.8164    0.5547],'DisplayName', '11%O2');
hold on
jbfill(timeline_1,Average_rise_onset+SEM_up,Average_rise_onset -SEM_up,[0.1328    0.3438    0.1562],[0.1328    0.3438    0.1562],0.1);
hold on
p2=plot(timeline_1,Average_rise_onset,'LineWidth', 1.5, 'Color', [0.1328    0.3438    0.1562],'DisplayName', '21%O2');
hold on
% jbfill(timeline_1,random_trials_cumulative_prob+SEM_rand,random_trials_cumulative_prob -SEM_rand,[0.9290 0.6940 0.1250],[0.9290 0.6940 0.1250],0.1);
hold on
p3=plot(timeline_3,random_trials_cumulative_prob,'LineWidth', 1.5, 'Color',[0.9290 0.6940 0.1250],'DisplayName', '11%O2');
xline(8.5,'Color','k','LineStyle','-')
legend([p1,p2,p3],'11%O2','21%O2','random trials');
ylabel('cumulative probability');
xlabel('Time (s)');

[h1,p1,ks2stat1] = kstest2(Average_rise_onset,random_trials_cumulative_prob)
[h2,p2,ks2stat2] = kstest2(Average_rise_onset_down(1:size(random_trials_cumulative_prob,2)),random_trials_cumulative_prob)
% savestr= strcat(neuron_name, ' Rise Onset Cumulative Probability');
% title(savestr);
% saveas(gcf, savestr);
% saveas(gcf, savestr, 'png');

end

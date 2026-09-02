
%% Plot speed with stim-trig average and shaded error for hits and misses
figure();
yl = [0, 0.25];
patch([-5 0 0 -5], [yl(1) yl(1) yl(2) yl(2)], [0.9, 0.9, 0.9], 'EdgeColor', 'none'); 
hold on

% Smoothed speed
smooth_hit_speed = smoothdata(hit_speed, 2, 'movmean', 30, 'omitnan');
smooth_miss_speed = smoothdata(miss_speed, 2, 'movmean', 30, 'omitnan');

shadedErrorBar2(timevec, mean(smooth_hit_speed, 'omitnan'), std(smooth_hit_speed, 'omitnan'), [0.9375, 0.4570, 0.0625], 0.5);
shadedErrorBar2(timevec, mean(smooth_miss_speed, 'omitnan'), std(smooth_miss_speed, 'omitnan'), [0, 0.6875, 0.9375], 0.5);

xline(0, '--k', 'LineWidth', 1.5);
xlabel('Time (s)');
ylabel('Speed (mm/s)');
ylim(yl);
title('Speed traces: Hit vs Miss');

 
%% plotting confusion matrix of 5 sec average

hit_values=mean(hit_speed(:,551:600),2,'omitnan');
miss_values=mean(miss_speed(:,551:600),2,'omitnan');

mean_hit=nanmean(hit_values);mean_miss=nanmean(miss_values);
n_hit=length(hit_values);
n_miss=length(miss_values);
mean_of_mean=(n_hit*mean_hit+n_miss*mean_miss)/(n_hit+n_miss);
hit_high=find(hit_values>mean_of_mean);
hit_low=find(hit_values<mean_of_mean);
miss_low=find(miss_values<mean_of_mean);
miss_high=find(miss_values>mean_of_mean);
% 
 confusion_matrix=[];
if mean_hit > mean_of_mean
   confusion_matrix.true_hits=hit_high;
   confusion_matrix.true_miss=miss_low;
   confusion_matrix.false_hits=hit_low;
   confusion_matrix.false_miss=miss_high;
   
 
else
   confusion_matrix.true_hits=hit_low;
   confusion_matrix.true_miss=miss_high;
   confusion_matrix.false_hits=hit_high;
   confusion_matrix.false_miss=miss_low;
end 
test_hit={};test_miss={};
test_hit(1:n_hit,1)=cellstr('reversal');test_miss(1:n_miss,1)=cellstr('No reversal');
predict_hit=test_hit;predict_miss=test_miss;
predict_hit(confusion_matrix.false_hits,1)= cellstr('No reversal');
predict_miss(confusion_matrix.false_miss,1)= cellstr('reversal');
test_hit=categorical(test_hit);test_miss=categorical(test_miss);
predict_hit=categorical(predict_hit);predict_miss=categorical(predict_miss);

test_data=[test_hit;test_miss];
predicted_data=[predict_hit;predict_miss];
Accuracy=(sum(test_data==predicted_data)/(n_hit+n_miss))*100;
figure()
plotconfusion(test_data,predicted_data) 
title(Accuracy);


%% from chatgpt actual way of using LDA equation to calculate the decision boundary (not very different from the one above)
mu1 = nanmean(hit_values);    % mean of hits
mu0 = nanmean(miss_values);   % mean of misses

var1 = var(hit_values);    
var0 = var(miss_values);

% LDA assumes equal variance → pooled variance
n1 = length(hit_values);
n0 = length(miss_values);

sigma2 = ((n1-1)*var1 + (n0-1)*var0) / (n1 + n0 - 2);

w = (mu1 - mu0) / sigma2;
b = -0.5 * (mu1^2 - mu0^2) / sigma2;
g = @(x) w*x + b;
X = [miss_values; hit_values];
y_true = [zeros(length(miss_values),1); ones(length(hit_values),1)];

y_pred = zeros(size(X));

for i = 1:length(X)
    if g(X(i)) > 0
        y_pred(i) = 1; % hit
    else
        y_pred(i) = 0; % miss
    end
end

TP = sum((y_pred == 1) & (y_true == 1));
TN = sum((y_pred == 0) & (y_true == 0));
FP = sum((y_pred == 1) & (y_true == 0));
FN = sum((y_pred == 0) & (y_true == 1));

total = TP + TN + FP + FN;

TP_p = 100 * TP / total;
TN_p = 100 * TN / total;
FP_p = 100 * FP / total;
FN_p = 100 * FN / total;

conf_mat_percent = [TP_p FN_p; FP_p TN_p];

disp('Confusion Matrix:');
disp('        Pred Hit   Pred Miss');
fprintf('True Hit    %6.2f%%     %6.2f%%\n', TP_p, FN_p);
fprintf('True Miss   %6.2f%%     %6.2f%%\n', FP_p, TN_p);

figure; hold on;

% histograms
histogram(miss_values, 'Normalization','pdf');
histogram(hit_values,  'Normalization','pdf');
x_boundary = -b / w;
% decision boundary
xline(x_boundary, 'k--', 'LineWidth',2);

legend('Miss','Hit','Decision boundary');
title('1D LDA classification');
%   end
%% histogram of the 5 sec average data
figure()
histogram(hit_values,'NumBins',10,'BinWidth',0.02,'FaceColor',[0.9375    0.4570    0.0625],'Normalization','probability')
hold on
histogram(miss_values,'NumBins',10,'BinWidth',0.02,'FaceColor',[0    0.6875    0.9375],'Normalization','probability')
hold on
xline(mean_hit,'LineStyle','--','LineWidth',1.5,'Color',[0.9375    0.4570    0.0625])
hold on
xline(mean_miss,'LineStyle','--','LineWidth',1.5,'Color',[0    0.6875    0.9375])
hold on
xline(mean_of_mean,'LineStyle','-','LineWidth',1.5,'Color','k')
xlabel('Speed (mm/s)')
ylabel('Probability')

 %% 
% Turn onset probability with background and stimulus shading
figure();
bin_size = 5;
shifts =[baseline*hz+stimulus_delay:winsize:total_time*hz];
time = 1:total_time/bin_size;
avg = nanmean(binned_turnonsets);
sem = std(binned_turnonsets, 'omitnan') / sqrt(num_files);
ymax = max(avg + sem);

fill([0, 0, max(time), max(time)], [0, ymax, ymax, 0], [0.55, 0.82, 0.78], 'FaceAlpha', 1, 'EdgeColor', 'none');
hold on;
for i = 1:trials
    rectangle('Position', [shifts(i)/(bin_size*hz), 0, postwin_sec/bin_size, ymax], ...
              'FaceColor', '#ffffb3', 'EdgeColor', 'none');
end
shadedErrorBar2(time, movmean(avg, 2), movmean(sem, 2), 'k', 1);

set(gca, 'FontSize', 16, 'FontWeight', 'bold', 'FontName', 'Helvetica');
xlabel('Time [s]');
ylabel('Turn probability');
xticks = linspace(0, max(time), 7);
xticklabels = linspace(0, total_time, 7);
set(gca, 'XTick', xticks, 'XTickLabel', xticklabels);
title('Turn Probability Over Time');

%%
% Rev onset probability with background and stimulus shading
figure();
bin_size = 5;
shifts =[baseline*hz+stimulus_delay:winsize:total_time*hz];
time = 1:total_time/bin_size;
avg = nanmean(binned_revonsets);
sem = std(binned_revonsets, 'omitnan') / sqrt(num_files);
ymax = max(avg + sem);

fill([0, 0, max(time), max(time)], [0, ymax, ymax, 0], [0.55, 0.82, 0.78], 'FaceAlpha', 1, 'EdgeColor', 'none');
hold on;
for i = 1:trials
    rectangle('Position', [shifts(i)/(bin_size*hz), 0, postwin_sec/bin_size, ymax], ...
              'FaceColor', '#ffffb3', 'EdgeColor', 'none');
end
shadedErrorBar2(time, movmean(avg, 2), movmean(sem, 2), 'k', 1);

set(gca, 'FontSize', 16, 'FontWeight', 'bold', 'FontName', 'Helvetica');
xlabel('Time [s]');
ylabel('Rev probability');
xticks = linspace(0, max(time), 7);
xticklabels = linspace(0, total_time, 7);
set(gca, 'XTick', xticks, 'XTickLabel', xticklabels);
title('Reversal Probability Over Time');

%%
% Downsampled average speed overtime
bin_size = 5;
avg_downsampled = Avg_speed(1:bin_size:end);
sem_downsampled = std_speed(1:bin_size:end) / sqrt(num_files);
hzames_downsampled = linspace(1, 1890, length(avg_downsampled));
ymax = max(avg_downsampled + sem_downsampled);

figure();
for i = 1:trials
    rectangle('Position', [shifts(i)/10, 0, 30, ymax], ...
              'FaceColor', '#ffffb3', 'LineWidth', 0.5);
end
hold on;
shadedErrorBar2(hzames_downsampled, movmean(avg_downsampled, 2), movmean(sem_downsampled, 2), 'k', 1);
xlim([0, total_time]);
ylim([0, ymax]);

set(gca, 'FontName', 'Helvetica', 'FontSize', 16, 'FontWeight', 'bold');
xlabel('Time [s]', 'FontSize', 22, 'FontWeight', 'bold');
ylabel('Speed (mm/s)', 'FontSize', 22, 'FontWeight', 'bold');
title('Average Speed Over Trials');

%% plot the stim-trigger average combining speed, revonset and turnonset

post_stimulus=linspace(0,postwin_sec,postwin_sec*hz);
time=linspace(-5,postwin_sec,(5+postwin_sec)*hz);

% smoothed_speed = smoothdata(all_stimtrig_speed, 2, 'gaussian', 50, 'omitnan');
% 
% [avg_stimtrig_speed, low_speed, high_speed] = bootstrap_mean(smoothed_speed, 2000);
% 
% smoothed_revonset = smoothdata(all_stimtrig_revonset, 2, 'gaussian', 50, 'omitnan');
% 
% [avg_stimtrig_revonset, low_revonset, high_revonset] = bootstrap_mean(smoothed_revonset, 2000);
% 
% smoothed_turnonset = smoothdata(all_stimtrig_turnonset, 2, 'gaussian', 50, 'omitnan');
% 
% [avg_stimtrig_turnonset, low_turnonset, high_turnonset] = bootstrap_mean(smoothed_turnonset, 2000);

avg_stimtrig_speed=nanmean(smoothdata(all_stimtrig_speed,2,'gaussian',50,'omitnan'));
sem_stimtrig_speed=nansem(smoothdata(all_stimtrig_speed,2,'gaussian',50,'omitnan'));
Avg_hit_speed=nanmean(smoothdata(hit_speed,2,'movmean',10,'omitnan'));
std_hit_speed=nansem(smoothdata(hit_speed,2,'movmean',10,'omitnan'));
Avg_miss_speed=nanmean(smoothdata(miss_speed,2,'movmean',10,'omitnan'));
std_miss_speed=nansem(smoothdata(miss_speed,2,'movmean',10,'omitnan'));

% avg_stimtrig_revonset=nanmean(all_stimtrig_revonset);
% sem_stimtrig_revonset=nansem(all_stimtrig_revonset);
% Avg_hit_revonset=nanmean(smoothdata(hit_rev_onset,2,'movmean',10,'omitnan'));
% std_hit_revonset=nansem(smoothdata(hit_rev_onset,2,'movmean',10,'omitnan'));
% Avg_miss_revonset=nanmean(smoothdata(miss_rev_onset,2,'movmean',10,'omitnan'));
% std_miss_revonset=nansem(smoothdata(miss_rev_onset,2,'movmean',10,'omitnan'));
% 
% avg_stimtrig_turnonset=nanmean(all_stimtrig_turnonset);
% sem_stimtrig_turnonset=nansem(all_stimtrig_turnonset);
% Avg_hit_turnonset=nanmean(smoothdata(hit_turn_onset,2,'movmean',10,'omitnan'));
% std_hit_turnonset=nansem(smoothdata(hit_turn_onset,2,'movmean',10,'omitnan'));
% Avg_miss_turnonset=nanmean(smoothdata(miss_turn_onset,2,'movmean',10,'omitnan'));
% std_miss_turnonset=nansem(smoothdata(miss_turn_onset,2,'movmean',10,'omitnan'));

% figure()
% yyaxis left
% shadedErrorBar2(time,movmean(avg_stimtrig_speed(((prewin_sec-5)*hz)+1:(prewin_sec+postwin_sec)*hz),50),[movmean(high_speed(((prewin_sec-5)*hz)+1:(prewin_sec+postwin_sec)*hz),50);movmean(low_speed(((prewin_sec-5)*hz)+1:(prewin_sec+postwin_sec)*hz),50)], 'r', 1);
% ylabel('Speed (mm/s)', 'FontName', 'Helvetica', 'FontSize', 22, 'FontWeight', 'bold');
% yyaxis right
% shadedErrorBar2(time,movsum(avg_stimtrig_revonset(((prewin_sec-5)*hz)+1:(prewin_sec+postwin_sec)*hz),30),[movsum(high_revonset(((prewin_sec-5)*hz)+1:(prewin_sec+postwin_sec)*hz),30);movsum(low_revonset(((prewin_sec-5)*hz)+1:(prewin_sec+postwin_sec)*hz),30)], 'g', 1);
% hold on
% shadedErrorBar2(time,movsum(avg_stimtrig_turnonset(((prewin_sec-5)*hz)+1:(prewin_sec+postwin_sec)*hz),30),[movsum(high_turnonset(((prewin_sec-5)*hz)+1:(prewin_sec+postwin_sec)*hz),30);movsum(low_turnonset(((prewin_sec-5)*hz)+1:(prewin_sec+postwin_sec)*hz),30)], 'b', 1);
% xlabel('Time (s)', 'FontName', 'Helvetica', 'FontSize', 16, 'FontWeight', 'bold');
% ylabel('probability', 'FontName', 'Helvetica', 'FontSize', 16, 'FontWeight', 'bold');

bin_size = 3; % seconds
edges = -4:bin_size:postwin_sec;
% Define peri-stimulus index window (same as your original logic)
idx = ((prewin_sec-5)*hz)+1 : (prewin_sec+postwin_sec)*hz;
% Time axis (robust, no mismatch)
time_plot = (-5*hz : (postwin_sec*hz - 1)) / hz;
n_trials = size(all_stimtrig_speed, 1);

rev_mat  = all_stimtrig_revonset(:, idx);
turn_mat = all_stimtrig_turnonset(:, idx);

[~, rev_time_idx]  = find(rev_mat == 1);
[~, turn_time_idx] = find(turn_mat == 1);

rev_times  = time_plot(rev_time_idx);
turn_times = time_plot(turn_time_idx);

rev_counts  = histcounts(rev_times, edges);
turn_counts = histcounts(turn_times, edges);

rev_freq  = rev_counts  / n_trials;
turn_freq = turn_counts / n_trials;

centers = edges(1:end-1) + bin_size/2;


figure()
% LEFT AXIS → SPEED
yyaxis left
shadedErrorBar2(time,movmean(avg_stimtrig_speed(((prewin_sec-5)*hz)+1:(prewin_sec+postwin_sec)*hz),50),movmean(sem_stimtrig_speed(((prewin_sec-5)*hz)+1:(prewin_sec+postwin_sec)*hz),50), 'r', 1);
ylabel('Speed (mm/s)', 'FontName', 'Helvetica', 'FontSize', 22, 'FontWeight', 'bold');
yyaxis right
% RIGHT AXIS → EVENTS
yyaxis right

bar(centers, rev_freq, 1, ...
    'FaceColor', [0 0.6 0], ...
    'FaceAlpha', 0.5, ...
    'EdgeColor', 'none');
hold on

bar(centers, turn_freq, 1, ...
    'FaceColor', [0 0 1], ...
    'FaceAlpha', 0.5, ...
    'EdgeColor', 'none');


ylabel('Events / 3 s / trial', 'FontName', 'Helvetica', 'FontSize', 18, 'FontWeight', 'bold');
xline(0, '--k', 'LineWidth', 2);
% LABELS
xlabel('Time (s)', 'FontName', 'Helvetica', 'FontSize', 18, 'FontWeight', 'bold');

legend({'Speed', 'Reversal onset', 'Turn onset'}, 'Location', 'best');
set(gca, 'FontSize', 14, 'LineWidth', 1.5);

%% Reversal onset plots and probability plot

imagesc(reversals)
hold on
for j=1:trials
    xline(shifts(j)+stimulus_delay_sec*hz,'Color','k','LineStyle','--')
    xline(shifts(j)+(postwin_sec+stimulus_delay_sec)*hz,'Color','k','LineStyle','--')
end

%% plotting reversal onsets, stimulus delay of 5 sec is taken into account

%optional plotting

figure()
imagesc(Full_track_stimtrig_trials);
hold on
xline(prewin,'Color','k','LineStyle','--')


mean_rev_onset_prob=mean(Full_track_stimtrig_trials);
sem_rev_onset_prob=std(Full_track_stimtrig_trials)/sqrt(size(Full_track_stimtrig_trials,1));
binned_rev_onset_prob=[];binned_sem_rev_onset_prob=[];
bin_size=3*hz;
for w=1:length(mean_rev_onset_prob)/bin_size
    binned_rev_onset_prob(1,w)=sum(mean_rev_onset_prob((w-1)*bin_size+1:w*bin_size),2);
    binned_sem_rev_onset_prob(1,w)=sum(sem_rev_onset_prob((w-1)*bin_size+1:w*bin_size),2);
end
time=linspace(-60,30,w);
figure()
plot(time,binned_rev_onset_prob,'LineWidth',2,'Color','k')
hold on
jbfill(time,binned_rev_onset_prob+binned_sem_rev_onset_prob,binned_rev_onset_prob-binned_sem_rev_onset_prob,[0,0,0])
xline(critical_window_sec,'Color','k','LineStyle','--')



% histogram of response duration
figure()
histogram(first_rev_frame/hz,'NumBins',10,'FaceColor','k')
hold on
xline(critical_window_sec,'Color','k','LineStyle','--','LineWidth',2)


%% Reversal onset cumulative probability plot

Avg_cumulative_prob_upshift=cumsum(first_reversal_onsets,2)
Avg_cumulative_prob_downshift=cumsum(first_reversal_onsets_down,2)
%plotting
Avg_cum_prob_revOnsets_upshifts= nanmean(Avg_cumulative_prob_upshift);
Avg_cum_prob_revOnsets_downshifts= nanmean(Avg_cumulative_prob_downshift);
StDev_up = std(Avg_cumulative_prob_upshift);
SEM_up = StDev_up/size(Avg_cumulative_prob_upshift,2);
StDev_down = std(Avg_cumulative_prob_downshift);
SEM_down = StDev_down/size(Avg_cumulative_prob_downshift,2);
Avg_rand_cntrl= mean(rand_trial_cntrl);
StDev_rand = std(rand_trial_cntrl);
SEM_rand = StDev_rand/length(Output);
timeline_1 = linspace( 0, 30, size(Avg_cum_prob_revOnsets_upshifts,2));
timeline_2 = linspace( 0, 60, size(Avg_cum_prob_revOnsets_downshifts,2));

figure()
jbfill(timeline_2,Avg_cum_prob_revOnsets_downshifts+SEM_down,Avg_cum_prob_revOnsets_downshifts -SEM_down,[0.6602    0.8164    0.5547],[0.6602    0.8164    0.5547],0.1);
hold on
p1=plot(timeline_2,Avg_cum_prob_revOnsets_downshifts,'LineWidth', 1.5, 'Color', [0.6602    0.8164    0.5547],'DisplayName', '11%O2');
hold on
jbfill(timeline_1,Avg_cum_prob_revOnsets_upshifts+SEM_up,Avg_cum_prob_revOnsets_upshifts -SEM_up,[0.1328    0.3438    0.1562],[0.1328    0.3438    0.1562],0.1);
hold on
p2=plot(timeline_1,Avg_cum_prob_revOnsets_upshifts,'LineWidth', 1.5, 'Color', [0.1328    0.3438    0.1562],'DisplayName', '21%O2');
hold on
jbfill(timeline_1,Avg_rand_cntrl+SEM_rand,Avg_rand_cntrl -SEM_rand,[0.9290 0.6940 0.1250],[0.9290 0.6940 0.1250],0.1);
hold on
p3=plot(timeline_1,Avg_rand_cntrl,'LineWidth', 1.5, 'Color',[0.9290 0.6940 0.1250],'DisplayName', '11%O2');
xline(critical_window_sec,'Color','k','LineStyle','-')
legend([p1,p2,p3],'11%O2','21%O2','random trials');
ylabel('cumulative probability');
xlabel('time (sec)');
savestr= ('Reversal Onset Cumulative Probability');
title(savestr);
saveas(gcf, savestr);
saveas(gcf, savestr, 'png');
%% response classes
figure()
pcolor(response) % change the caxis [cmin, cmax] to change color Turbo [-0.5,1.5]
axis ij


function [mean_est, ci_lower, ci_upper] = bootstrap_mean(data, B)
    % data: trials x time
    % B: number of bootstrap samples
    
    [n_trials, n_time] = size(data);
    boot_means = nan(B, n_time);
    
    for b = 1:B
        idx = randi(n_trials, [n_trials, 1]); % resample trials
        sample = data(idx, :);
        boot_means(b, :) = nanmean(sample, 1);
    end
    
    mean_est = nanmean(data, 1);
    ci_lower = prctile(boot_means, 2.5);
    ci_upper = prctile(boot_means, 97.5);
end

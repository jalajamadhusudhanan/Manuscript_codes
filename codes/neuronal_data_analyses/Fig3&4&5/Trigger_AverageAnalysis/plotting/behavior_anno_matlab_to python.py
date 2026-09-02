import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Qt5Agg")
import matplotlib.pyplot as plt
import seaborn as sns
import helper_function as hf

#Reading Data and Preprocessing
# Read the CSV file
# beh_anno = pd.read_csv(r"Z:\jalaja\behaviour\Autoscope\autoscope_stage position\manual_annotation.csv")
beh_anno = pd.read_csv(r"C:\Users\Jalaja Madhusudhanan\Desktop\server data\ZIM2343&ZIM2344\data\All_AVA_rise_state.csv")
beh_anno=beh_anno.T
# Add this line to ensure text remains text in the SVG
plt.rcParams['svg.fonttype'] = 'none'  # Ensures text is saved as editable text, not paths
# Constants and parameters
upshift_period_length = 30  # length of each of the shift periods; in SECONDS
downshift_period_length = 60
fr = 5
trials = 16
lnbase = 450 * fr
total_time = 450 + (upshift_period_length + downshift_period_length) * trials
frames = total_time * fr
trial_length = (upshift_period_length + downshift_period_length) * fr
shifts = np.arange(lnbase, frames + 1, trial_length)
stimulus_delay = 0
critical_end_point = 8.5
before_stimulus = 2
bin_size = 3 * fr # 3 seconds


# Initialize lists
reversals = []
rev_onsets = []
rev_onset_frames = []
turn_onsets = []

for i in range(beh_anno.shape[1]):
    anno_perworm = beh_anno.iloc[:, i]
    rev = anno_perworm.copy()
    turn = anno_perworm.copy()
    rev[anno_perworm > 1] = 0
    turn[(anno_perworm == 2) | (anno_perworm == 3)] = 1
    turn[anno_perworm < 2] = 0

    rev_onset = hf.detect_onset(rev)
    turn_onset = hf.detect_onset(turn)

    reversals.append(rev)
    rev_onsets.append(rev_onset)
    rev_onset_frames=np.where(rev_onset)[0]
    turn_onsets.append(turn_onset)

# Convert lists to arrays
reversals = np.array(reversals)
rev_onsets = np.array(rev_onsets)
turn_onsets = np.array(turn_onsets)


# Bin the reversal onset and turn onset data
binned_revOnsets = hf.bin_data(rev_onsets, bin_size)
binned_turnOnsets = hf.bin_data(turn_onsets, bin_size)

# Calculate the mean and SEM for each bin
mean_revOnsets, sem_revOnsets = hf.calculate_mean_sem(binned_revOnsets)
mean_turnOnsets, sem_turnOnsets = hf.calculate_mean_sem(binned_turnOnsets)

smooth_window=3
# Smooth the data using moving average
rev_onset_mean_smooth = hf.rolling_mean(mean_revOnsets, smooth_window)
rev_onset_sem_smooth = hf.rolling_mean(sem_revOnsets, smooth_window)
turn_onset_mean_smooth = hf.rolling_mean(mean_turnOnsets, smooth_window)
turn_onset_sem_smooth = hf.rolling_mean(sem_turnOnsets, smooth_window)

# Generate time vector for plotting (based on the number of bins)
time_bins = np.arange(0, mean_revOnsets.shape[0]) * 3  # 3-second bins

# Plotting
plt.figure(figsize=(10, 6))
    # Plot shaded error bars for reversal onsets
plt.fill_between(time_bins,  rev_onset_mean_smooth-rev_onset_sem_smooth,rev_onset_mean_smooth + rev_onset_sem_smooth, color='black', alpha=0.3)
plt.plot(time_bins, rev_onset_mean_smooth, 'k', label='Reversal Onsets')
plt.xlabel('Time (seconds)', fontsize=14)
plt.ylabel('Onsets per Bin (3 sec)', fontsize=14)
plt.title('Binned Reversal and Onsets (3 sec bins)', fontsize=16)
plt.legend(loc='upper right')
plt.tight_layout()
plt.show()

# plt.figure(figsize=(10, 6))
# # Plot shaded error bars for reversal onsets
# plt.fill_between(time_bins,  turn_onset_mean_smooth-turn_onset_sem_smooth,turn_onset_mean_smooth + turn_onset_sem_smooth, color='black', alpha=0.3)
# plt.plot(time_bins, turn_onset_mean_smooth, 'k', label='Turn Onsets')
# plt.xlabel('Time (seconds)', fontsize=14)
# plt.ylabel('Onsets per Bin (3 sec)', fontsize=14)
# plt.title('Binned Turn and Onsets (3 sec bins)', fontsize=16)
# plt.legend(loc='upper right')
# plt.tight_layout()
# plt.show()

# Visualization fig 1B

# fig, ax = plt.subplots(figsize=(10,10))
# df1=pd.DataFrame(np.ones((1,18900))*11)
# for k in range(16):
#     plt.axvline(x=4500 + stimulus_delay + (k * 900), color='r', linestyle='--', linewidth=1.5)
#     df1.iloc[0, 4500 + stimulus_delay + (k * 900) + 1:4500 + stimulus_delay + (k * 900) + 300] = 21
# # Sample figsize in inches
# sns.heatmap(reversals, cmap='gray_r',cbar=False,ax=ax)
# ax.tick_params(axis='both', which='major', labelsize=12)
# ax.set_xticks([2000,4000,6000,8000,10000,12000,14000,16000,18000])
# ax.set_xticklabels(['200','400','600','800','1000','1200','1400','1600','1800'], rotation=0)
# ax.set_yticklabels([1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25], rotation=0)
# ax.set_xlabel('Time (s)',fontsize=15)
# ax.set_ylabel('worms',fontsize=15)
# for _, spine in ax.spines.items():
#     spine.set_visible(True)
#     spine.set_edgecolor('black')
#
# plt.show()

All_stimtrig_trials = np.empty((0, trial_length))
All_stimtrig_trials_turns = np.empty((0, trial_length))
All_randomtrig_trials = np.empty((0, trial_length))
for w in range(rev_onsets.shape[0]):
    stimtrig_revonsets = np.empty((trials, trial_length))
    beh_perworm = np.empty((trials, trial_length))
    stimtrig_turnonsets = np.empty((trials, trial_length))
    random_trigger = np.empty((trials, trial_length))
    random_trigger_point = np.random.randint(low=downshift_period_length * fr + 1,
                                             high=frames - upshift_period_length * fr, size=trials)

    for t in range(trials):
        start_frame = shifts[t] - downshift_period_length * fr + stimulus_delay * fr
        end_frame = shifts[t + 1] - downshift_period_length * fr + stimulus_delay * fr

        stimtrig_revonsets[t] = rev_onsets[w, start_frame:end_frame]
        beh_perworm[t] = beh_anno.iloc[start_frame:end_frame, w].to_numpy()
        stimtrig_turnonsets[t] = turn_onsets[w, start_frame:end_frame]
        random_trigger[t]=rev_onsets[w, random_trigger_point[t] - downshift_period_length * fr: random_trigger_point[t] + upshift_period_length * fr]

    All_stimtrig_trials = np.vstack((All_stimtrig_trials, stimtrig_revonsets))
    All_stimtrig_trials_turns = np.vstack((All_stimtrig_trials_turns, stimtrig_turnonsets))
    All_randomtrig_trials= np.vstack((All_randomtrig_trials, random_trigger))
# Find rows with NaN values
where_nan = np.isnan(All_stimtrig_trials)

# Find rows without any NaN values
where_no_nan = np.where(np.sum(where_nan, axis=1) == 0)[0]

# Filter out rows without NaN values
Full_track_stimtrig_trials = All_stimtrig_trials[where_no_nan]
Full_track_stimtrig_trials_turns = All_stimtrig_trials_turns[where_no_nan]

#figure 1C stimtrig plot

# Find the indices of the first occurrence of 1 in columns 600 to 900
first_1_indices = np.argmax(Full_track_stimtrig_trials[:, downshift_period_length*fr:] == 1, axis=1)

# Find the indices of rows where there are no 1s in the range 600 to 900
no_1_indices = np.where(np.all(Full_track_stimtrig_trials[:, downshift_period_length*fr:] == 0, axis=1))[0]

# Find the indices of rows with 1s in the range 600 to 900
with_1_indices = np.where(first_1_indices != 0)[0]

# Sort rows with 1s based on the first_1_indices
sorted_indices_with_1 = with_1_indices[np.argsort(first_1_indices[with_1_indices])]

# Concatenate sorted rows with 1s and rows without 1s
Full_track_stimtrig_trials_sorted = np.concatenate((Full_track_stimtrig_trials[sorted_indices_with_1], Full_track_stimtrig_trials[no_1_indices]), axis=0)

fig, ax = plt.subplots(figsize=(20,20))
plt.imshow(Full_track_stimtrig_trials_sorted, cmap='gray_r')
plt.scatter(*zip(*[(j, i) for i, row in enumerate(Full_track_stimtrig_trials_sorted) for j, val in enumerate(row) if val == 1]), color='black', marker='|',s=7)
plt.axvline(x=60*fr, color='r', linestyle='--', linewidth=1.5)
# plt.axvline(x=600+8.5*10, color='k', linestyle='--', linewidth=1.5)
# Set the axis ticks and labels
# ax.set_xticks(np.arange(0,901, step=100))
ax.set_xticklabels(np.arange(-60, 31, step=10),fontsize=10,rotation=0)
# ax.set_yticks(np.arange(1,349,step=50))
# ax.set_yticklabels(np.arange(1,349,step=50),fontsize=10)
ax.set_xlabel('Time (s)',fontsize=10)
ax.set_ylabel('Trials',fontsize=10)
plt.show()

# Apply similar sorting logic to random-triggered trials
first_1_indices_random = np.argmax(All_randomtrig_trials[:, downshift_period_length*fr:] == 1, axis=1)
no_1_indices_random = np.where(np.all(All_randomtrig_trials[:, downshift_period_length*fr:] == 0, axis=1))[0]
with_1_indices_random = np.where(first_1_indices_random != 0)[0]
sorted_indices_random_with_1 = with_1_indices_random[np.argsort(first_1_indices_random[with_1_indices_random])]

sorted_random_trials = np.vstack([All_randomtrig_trials[sorted_indices_random_with_1], All_randomtrig_trials[no_1_indices_random]])

fig, ax = plt.subplots(figsize=(20,20))
plt.imshow(sorted_random_trials, cmap='gray_r')
plt.scatter(*zip(*[(j, i) for i, row in enumerate(sorted_random_trials) for j, val in enumerate(row) if val == 1]), color='black', marker='|',s=7)

plt.axvline(x=60*fr, color='r', linestyle='--', linewidth=1.5)
#plt.axvline(x=(60+8.5)*fps, color='k', linestyle='--', linewidth=1.5)
# Set the axis ticks and labels
ax.set_xticks(np.arange(1,sorted_random_trials.shape[1], step=fr*10))
ax.set_xticklabels(np.arange(-60, 30, step=10),fontsize=10,rotation=0)
ax.set_yticks(np.arange(1,sorted_random_trials.shape[0],step=10))
ax.set_yticklabels(np.arange(1,sorted_random_trials.shape[0],step=10),fontsize=10)
ax.set_xlabel('Time (s)',fontsize=10)
ax.set_ylabel('trials',fontsize=10)
plt.show()

# Calculate mean_rev_onset_prob
mean_rev_onset_prob = np.mean(Full_track_stimtrig_trials, axis=0)

# Calculate sem_rev_onset_prob
num_trials = Full_track_stimtrig_trials.shape[0]
sem_rev_onset_prob = np.std(Full_track_stimtrig_trials, axis=0) / np.sqrt(num_trials)


num_bins = int(mean_rev_onset_prob.shape[0] / bin_size)
binned_rev_onset_prob = np.zeros(num_bins)
binned_sem_rev_onset_prob = np.zeros(num_bins)
for w in range(num_bins):
    start_idx = w * bin_size
    end_idx = start_idx + bin_size
    binned_rev_onset_prob[w] = np.sum(mean_rev_onset_prob[start_idx:end_idx])
    binned_sem_rev_onset_prob[w] = np.sum(sem_rev_onset_prob[start_idx:end_idx])

time = np.linspace(-60, 30, num_bins)
plt.figure()
plt.plot(time, binned_rev_onset_prob, linewidth=2, color='k')
plt.fill_between(time, binned_rev_onset_prob + binned_sem_rev_onset_prob,
                 binned_rev_onset_prob - binned_sem_rev_onset_prob, color='gray', alpha=0.5)
plt.axvline(0, color='r', linestyle='--', linewidth=1.5)
plt.xlabel('Time (s)')
plt.ylabel('probability')
plt.show()

# Find the indices of the first reversal onset for each trial
first_rev_frame = np.zeros(Full_track_stimtrig_trials.shape[0], dtype=float)
first_reversal_onsets = np.zeros((Full_track_stimtrig_trials.shape[0], Full_track_stimtrig_trials.shape[1] - 60*fr))

for p in range(Full_track_stimtrig_trials.shape[0]):
    trial_data = Full_track_stimtrig_trials[p, 60*fr:]  # Focus on data after the stimulus (600 frames)
    if np.any(trial_data == 1):  # If there's at least one reversal onset
        first_rev_idx = np.argmax(trial_data == 1)  # Find index of the first 1
        first_reversal_onsets[p, first_rev_idx] = 1  # Mark the onset
        first_rev_frame[p] = first_rev_idx + 60*fr  # Adjust to get the actual frame number
    else:
        first_rev_frame[p] = np.nan  # No reversal onset in this trial

# Filter out trials without a reversal onset (NaNs)
valid_rev_frames = first_rev_frame[~np.isnan(first_rev_frame)]

# Convert frame numbers to time (s)
valid_rev_times = (valid_rev_frames - 60*fr) / fr  # Offset 600 frames (start at stimulus), divide by framerate to get time in seconds

# Histogram of response duration
plt.figure(figsize=(8, 6))

# Create the histogram
plt.hist(valid_rev_times, bins=10, color='black', edgecolor='white', alpha=0.7)

# Add a vertical line at the critical end point
plt.axvline(x=critical_end_point, color='black', linestyle='--', linewidth=2)
plt.xlabel('Post-stimulus time (s)', fontsize=14)
plt.ylabel('Count', fontsize=14)
plt.title('Histogram of Response Duration', fontsize=16)
plt.savefig("cumulative_slowing.svg", format="svg")
plt.show()





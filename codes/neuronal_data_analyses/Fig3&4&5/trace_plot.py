import numpy as np
import matplotlib
matplotlib.use("Qt5Agg")
import matplotlib.pyplot as plt
import pandas as pd
import matplotlib.patches as patches
plt.rcParams['svg.fonttype'] = 'none'

# Read the CSV file
df = pd.read_csv(r"C:\Users\Jalaja Madhusudhanan\Desktop\server data\ZIM2343&ZIM2344\data\dataset7_traces.csv", delimiter=',', parse_dates=True)
df1 = pd.read_csv(r"C:\Users\Jalaja Madhusudhanan\Desktop\server data\ZIM2343&ZIM2344\data\average_traces.csv", delimiter=',', parse_dates=True)
# Read the CSV file

fr = len(df) / 1890

# Generate x values using linspace
x = np.linspace(0, 1890, num=len(df))

# Sample data
# y1 = df['URXR'].values
# y2 = df['AUAL'].values
# y3 = df['RIBL'].values
# y4 = df['AVAL'].values
# #y5 = df['PVPL'].values
y1 = df['AVAL'].values

# Smooth the data using a moving average
window_size = 15
# y1_smooth = np.convolve(y1, np.ones(window_size)/window_size, mode='same')
# y2_smooth = np.convolve(y2, np.ones(window_size)/window_size, mode='same')
# y3_smooth = np.convolve(y3, np.ones(window_size)/window_size, mode='same')
# y4_smooth = np.convolve(y4, np.ones(window_size)/window_size, mode='same')
#y5_smooth = np.convolve(y5, np.ones(window_size)/window_size, mode='same')
y1_smooth = np.convolve(y1, np.ones(window_size)/window_size, mode='same')

# # Create subplots with shared x-axis
# fig, axs = plt.subplots(4, 1, sharex=True, figsize=(10, 8))  # Increase figure size if needed
# plt.rcParams.update({'font.size': 22})
#
# # Plot smoothed data for each y-value in separate subplots
# axs[0].plot(x, y1_smooth, color='tab:brown')
# axs[0].set_ylabel('AVA', fontsize=14, fontweight='bold')
# #
# # axs[1].plot(x, y2_smooth, color='tab:pink')
# # axs[1].set_ylabel('AUAL', fontsize=14, fontweight='bold')
# #
# # axs[2].plot(x, y3_smooth, color='tab:blue')
# # axs[2].set_ylabel('RIBL', fontsize=14, fontweight='bold')
#
# # axs[3].plot(x, y4_smooth, color='black')
# # axs[3].set_ylabel('AVAL', fontsize=14, fontweight='bold')
# #
# # axs[3].set_xlabel('Time (s)', fontsize=16)
#
# # Adjust spacing
# fig.subplots_adjust(hspace=0.01)  # Increase space between subplots
#
# # Add colored patches
# for ax in axs:
#     ax.axvspan(x[0], x[-1], facecolor='#8dd3c7', alpha=0.7)
#     for k in range(16):
#         start_idx = int(450 * fr + (k * 90 * fr) + 1)
#         end_idx = int(450 * fr + (k * 90 * fr) + 30 * fr)
#         ax.axvspan(x[start_idx], x[end_idx], facecolor='#ffffb3')
#
# # Set x-axis limit
# plt.xlim(0, 1890)
# fig.suptitle('Sensory neurons', fontsize=20, fontweight='bold')
#
# # Ensure labels don't overlap
# fig.tight_layout(pad=0.5)
# # plt.savefig(r"C:\Users\Jalaja Madhusudhanan\Desktop\example_full_traces.svg", format="svg")
# # Show the plot
# plt.show()


# # Read the CSV file
# df = pd.read_csv(r"C:\Users\Jalaja Madhusudhanan\Desktop\server data\ZIM2343&ZIM2344\data\dataset7_traces.csv", delimiter=',')
#
# # Generate x values using linspace
# x = np.linspace(0, 1890, num=len(df))
#
# # Smooth function using a moving average
# window_size = 20
# def smooth(y, window_size):
#     return np.convolve(y, np.ones(window_size)/window_size, mode='same')
#
# # Define neurons and colors
# neurons = ['URXR', 'AUAL', 'RIBL', 'AVAL']
# colors = ['tab:brown', 'tab:green', 'black', 'tab:blue']
#
# # Smooth data
# y_smooth = {neuron: smooth(df[neuron].values, window_size) for neuron in neurons}
#
# # Scale relative to AUAL
# y_ref = y_smooth['AUAL']
# y_scaled = {neuron: (y_smooth[neuron] - np.mean(y_ref)) / np.std(y_ref) for neuron in neurons}
#
# # Define offsets for separation
# offsets = np.linspace(0, 3, len(neurons))  # Create vertical offsets
#
# # Create the plot
# plt.figure(figsize=(10, 6))
# plt.rcParams.update({'font.size': 22})
#
# # Plot each neuron trace with scaling relative to AUAL
# for i, (neuron, color) in enumerate(zip(neurons, colors)):
#     plt.plot(x, y_scaled[neuron] + offsets[i], label=neuron, color=color)
#
# # Add shaded regions
# fr = len(df) / 1890
# plt.axvspan(x[0], x[-1], facecolor='#8dd3c7', alpha=0.7)  # Background color
# for k in range(16):
#     start_idx = int(450 * fr + (k * 90 * fr) + 1)
#     end_idx = int(450 * fr + (k * 90 * fr) + 30 * fr)
#     plt.axvspan(x[start_idx], x[end_idx], facecolor='#ffffb3')
#
# # Scale bar settings
# scale_bar_length = 1  # Relative scale
# scale_bar_x = 1700  # X position
# scale_bar_y = offsets[0] - 0.5  # Place below first trace
#
# # Draw scale bar
# plt.plot([scale_bar_x, scale_bar_x], [scale_bar_y, scale_bar_y + scale_bar_length], 'k', lw=3)
# plt.text(scale_bar_x + 20, scale_bar_y + scale_bar_length / 2, '1 AUAL std', fontsize=14, verticalalignment='center')
#
# # Formatting
# plt.xlabel('Time (s)', fontsize=16)
# plt.yticks(offsets, neurons, fontsize=14, fontweight='bold')  # Use neuron names as y-ticks
# plt.title('Sensory Neurons Activity (Scaled to AUAL)', fontsize=20, fontweight='bold')
# plt.xlim(0, 1890)
# plt.grid(axis='x', linestyle='--', alpha=0.5)
# plt.legend()
# plt.show()


start_time = 1315
end_time = 1600

start_idx = int(start_time * fr)
end_idx = int(end_time * fr)

fig, ax = plt.subplots(figsize=(10,5))

# Plot AVA window
ax.plot(x[start_idx:end_idx], y1_smooth[start_idx:end_idx], color='black')

# Stimulus patches
for k in range(16):

    stim_start = 450 + k*90
    stim_end = stim_start + 30

    # draw patch only if it overlaps the chosen window
    if stim_end > start_time and stim_start < end_time:

        ax.axvspan(max(stim_start, start_time),
                   min(stim_end, end_time),
                   facecolor='#ffffb3',
                   alpha=0.8)

ax.set_xlim(start_time, end_time)
ax.set_ylabel('AVA')
ax.set_xlabel('Time (s)')
ax.set_ylim(-0.5,2)
plt.savefig(r"C:\Users\Jalaja Madhusudhanan\Desktop\AVA_scheme_zoom.svg", format="svg")
plt.show()
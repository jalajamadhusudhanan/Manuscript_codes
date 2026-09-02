# === Standard library ===
import os
import sys
import textwrap
from collections import Counter, defaultdict

# === Scientific stack ===
import numpy as np
import pandas as pd
import scipy.io as scio
import mat73
import imageio
from tqdm import tqdm

# === Scikit-learn ===
from sklearn.decomposition import PCA
from sklearn.cross_decomposition import PLSRegression
from sklearn.discriminant_analysis import LinearDiscriminantAnalysis
from sklearn.model_selection import (
    KFold, LeaveOneOut, train_test_split,
    RepeatedStratifiedKFold, cross_val_score, permutation_test_score
)
from sklearn.preprocessing import StandardScaler, RobustScaler
from sklearn.pipeline import make_pipeline
from sklearn.linear_model import LinearRegression
from sklearn.experimental import enable_iterative_imputer  # noqa
from sklearn.impute import SimpleImputer, IterativeImputer
from sklearn.ensemble import IsolationForest

# === Visualization ===
import matplotlib.pyplot as plt
from matplotlib.ticker import MaxNLocator
from mpl_toolkits.mplot3d import Axes3D
from matplotlib.animation import FuncAnimation
import plotly.graph_objects as go

# === Dash (for interactive apps) ===
import dash
from dash import dcc, html
from dash.dependencies import Input, Output

# === Custom modules ===
import wbfm.utils.general.utils_behavior_annotation as behavior_annotation
import wbfm.utils.visualization.utils_plot_traces as utils_plot_traces

# === Miscellaneous ===
import openpyxl
import dill
import pynumdiff as pdiff

# for wrapping outputs
wrapper = textwrap.TextWrapper(width=50)

def z_score_df(df):
    """
    Z-scores each column of a dataframe.

    Parameters:
    df (pd.DataFrame): Dataframe with numerical columns to be z-scored.

    Returns:
    pd.DataFrame: Dataframe with z-scored columns.
    """
    return (df - df.mean()) / df.std()

def normalize_by_peak(df):
    """
    Normalize each column of a DataFrame by its peak magnitude (max absolute value).
    If a column is all zeros, it is left unchanged to avoid division by zero.
    """
    df = df.copy()
    peak = df.abs().max(axis=0)              # max absolute value per column
    peak[peak == 0] = 1                      # avoid division by zero
    return df / peak

def quantile_subtract(data):
    for column in data.columns:
        quantile_20 = data[column].quantile(0.20)
        data[column] = data[column].apply(lambda x: x - quantile_20)
    return data

def create_sliced_dataframe(df, interval_start, interval_step, slice_duration, stimulus_period, fps):
    interval_start_frame = int(interval_start * fps)
    step_frames = int(interval_step * fps)
    slice_frames = int(slice_duration * fps)
    stimulus_frames=int(stimulus_period * fps)
    result_data = []
    trigger_data=[]

    for group in df['group'].unique():
        group_data = df[df['group'] == group]
        
        
        start_frame = interval_start_frame
        while start_frame +  stimulus_frames <= len(group_data):
            slice_interval = group_data.iloc[start_frame - slice_frames:start_frame]
            trigger_interval = group_data.iloc[start_frame - slice_frames:start_frame+stimulus_frames  ]
            target_interval = group_data.iloc[start_frame :start_frame + stimulus_frames]
            
            # Determine the most common target in the target interval
            most_common_target = target_interval['target'].mode()[0]
            
            # Add the target vector to the sliced interval
            slice_interval = slice_interval.copy()
            trigger_interval =trigger_interval .copy()
            slice_interval['target'] = most_common_target
            trigger_interval['target'] = most_common_target
            
            result_data.append(slice_interval)
            trigger_data.append(trigger_interval)
            start_frame += step_frames

    prestimulus_df = pd.concat(result_data)
    triggered_df= pd.concat(trigger_data)
    return prestimulus_df, triggered_df

def fill_short_states(df, column, max_length=3):
    """
    Identifies short sequences in a specified column of the DataFrame and replaces them with the preceding state.

    Parameters:
    df (pd.DataFrame): The DataFrame containing the state column.
    column (str): The column name for which to fill short sequences.
    max_length (int): The maximum length for a sequence to be considered "short."

    Returns:
    pd.DataFrame: DataFrame with short sequences filled with the previous state.
    """
    
    filled_values = df[column].copy()  # Copy of the column to modify

    i = 0
    while i < len(df):
        # Find the start of a sequence
        start = i
        current_value = df[column].iloc[i]


        # Find the end of the sequence
        while i < len(df) and df[column].iloc[i] == current_value:
            i += 1
        end = i

        # If the sequence length is less than max_length, replace it with the previous state
        if end - start <= max_length and start > 0:
            filled_values[start:end] = df[column].iloc[start - 1]

    df[column] = filled_values
    return df

def extract_events_with_pre_forward(df, label, pre_frames):
    """
    Extract reversal events of a given label and include
    a -pre_frames window of contiguous Forward (state == 1).
    Assign one event_id to the entire stretch.
    """

    df = df.copy()
    is_event = df['label'] == label

    # identify contiguous event blocks
    raw_event_id = (is_event & ~is_event.shift(fill_value=False)).cumsum()
    df.loc[~is_event, 'raw_event_id'] = np.nan
    df.loc[is_event, 'raw_event_id'] = raw_event_id[is_event]

    collected = []
    new_event_id = 0

    for _, ev in df.groupby('raw_event_id'):
        if ev.empty:
            continue

        start = ev.index.min()
        end   = ev.index.max()

        # ---------- pre-window: contiguous Forward only ----------
        pre_start = max(df.index.min(), start - pre_frames)

        pre_indices = []
        for idx in range(start - 1, pre_start - 1, -1):
            if df.loc[idx, 'state'] == 1:
                pre_indices.append(idx)
            else:
                break

        pre_df = df.loc[sorted(pre_indices)]
        event_df = df.loc[start:end]

        block = pd.concat([pre_df, event_df])
        block = block.copy()
        block['event_id'] = new_event_id

        collected.append(block)
        new_event_id += 1

    return pd.concat(collected) if collected else pd.DataFrame()

def remove_jumps_and_interpolate(df, columns, threshold=2,lower_bound=-5, upper_bound=10):
    """
    Detect and interpolate jumps in specified columns of a DataFrame.
    
    Parameters:
        df (pd.DataFrame): DataFrame containing PLS columns.
        columns (list): List of column names to check for jumps.
        threshold (float): Maximum allowed jump value.
    
    Returns:
        pd.DataFrame: DataFrame with jumps interpolated.
    """
    for col in columns:
        # Calculate differences between consecutive values
        diffs = df[col].diff().abs()
        
        # Find indices where the difference exceeds the threshold (i.e., a jump)
        jump_indices = diffs[diffs > threshold].index
        print(f'Jump detected at: {jump_indices}')
        # Set jumps to NaN
        df.loc[jump_indices, col] = np.nan
        
        # Replace values outside the range [lower_bound, upper_bound] with NaN
        outlier_indices = df[(df[col] < lower_bound) | (df[col] > upper_bound)].index
        print(f"Outliers detected in {col} at indices: {outlier_indices}")
        
        df.loc[outlier_indices, col] = np.nan
        
        
        # Interpolate using linear method, but only over valid data points (non-outliers)
        df[col] = df[col].interpolate(method='linear', limit_direction='both').fillna(method='bfill').fillna(method='ffill')
    
    return df

def analyze_event_means(data, label_col, pls_cols):
    """
    Analyze event lengths for each label and compute mean PLS values for each event.

    Parameters:
        data (pd.DataFrame): DataFrame containing labels and PLS modes.
        label_col (str): Column name for labels.
        pls_cols (list): List of PLS mode column names.

    Returns:
        pd.DataFrame: DataFrame with mean PLS values, label, and event length.
    """
    # Step 1: Analyze event lengths and compute means
    event_means = []
    current_label = None
    current_event_data = []

    for i, label in enumerate(data[label_col]):
        if label == current_label:
            # Continue collecting data for the current event
            current_event_data.append(data.iloc[i][pls_cols].values)
        else:
            if current_label is not None:
                # Compute mean for the previous event
                event_mean = np.mean(current_event_data, axis=0)
                event_means.append({
                    **{col: val for col, val in zip(pls_cols, event_mean)},
                    'Label': current_label,
                    'Length': len(current_event_data)
                })
            # Start a new event
            current_label = label
            current_event_data = [data.iloc[i][pls_cols].values]

    # Handle the last event
    if current_label is not None:
        event_mean = np.mean(current_event_data, axis=0)
        event_means.append({
            **{col: val for col, val in zip(pls_cols, event_mean)},
            'Label': current_label,
            'Length': len(current_event_data)
        })

    # Convert to DataFrame
    result_df = pd.DataFrame(event_means)
    return result_df
    
def interpolate(vector, indices):
    """interpolates a vector to a certain length

    Args:
        vector (list): list of values
        indices (list): list of indices

    Returns:
        vector: interpolated vector
    """
    vector = np.interp(indices, np.linspace(0, 1, len(vector)), vector)
    return vector


def resample(dataframe, lengths, frames_num=3529):
    """resamples the data to the same length

    Args:
        dataframe (): dataframe of the stacked data
        length_dict (): dictionary of the number of observations per dataset
        frames_num (int, optional): _description_. Defaults to 3529.

    Returns:
        _type_: _description_
    """

    # we will unstack the dataframe and plot the traces for each dataset
    start_index = 0
    resampled_dataframes = []
    final_indexes = []

    for obs_count in lengths:

        # we take the number of observations from the length dictionary and add it to the start index
        end_index = start_index + obs_count
        df = dataframe.iloc[start_index:end_index].copy()
        if obs_count < frames_num:
            if "state" in df.columns:
                # Interpolate the values between the first and last elements
                # index of current df
                indices = np.linspace(0, frames_num, obs_count)
                df.index = indices

                diff = frames_num - obs_count
                nan_data = pd.DataFrame(
                    np.nan, index=range(diff), columns=df.columns)
                new_indices = np.linspace(1, frames_num-1, diff)
                nan_data.index = new_indices
                df = pd.concat([df, nan_data])
                df = df.sort_index().reset_index(drop=True)
                interpolated_df = df.loc[:, ~df.columns.isin(["state", "dataset"])].interpolate(
                    method="linear", axis=0)
                interpolated_df["state"] = df["state"].interpolate(
                    method="backfill", limit_direction="backward")
                if "dataset" in df.columns:
                    interpolated_df["dataset"] = df["dataset"].interpolate(
                        method="backfill", limit_direction="backward")
                df = interpolated_df
        if obs_count > frames_num:
            # index of current df
            indices = np.linspace(0, obs_count-1, frames_num, dtype=int)
            df = df.iloc[indices]

        resampled_dataframes.append(df)

        start_index = end_index

    resampled_dataframe = pd.concat(
        resampled_dataframes, axis=0, ignore_index=True)

    return resampled_dataframe

def impute_missing_values_in_dataframe(df: pd.DataFrame, d=None) -> pd.DataFrame:
    """
    Given a dataframe with gaps, impute the missing values using PPCA

    Parameters
    ----------
    df
    d

    Returns
    -------

    """
    from ppca import PPCA

    # DLC uses zeros as "failed tracking"
    # Replace with nan and scale
    # df.replace(0, np.NaN, inplace=True)
    df_dat = df.to_numpy()
    scaler = StandardScaler()
    scaler.fit(df_dat)
    dat_normalized = scaler.transform(df_dat)
    # Actually impute
    ppca = PPCA()
    ppca.fit(data=dat_normalized, d=d, verbose=False)
    dat_imputed = scaler.inverse_transform(ppca.data)
    df_imputed = pd.DataFrame(data=dat_imputed, columns=df.columns)
    
    return df_imputed

# Function to smooth data
def smooth_data(df, columns, window=10):
    """
    Smooths specified columns in a DataFrame using a moving average.
    
    Parameters:
    df (pd.DataFrame): The input DataFrame containing the data to be smoothed.
    columns (list of str): List of column names to be smoothed.
    window (int): The window size for the moving average. Default is 10.
    
    Returns:
    pd.DataFrame: A new DataFrame with the specified columns smoothed.
    """
    # Copy the input DataFrame to avoid modifying the original data
    smoothed_df = df.copy()
    
    # Ensure the specified columns are in the DataFrame
    for col in columns:
        if col not in df.columns:
            raise ValueError(f"Column '{col}' not found in the DataFrame.")
    
    # Apply moving average to each specified column
    for col in columns:
        smoothed_df[col] = df[col].rolling(window=window, center=True).mean()
    
    return smoothed_df

####from Liana for PCA/PLS plotting

def analyze_event_lengths_and_compute_traces(data, label_col, pls_cols, window_size):
    """
    Analyze event lengths for each label and compute mean PLS traces.

    Parameters:
        data (pd.DataFrame): DataFrame containing labels and PLS modes.
        label_col (str): Column name for labels.
        pls_cols (list): List of PLS mode column names.
        window_size (int): Number of frames for fixed-size averaging.

    Returns:
        dict: Dictionary containing mean PLS traces for each label.
    """
    # Step 1: Analyze event lengths
    event_lengths = []
    current_label = None
    current_length = 0
    event_start_indices = []
    all_labels = []

    for i, label in enumerate(data[label_col]):
        if label == current_label:
            current_length += 1
        else:
            if current_label is not None:
                event_lengths.append(current_length)
                event_start_indices.append(i - current_length)
                all_labels.append(current_label)
            current_label = label
            current_length = 1

    # Add the last event
    if current_label is not None:
        event_lengths.append(current_length)
        event_start_indices.append(len(data) - current_length)
        all_labels.append(current_label)

    # Create DataFrame for event analysis
    event_df = pd.DataFrame({
        'Label': all_labels,
        'Start': event_start_indices,
        'Length': event_lengths
    })


    # Step 2: Plot histograms of event lengths for each label
    unique_labels = event_df["Label"].unique()
    plt.figure(figsize=(12, 6))
    for i, label in enumerate(unique_labels):
        plt.subplot(1, len(unique_labels), i + 1)
        lengths = event_df[event_df["Label"] == label]["Length"]
        lengths.hist(bins=30, color="skyblue", edgecolor="black")
        plt.title(f"Label: {label}")
        plt.xlabel("Event Length")
        plt.ylabel("Frequency")
        plt.tight_layout()
    plt.show()

    # Step 2: Filter events shorter than the window size
    valid_events = event_df[event_df['Length'] >= window_size]

    # Step 3: Compute mean PLS traces for each label
    mean_traces = {}

    for label in valid_events['Label'].unique():
        # Get all valid events for this label
        label_events = valid_events[valid_events['Label'] == label]

        # Initialize a list to collect traces
        label_traces = []

        for _, event in label_events.iterrows():
            start_idx = event['Start']
            trace = data.iloc[start_idx:start_idx + window_size][pls_cols].values
            label_traces.append(trace)

        # Compute the mean trace for the label
        if label_traces:
            label_traces = np.array(label_traces)
            mean_trace = label_traces.mean(axis=0)
            mean_traces[label] = mean_trace

    return mean_traces

def tolerant_mean(arrs, max_len=100):
    """
    Compute the mean across a list of arrays with varying lengths, 
    tolerating missing values by using masked arrays, with an upper bound on length.

    Parameters:
        arrs (list of np.ndarray): List of 1D arrays with varying lengths.
        max_len (int): Maximum allowable length for arrays (default: 300).

    Returns:
        np.ndarray: Mean values computed across the arrays, considering only valid entries.
    """
    # Cap the maximum length at max_len
    max_len = min(max(max(len(arr) for arr in arrs), 1), max_len)
    arr = np.ma.masked_all((max_len, len(arrs)))  # Create a masked array with all elements masked

    for idx, l in enumerate(arrs):
        length = min(len(l), max_len)  # Ensure array length does not exceed max_len
        arr[:length, idx] = l[:length]  # Truncate the array if it exceeds max_len

    return arr.mean(axis=-1)  # Compute the mean across columns, return the underlying array

def get_averages(dataframe, state, max_len):
    # get all sequences of the same state
    forward_seq = dataframe[dataframe['label'] == state] 
    
    if forward_seq.empty:
        return pd.DataFrame()

    # split the dataframe of a state by event into a list of dataframes for each component
    forward_seq_split0 = [df.iloc[:,0].to_numpy() for _, df in forward_seq.groupby(forward_seq['event'])]
    forward_seq_split1 = [df.iloc[:,1].to_numpy() for _, df in forward_seq.groupby(forward_seq['event'])]
    forward_seq_split2 = [df.iloc[:,2].to_numpy() for _, df in forward_seq.groupby(forward_seq['event'])]
    
    # get the mean over a list of state sequences for each component
    y0 = tolerant_mean(forward_seq_split0,max_len)
    y1 = tolerant_mean(forward_seq_split1,max_len)
    y2 = tolerant_mean(forward_seq_split2,max_len)
    
    # zip the three arrays together
    average_mat = np.array(list(zip(y0, y1, y2)))
    
    # drop nan values
    average_mat = average_mat[~np.isnan(average_mat).any(axis=1)]
    
    return pd.DataFrame(average_mat)

def permutation_neuron_analysis(
    stimulus_df,
    feature_columns,
    slice_duration=60,
    stimulus_period=30,
    fps=5,
    window_start=200,
    window_end=300,
    smoothing_window=10,
    peak_avg_radius=5,
    n_permutations=5000,
    random_seed=42          # ← add this for reproducibility
):
    rng = np.random.default_rng(random_seed)   # seeded generator
    n = (slice_duration + stimulus_period) * fps
    results = []

    for feature in feature_columns:

        feature_values = stimulus_df[feature].values
        target_vals    = stimulus_df['target'].values
        group_vals     = stimulus_df['group'].values

        n_trials = len(feature_values) // n

        # ── FIX: build trial matrix in one shot (no fragmentation) ──
        frame_data = np.array([
            feature_values[i * n : i * n + n]
            for i in range(n_trials)
        ], dtype=float)

        trial_targets = np.array([target_vals[i * n + n - 1] for i in range(n_trials)], dtype=int)
        trial_groups  = np.array([group_vals [i * n + n - 1] for i in range(n_trials)])

        # Build clean DataFrame all at once
        trigger_df = pd.DataFrame(frame_data, columns=list(range(n)))
        trigger_df['target'] = trial_targets
        trigger_df['group']  = trial_groups

        frame_cols = list(range(n))

        # ── STEP 1: Find peak ──
        mean_0 = trigger_df[trigger_df['target'] == 0][frame_cols].mean()
        mean_1 = trigger_df[trigger_df['target'] == 1][frame_cols].mean()

        sm0 = mean_0.rolling(window=smoothing_window, min_periods=1, center=True).mean()
        sm1 = mean_1.rolling(window=smoothing_window, min_periods=1, center=True).mean()

        diff = np.abs(sm0.iloc[window_start:window_end].values - 
                      sm1.iloc[window_start:window_end].values)
        
        local_max_idx  = np.argmax(diff)
        abs_frame_idx  = window_start + local_max_idx
        max_difference = diff[local_max_idx]

        # ── STEP 2: Average around peak ──
        start = max(0, abs_frame_idx - peak_avg_radius)
        end   = min(n, abs_frame_idx + peak_avg_radius + 1)

        # FIX: assign to a new column cleanly, avoid fragmentation warning
        peak_vals = frame_data[:, start:end].mean(axis=1)   # pure numpy, no fragmentation
        trigger_df = trigger_df[['target', 'group']].copy()  # drop frame cols, keep only what's needed
        trigger_df['value'] = peak_vals

        df_model = trigger_df.dropna()

        # ── Keep only animals with both conditions ──
        valid_groups = df_model.groupby('group')['target'].nunique()
        valid_groups = valid_groups[valid_groups == 2].index
        df_model = df_model[df_model['group'].isin(valid_groups)]
        n_animals = df_model['group'].nunique()

        # ── STEP 3: Observed statistic ──
        animal_means = (
            df_model.groupby(['group', 'target'])['value']
            .mean()
            .unstack()
            .dropna()
        )

        if animal_means.shape[0] < 3:
            results.append({
                'Feature': feature, 'Max Difference': max_difference,
                'Effect': np.nan, 'P-Value': np.nan,
                'Peak Frame': abs_frame_idx, 'N animals': n_animals
            })
            continue

        observed = (animal_means[1] - animal_means[0]).mean()

        # ── STEP 4: Permutation test ──
        groups      = df_model['group'].values
        targets     = df_model['target'].values
        values      = df_model['value'].values
        unique_grps = np.unique(groups)

        perm_stats = []
        for _ in range(n_permutations):
            perm_targets = targets.copy()

            # shuffle labels within each animal using seeded rng
            for g in unique_grps:
                mask = groups == g
                perm_targets[mask] = rng.permutation(targets[mask])

            # compute animal-level means with numpy for speed
            means_0, means_1 = [], []
            for g in unique_grps:
                mask = groups == g
                t = perm_targets[mask]
                v = values[mask]
                m0 = v[t == 0].mean() if (t == 0).any() else np.nan
                m1 = v[t == 1].mean() if (t == 1).any() else np.nan
                means_0.append(m0)
                means_1.append(m1)

            means_0 = np.array(means_0, dtype=float)
            means_1 = np.array(means_1, dtype=float)

            valid = ~np.isnan(means_0) & ~np.isnan(means_1)
            if valid.sum() >= 3:
                perm_stats.append((means_1[valid] - means_0[valid]).mean())

        perm_stats = np.array(perm_stats)
        
        p_value = np.mean(np.abs(perm_stats) >= np.abs(observed)) if len(perm_stats) else np.nan

        results.append({
            'Feature': feature, 'Max Difference': max_difference,
            'Effect': observed, 'P-Value': p_value,
            'Peak Frame': abs_frame_idx, 'N animals': n_animals
        })

    # ── STEP 5: FDR correction ──
    results_df = pd.DataFrame(results)
    valid_p    = results_df['P-Value'].notna()
    
    reject, pvals_fdr, _, _ = multipletests(
        results_df.loc[valid_p, 'P-Value'], method='fdr_bh'
    )

    results_df['P-Value-FDR'] = np.nan
    results_df.loc[valid_p, 'P-Value-FDR'] = pvals_fdr
    results_df['Significant'] = False
    results_df.loc[valid_p, 'Significant'] = reject

    return results_df
    
def plot_comparison_scatter(df1, df2, p_value_threshold=0.05, title="Comparison of Max Differences"):
    """
    Create a scatter plot comparing the 'Max Difference' values from two DataFrames
    and highlights points with significant p-values in x and/or y.

    Parameters:
    - df1: First DataFrame with columns ['Feature', 'Max Difference', 'p_value'].
    - df2: Second DataFrame with columns ['Feature', 'Max Difference', 'p_value'].
    - p_value_threshold: Threshold for determining significance of p-values.
    - title: Title of the plot.
    """
    import matplotlib.pyplot as plt
    import pandas as pd

    # Merge the DataFrames on 'Feature'
    merged_df = pd.merge(df1, df2, on='Feature', suffixes=('_x', '_y'))
    
    # Extract x, y values, features, and p-values
    x_values = merged_df['Max Difference_x']
    y_values = merged_df['Max Difference_y']
    features = merged_df['Feature']
    p_value_x = merged_df['P-Value_x']
    p_value_y = merged_df['P-Value_y']

    # Determine colors based on p-value significance
    colors = [
        'black' if (px < p_value_threshold and py < p_value_threshold)
        else 'red'   if (px < p_value_threshold)
        else 'green' if (py < p_value_threshold)
        else 'gray'
        for px, py in zip(p_value_x, p_value_y)
    ]

    # Create scatter plot
    plt.figure(figsize=(12, 8))
    scatter = plt.scatter(x_values, y_values, c=colors, alpha=0.7, edgecolor='k', s=70)

    # Add feature name labels to each point
    for i, feature in enumerate(features):
        plt.text(
            x_values.iloc[i], y_values.iloc[i], feature,
            fontsize=12, ha='right', va='bottom', color='black'
        )

    # Customize plot
    plt.title(title, fontsize=16)
    plt.xlabel("Spontaneous activity (Max Difference)", fontsize=16)
    plt.ylabel("Residual activity (Max Difference)", fontsize=16)

    # Legend entries
    plt.scatter([], [], color='red',   label='X-significant (only)')
    plt.scatter([], [], color='green', label='Y-significant (only)')
    plt.scatter([], [], color='black', label='Both significant')
    plt.scatter([], [], color='gray',  label='Not significant')
    plt.legend(title='Significance', fontsize=12, title_fontsize=14)

    # Finalize & save
    plt.tight_layout()
    plt.rcParams['svg.fonttype'] = 'none'
    plt.savefig("neuron_contribution_scatter.svg", format='svg', dpi=300)
    plt.show()

def truncate(dataframe, n=100):
    """truncates the first and the last n frames of the data

    Args:
        dataframe (pd.DataFrame): dataframe of the stacked data
        n (int, optional): _description_. Defaults to 100.

    Returns:
        truncated_dataframe (pd.DataFrame): truncated dataframe
    """

    # we will unstack the dataframe and plot the traces for each dataset
    start_index = 0
    truncated_dataframes = []

    for obs_count in dataframe.groupby("dataset").size().values:

        end_index = start_index + obs_count
        df = dataframe.iloc[start_index+n:end_index-n]

        # we replace the dataframe with the interpolated dataframe
        truncated_dataframes.append(df)

        start_index = end_index

    truncated_dataframe = pd.concat(
        truncated_dataframes, axis=0, ignore_index=True)

    return truncated_dataframe

def compute_derivatives(dataframe, length_dict, iterations=1, gamma=0.01, dt=1/3):
    """computes the derivatives of the data

    Args:
        dataframe (pd.DataFrame): dataframe of the data

    Returns:
        dataframe (pd.DataFrame): dataframe of the data with derivatives
    """

    resampled_derivatives = dataframe.copy()

    start_index = 0
    # we compute the derivatives of the data
    for obs_count in length_dict.values():
        end_index = start_index + obs_count
        for col_index in range(len(dataframe.columns)):
            # x_hat: estimated (smoothed) x, dxdt_hat: estimated dx/dt, [1, 0.0001]: regularization parameters -> gamma=0.2 is too high, derivatives become too blocky
            x_hat, dxdt_hat = pdiff.total_variation_regularization.iterative_velocity(
                resampled_derivatives.iloc[start_index:end_index, col_index], dt, [iterations, gamma])
            resampled_derivatives.iloc[start_index:end_index,
                                       col_index] = dxdt_hat
        start_index = end_index

    return resampled_derivatives


def compute_cumsum(dataframe, length_dict):
    start_index = 0
    for obs_count in length_dict.values():
        end_index = start_index + obs_count
        for col_index in range(len(dataframe.columns)):
            integrated = np.cumsum(
                dataframe.iloc[start_index:end_index, col_index])
            dataframe.iloc[start_index:end_index, col_index] = integrated + \
                abs(integrated.min()) + 0.01
        start_index = end_index


def normalize_per_dataset(dataframe, lengths, scaler):
    """normalizes the data per dataset

    Args:
        dataframe (pd.DataFrame): dataframe of the stacked data
        lengths (list): list of the number of observations per dataset

    Returns:
        normalized_dataframe: normalized dataframe
    """

    normalized_dfs = []

    start_index = 0
    # we will unstack the dataframe and plot the traces for each dataset
    for obs_count in lengths:

        # we take the number of observations from the length dictionary and add it to the start index
        end_index = start_index + obs_count
        resampled_dataframe_df = dataframe.iloc[start_index:end_index]

        normalized_dfs.append(pd.DataFrame(scaler.fit_transform(
            resampled_dataframe_df), columns=resampled_dataframe_df.columns))

        start_index = end_index

    normalized_dataframe = pd.concat(normalized_dfs, ignore_index=True)
    return normalized_dataframe


def get_num_rows_columns(dataframe):
    """calculates the number of rows and columns in a dataframe

    Args:
        dataframe (pandas.DataFrame): a pandas dataframe

    Returns:
        num_rows (int): number of rows in the dataframe
        num_cols (int): number of columns in the dataframe
    """
    num_columns = len(list(dataframe.columns))
    num_rows = int(num_columns ** 0.5) + 1
    num_cols = num_columns // num_rows + 1
    return num_rows, num_cols


def count_IDs(dataframes):
    """counts the number of IDs in each dataset and the total number of IDs in all datasets

    Args:
        dataframes (dict): dictionary of dataframes, where the key is the name of the dataset and the value is the dataframe itself

    Returns:
        all_IDed_neurons (dict): dictionary of all neurons and their counts
        IDs_per_set (dict): dictionary of the number of IDs per dataset
    """

    # initialising the dictionaries for counting the IDs
    all_IDed_neurons = Counter()
    IDs_per_set = defaultdict()

    for key, value in dataframes.items():
        # take only columns that have IDs (e.g. "AVAR","RIBL",..)
        IDed_neurons = [
            column for column in value.columns if "neuron" not in column]
        dataframes[key] = value[IDed_neurons]

        # some cleaning, removing question marks (rebecca's data), useless columns and duplicated columns
        dataframes[key].columns = dataframes[key].columns.str.replace(
            '?', '', regex=True)
        dataframes[key] = dataframes[key].loc[:, ~
                                              dataframes[key].columns.duplicated()]
        dataframes[key] = dataframes[key].drop(columns=[columnname for columnname in [
                                               'is this OLQ or URA', 'OLQDLorR', 'masked', 'retrace', ''] if columnname in dataframes[key].columns])

        # incrementing the counter for each ID
        for ID in list(dataframes[key].columns):
            all_IDed_neurons[ID] += 1

        # counting the number of IDs per dataset
        IDs_per_set[key] = len(dataframes[key].columns)

    return all_IDed_neurons, IDs_per_set


def visualize_IDs(dictionary, title, xlabel, ylabel, coloring="tab:orange", display_all_values=False):
    """plots a dictionary of neurons and their values (e.g. counts) as a bar chart

    Args:
        dictionary: dictionary of neurons and their values (e.g. counts)
        title: title of the plot
        xlabel: label of the x-axis
        ylabel: label of the y-axis
        coloring: color of the bars
        display_all_values: if True, all values are displayed on the y-axis, if False, only every 10th value is displayed

    Returns:
        fig, ax: figure and axis of the plot
    """

    dictionary = dict(
        sorted(dictionary.items(), key=lambda item: item[1], reverse=False))
    dict_keys = list(dictionary.keys())
    dict_values = list(dictionary.values())

    # Create the figure and axis
    # You can adjust the width as needed
    fig, ax = plt.subplots(figsize=(15, 7))
    plt.ylim(min(dict_values)-(max(dict_values)*0.05),
             max(dict_values)+(max(dict_values)*0.05))

    # Create the cumulative bar chart and add markers on top of each bar
    ax.bar(dict_keys, dict_values,
           color=coloring, alpha=0.7, width=0.5)
    ax.plot(dict_keys, dict_values, marker='o',
            color=coloring, linestyle='', label='Markers')

    x_positions = [neurons_key-0.1 for neurons_key in range(len(dict_keys))]
    # Set y-axis and x-axis labels
    if display_all_values:
        ax.set_yticks(dict_values)
    else:
        step = len(dict_values) // 10
        # Use slicing to get 10 equidistant values from the list of y-values
        ax.set_yticks(dict_values[::step])
    ax.set_xticks(x_positions)
    # Adjust rotation and alignment as needed
    ax.set_xticklabels(dict_keys, rotation=90)

    # Set the title and labels
    ax.set_title(title)
    ax.set_xlabel(xlabel)
    ax.set_ylabel(ylabel)

    return fig, ax


def visualize_fps(dataframe, title, xlabel, ylabel, coloring="tab:red", display_all_values=False):
    """plots a dictionary of neurons and their values (e.g. counts) as a bar chart

    Args:
        dataframe: dataframe with column 'dataset' to indicate how many time points belong to the recording
        title: title of the plot
        xlabel: label of the x-axis
        ylabel: label of the y-axis
        coloring: color of the bars
        display_all_values: if True, all values are displayed on the y-axis, if False, only every 10th value is displayed

    Returns:
        fig, ax: figure and axis of the plot
    """

    dict_keys = list(dataframe["dataset"].unique())
    dict_values = list(dataframe.groupby('dataset').size().values)

    # Create the figure and axis
    # You can adjust the width as needed
    fig, ax = plt.subplots(figsize=(15, 7))
    plt.ylim(min(dict_values)-(max(dict_values)*0.05),
             max(dict_values)+(max(dict_values)*0.05))

    # Create the cumulative bar chart and add markers on top of each bar
    ax.bar(dict_keys, dict_values,
           color=coloring, alpha=0.7, width=0.5)
    ax.plot(dict_keys, dict_values, marker='o',
            color=coloring, linestyle='', label='Markers')

    x_positions = [neurons_key-0.1 for neurons_key in range(len(dict_keys))]
    # Set y-axis and x-axis labels
    if display_all_values:
        ax.set_yticks(dict_values)
    else:
        step = len(dict_values) // 10
        # Use slicing to get 10 equidistant values from the list of y-values
        ax.set_yticks(dict_values[::step])

    plt.gca().yaxis.set_major_locator(MaxNLocator(prune='lower'))

    ax.set_xticks(x_positions)
    # Adjust rotation and alignment as needed
    ax.set_xticklabels(dict_keys, rotation=90)

    # Set the title and labels
    ax.set_title(title)
    ax.set_xlabel(xlabel)
    ax.set_ylabel(ylabel)

    return fig, ax


def vip(model):
    """calculates the VIP scores of a PLSR model as described on github in a scikit-learn thread: https://github.com/scikit-learn/scikit-learn/issues/7050#issuecomment-345208503

    Args:
        model (PLSRegression): PLSR model

    Returns:
        list: VIP scores
    """

    t = model.x_scores_
    w = model.x_weights_
    q = model.y_loadings_
    p, h = w.shape
    vips = np.zeros((p,))
    s = np.diag(t.T @ t @ q.T @ q).reshape(h, -1)
    total_s = np.sum(s)
    for i in range(p):
        weight = np.array(
            [(w[i, j] / np.linalg.norm(w[:, j]))**2 for j in range(h)])
        vips[i] = np.sqrt(p*(s.T @ weight)/total_s)
    return vips


def get_R2_predictions(dataframes, all_IDed_neurons):
    """calculates the R2 scores of each neuron and the predictions of each neuron

    Args:
        dataframes (dict): dictionary of dataframes, where the key is the name of the dataset and the value is the dataframe itself
        all_IDed_neurons (dict): dictionary of all neurons and their counts

    Returns:
        avg_r2 (dict): dictionary of neurons and their average R2 scores
        predictions (dict): dictionary of neurons and their predicted activity
        raw_data (dict): dictionary of neurons and their raw data
    """

    rsquareds = defaultdict()
    raw_data = defaultdict(lambda: defaultdict(list))
    predictions = defaultdict(lambda: defaultdict(list))
    top_predictors = defaultdict(lambda: defaultdict(list))
    threshold = 10
    avg_r2 = defaultdict()

    cv = KFold(n_splits=5, random_state=1, shuffle=True)

    for key, dataframe in dataframes.items():

        for neuron in dataframe.columns:

            # skip neurons that have been IDed less than 10 times
            if all_IDed_neurons[neuron] < threshold:
                continue

            # y is our response variable, X is our explanatory variable
            y = dataframe[neuron]
            X = dataframe.drop(columns=[neuron])
            N = 3  # number of components to use for PLSR

            # train a simple linear regression model and get the r^2 score and prediction of the neuron
            model = PLSRegression(n_components=N).fit(X, y)

            # quantify how good the model is by looking at the R2 values in a cross-validated fashion
            r2s = cross_val_score(model, X, y, scoring='r2',
                                  cv=cv, n_jobs=-1)
            rsquare = np.mean(r2s)

            if neuron in rsquareds:
                rsquareds[neuron] += rsquare
            else:
                rsquareds[neuron] = rsquare

            # store the prediction of the neuron in a dictionary
            prediction = model.predict(X)
            predictions[neuron][key] = prediction

            # Calculate VIP scores
            VIP_scores = vip(model)
            predictors = [(list(X.columns)[i], VIP_scores[i])
                          for i in VIP_scores.argsort()[::-1]]

            top_VIPs = VIP_scores.argsort()[::-1][:5]
            top_5_predictors = [(list(X.columns)[i], VIP_scores[i])
                                for i in top_VIPs]
            for i in range(len(predictors)):
                predictor = predictors[i][0]
                if predictor in top_predictors[neuron]:
                    top_predictors[neuron][predictor].append(
                        predictors[i][1])
                else:
                    top_predictors[neuron][predictor] = [
                        predictors[i][1]]

            # add the raw data to a dictionary
            raw_data[neuron][key] = np.array(y)

    # averaging the R2 scores over all datasets
    for neuron in rsquareds:
        avg_r2[neuron] = rsquareds[neuron]/all_IDed_neurons[neuron]

    return avg_r2, predictions, top_predictors, raw_data


# def plot_from_stacked_imputed(dataset_dict, df1, df2, saving_path):
#     """plots the stacked and imputed dataframes and saves the plots

#     Args:
#         dataset_dict (dict): dictionary of the number of observations per dataset
#         dataframe1 (pd.DataFrame): dataframe of the stacked data
#         dataframe2 (pd.DataFrame): dataframe of the imputed data
#         saving_path (str): path to save the plots
#     """

#     start_index = 0
#     count = 0

#     dataframe1 = df1.copy()
#     dataframe2 = df2.copy()

#     # we will unstack the dataframe and plot the traces for each dataset
#     for obs_count in dataset_dict.values():

#         if "state" in dataframe1.columns:
#             dataframe1.drop(columns=["state"], inplace=True)
#         if "state" in dataframe2.columns:
#             dataframe2.drop(columns=["state"], inplace=True)

#         # we take the number of observations from the length dictionary and add it to the start index
#         end_index = start_index + obs_count
#         df_dataframe2 = dataframe2.iloc[start_index:end_index]
#         df_dataframe1 = dataframe1.iloc[start_index:end_index]

#         # 2 dataframe grid plots, imputed in blue (first argument, such that it is in the back) and unimputed in orange (second argument, on top)
#         fig = plot_traces.make_grid_plot_from_two_dataframes(
#             df_dataframe1, df_dataframe2, twinx_when_reusing_figure=True)
#         # fig, ax = plot_traces.make_grid_plot_from_dataframe(df_imputed)

#         # save all plots in a folder
#         pathname = saving_path + list(dataset_dict.keys())[count] + ".png"
#         fig.savefig(pathname)
#         plt.close(fig)
#         start_index = end_index
#         count += 1


# def plot_from_single_imputed(raw_data, predictions, delta_path, model_path, plot_kwargs):
#     """plots the raw data against the predictions and the delta between the two and saves the plots

#     Args:
#         raw_data (defaultdict): dataframe of the raw data
#         predictions (defaultdict): dictionary of neurons and their predictions
#         delta_path (str): path to save the delta plots
#         model_path (str): path to save the model plots
#         **plot_kwargs: additional arguments for the plot
#     """

#     modelled_activity_patterns = defaultdict()

#     for neuron, df in predictions.items():
#         raw_neuron = list(raw_data[neuron].values())
#         modelled_neuron = list(df.values())
#         diff = [raw_neuron[i]-modelled_neuron[i]
#                 for i in range(len(raw_neuron))]

#         modelled_activity_patterns[neuron] = pd.DataFrame(modelled_neuron).T

#         # Calculate the number of rows and columns for subplots
#         num_rows, num_cols = get_num_rows_columns(
#             modelled_activity_patterns[neuron])

#         figsample, ax = plt.subplots(num_rows, num_cols, figsize=(12, 8))

#         # create delta figures
#         fig_delta, ax = plot_traces.make_grid_plot_from_dataframe(
#             pd.DataFrame(diff).T, fig=figsample)
#         fig_delta.savefig(delta_path+neuron+".png")

#         # clear figure
#         plt.cla()

#         figsample, ax = plt.subplots(num_rows, num_cols, figsize=(12, 8))

#         fig, ax = plot_traces.make_grid_plot_from_dataframe(
#             modelled_activity_patterns[neuron], fig=figsample)

#         fig, ax = plot_traces.make_grid_plot_from_dataframe(pd.DataFrame(
#             raw_neuron).T, fig=fig, twinx_when_reusing_figure=True, **plot_kwargs)

#         # save all plots in a folder
#         fig.savefig(model_path+neuron+".png")


def find_percent(data, min_value):
    """calculates the percentile of a value in a list

    Args:
        data (list): list of values
        min_value (float): value for which the percentile is calculated

    Returns:
        percent: percentile of the value
    """
    sorted_data = sorted(data)
    rank = sorted_data.index(min_value) + 1
    total_points = len(sorted_data)
    percent = 100 - ((rank - 0.5) / total_points) * 100
    return percent


def get_behavioural_states(dataframe):
    """taken from wbfm function @approximate_turn_annotations_using_ids and modified to return the behavioural states from a dataframe and not from a project

    Args:
        dataframe (pd.DataFrame): dataframe of the data

    Returns:
        turn_vec (pd.Series): a series of the behavioural states
    """

    y_dorsal = behavior_annotation.combine_pair_of_ided_neurons(
        dataframe, base_name='SMDD')
    y_ventral = behavior_annotation.combine_pair_of_ided_neurons(
        dataframe, base_name='SMDV')
    y_reversal = behavior_annotation.combine_pair_of_ided_neurons(
        dataframe, base_name='AVA')

    dorsal_vec = behavior_annotation.calculate_rise_high_fall_low(y_dorsal)
    ventral_vec = behavior_annotation.calculate_rise_high_fall_low(
        y_ventral)
    reversal_vec = behavior_annotation.calculate_rise_high_fall_low(
        y_reversal)

    ava_fall_starts, ava_fall_ends = behavior_annotation.get_contiguous_blocks_from_column(
        reversal_vec == 'fall', already_boolean=True)
    ava_high_starts, ava_high_ends = behavior_annotation.get_contiguous_blocks_from_column(
        reversal_vec == 'high', already_boolean=True)
    ava_rise_starts, ava_rise_ends = behavior_annotation.get_contiguous_blocks_from_column(
        reversal_vec == 'rise', already_boolean=True)

    turn_vec = pd.Series(np.zeros_like(reversal_vec),
                         index=reversal_vec.index, dtype=object)
    for s, e in zip(ava_fall_starts, ava_fall_ends):
        if s <= 1:
            continue
        # Check if dorsal or ventral are in a rise state, including some time after
        e_padding = e + 10
        len_dorsal_rise = len(np.where(dorsal_vec[s:e_padding] == 'rise')[0])
        len_ventral_rise = len(np.where(ventral_vec[s:e_padding] == 'rise')[0])

        if len_ventral_rise > len_dorsal_rise:

            turn_vec[s:e] = 'ventral'
        elif len_ventral_rise < len_dorsal_rise:
            turn_vec[s:e] = 'dorsal'
        elif len_ventral_rise == 0 and len_dorsal_rise == 0:
            continue
        else:
            # This means they were both rising the same non-zero amount
            if np.mean(y_ventral[s:e_padding]) > np.mean(y_dorsal[s:e_padding]):
                turn_vec[s:e] = 'ventral'
            else:
                turn_vec[s:e] = 'dorsal'

    for s, e in zip(ava_high_starts, ava_high_ends):
        turn_vec[s:e] = 'reversal'

    for s, e in zip(ava_rise_starts, ava_rise_ends):
        turn_vec[s:e] = 'reversal'

    turn_vec.replace(0, 'forward', inplace=True)

    return turn_vec


def get_LLO_PCAs(dataframe, n_components=3):
    """calculates the PCA loadings for each neuron using leave one out cross validation

    Args:
        dataframe (pd.DataFrame): dataframe of the data
        n_components (int, optional): number of PCA components. Defaults to 3.

    Returns:
        pca_all_splits (defaultdict): dictionary of the PCA loadings for each neuron
    """

    loo = LeaveOneOut()
    pca_all_splits = defaultdict(list)

    # 73 iterations are done because we have 73 neurons
    for train_index, test_index in loo.split(dataframe):
        X_train = dataframe.iloc[train_index]

        # Fit the PCA model on the training data
        pca = PCA(n_components=n_components)
        pca_neuron_loo = pca.fit_transform(X_train)

        # Retrieve and store the PCA loadings of the first component as a DataFrame
        for i in range(n_components):
            variable_name = f"pca{i+1}_all_splits"
            pca_df_loo = pd.DataFrame(pca_neuron_loo[:, i])
            pca_df_loo["neuron"] = X_train.index
            pca_df_loo = pca_df_loo.rename(columns={0: 'Mode {}'.format(i+1)})
            pca_all_splits[variable_name].append(pca_df_loo)

    return pca_all_splits


def get_mahalanobis_distances(dataframe):
    # computing the covariance which is important for the mahalanobis distance

    cov_matrix = dataframe.cov()
    # compute inverse of covariance matrix
    inv_cov_matrix = np.linalg.inv(cov_matrix)
    mean_predictors = np.mean(dataframe, axis=0)
    mahalanobis_distances = [mahalanobis(obs[1], mean_predictors, inv_cov_matrix) for obs in dataframe
                             .iterrows()]
    return mahalanobis_distances


def determine_turn(dataframe, original_turn_vec):
    in_turn = False
    count = 0
    smdv = 0
    smdd = 0
    actual_turn_vec = original_turn_vec.copy()
    for idx, state in enumerate(original_turn_vec):
        if state == "turn":
            in_turn = True
            count = count + 1

            smdvr = dataframe.loc[idx, "SMDVR"]
            smdvl = dataframe.loc[idx, "SMDVL"]
            smdv = smdv + (smdvr + smdvl) / 2

            smddr = dataframe.loc[idx, "SMDDR"]
            smddl = dataframe.loc[idx, "SMDDL"]
            smdd = smdd + (smddr + smddl) / 2

        else:
            if in_turn:
                if (smdv/count) > (smdd/count):
                    actual_turn_vec[idx-count:idx] = "ventral"
                else:
                    actual_turn_vec[idx-count:idx] = "dorsal"
                smdv = 0
                smdd = 0
                count = 0
                in_turn = False
            actual_turn_vec[idx] = state
    return actual_turn_vec


def apply_PCA_with_smoothing(dataframe):
    pca = PCA(n_components=3)
    dataframe_pca = pd.DataFrame(pca.fit_transform(
        dataframe.loc[:, ~dataframe.columns.isin(["state", "dataset"])]))
    window_size = 10
    # Applying a 10-sample sliding average for smoother visualizations!
    for i in range(3):
        dataframe_pca[i] = np.convolve(dataframe_pca[i], np.ones(
            window_size)/window_size, mode='same')

    return dataframe_pca


def plot_PCs(dataframe, filename='PCA_plot.html', variances=None):
    """plots the first three principal components of the data

    Parameters
    ----------
        dataframe (pd.DataFrame): dataframe of the data with a column of behavioural states
        filename (str): filename of the plot
        variances (list): list of the variances explained by each principal component

    Returns
    ----------
        fig (go.Figure()): figure of the plot
    """

    plotly_pca, names = utils_plot_traces.modify_dataframe_to_allow_gaps_for_plotly(
        dataframe, [0, 1, 2], 'state')
    state_codes = dataframe['state'].unique()
    phase_plot_list = []
    custom_colors = {
        'reversal': 'rgb(255,99,71)',
        'forward': 'rgb(100,149,237)',
        'dorsal': 'rgb(154,205,50)',
        'ventral': 'rgb(255,215,0)',
        'sustained reversal': 'rgb(128, 0, 32)',
        'post reversal': 'rgb(130, 30, 20)'
    }

    if 'dataset' in dataframe.columns:
        text = dataframe['dataset']
        hovertemplate = 'x:%{x}<br>y:%{y}<br>z:%{z}<br>%{text}'
    else:
        text = None
        hovertemplate = 'x:%{x}<br>y:%{y}<br>z:%{z}'

    for i, state_code in enumerate(state_codes):
        phase_plot_list.append(
            go.Scatter3d(x=plotly_pca[names[0][i]], y=plotly_pca[names[1][i]], z=plotly_pca[names[2][i]], mode="lines",
                         name=state_code, line=dict(color=custom_colors[state_code], width=3), hovertemplate=hovertemplate, text=text))

    fig = go.Figure()
    fig.add_traces(phase_plot_list)
    if variances is not None:
        scene = dict(xaxis_title=f"PC 1 ({variances[0]:.2f}%)",
                     yaxis_title=f"PC 2 ({variances[1]:.2f}%)",
                     zaxis_title=f"PC 3 ({variances[2]:.2f}%)")
    else:
        scene = dict(xaxis_title="PC 1",
                     yaxis_title="PC 2",
                     zaxis_title="PC 3")

    fig.update_layout(scene=scene)
    fig.write_html(filename)
    # fig.show()
    return fig


def plot_PCs_separately(datasets):
    # datasets is a dictionary of dataframe containing the data projected to PC space

    app = dash.Dash(__name__)

    @app.callback(
        Output('graph', 'figure'),
        [Input('slider', 'value')])
    def update_graph(selected_dataset):
        keyname = list(datasets.keys())[selected_dataset]
        fig = plot_PCs(datasets[keyname])
        return fig

    app.layout = html.Div([
        dcc.Graph(id='graph'),
        dcc.Slider(
            id='slider',
            min=1,
            max=len(datasets.keys()),
            value=1,
            step=1
        )
    ])

    return app


def plot_PCs_iteratively(datasets):
    # datasets is a dictionary of dataframe containing the data projected to PC space

    app = dash.Dash(__name__)
    #
    #
    # fig =

    @app.callback(
        Output('graph', 'figure'),
        [Input('slider', 'value')])
    def update_graph(selected_dataset):

        if selected_dataset == 1:
            keyname = list(datasets.keys())[0]
            df = datasets[keyname]
            return plot_PCs(df)

        else:
            selected_datasets = []
            for i in range(selected_dataset):
                keyname = list(datasets.keys())[i]
                selected_datasets.append(datasets[keyname])

            df = pd.concat(selected_datasets, ignore_index=True)
            fig = plot_PCs(df)
            return fig

    app.layout = html.Div([
        dcc.Graph(id='graph'),
        dcc.Slider(
            id='slider',
            min=1,
            max=len(datasets.keys()),
            value=1,
            step=1
        )
    ])

    return app


def plot_PC_gif(dataframe, turn_vec, fn):
    plotly_pca, names = utils_plot_traces.modify_dataframe_to_allow_gaps_for_plotly(
        dataframe, [0, 1, 2], 'state')
    state_codes = turn_vec.unique()

    custom_colors = {
        'reversal': 'rgb(255,99,71)',
        'forward': 'rgb(100,149,237)',
        'dorsal': 'rgb(154,205,50)',
        'ventral': 'rgb(255,215,0)',
        'sustained reversal': 'rgb(128, 0, 32)'
    }
    phase_plot_list = []
    for i, state_code in enumerate(state_codes):
        phase_plot_list.append(
            go.Scatter3d(x=plotly_pca[names[0][i]], y=plotly_pca[names[1][i]], z=plotly_pca[names[2][i]], mode='lines',
                         name=state_code, line=dict(color=custom_colors[state_code], width=3)))

    fig = go.Figure()
    fig.add_traces(phase_plot_list)
    fig.update_layout(scene=dict(camera=dict(eye=dict(x=1.25, y=1.25, z=1.25)), xaxis_title='Mode 1',
                                 yaxis_title='Mode 2',
                                 zaxis_title='Mode 3'))

    num_frames = 100  # Adjust the number of frames as needed

    rotation_angles = np.linspace(0, 2 * np.pi, num_frames)

    os.makedirs("frames", exist_ok=True)
    for i, angle in enumerate(rotation_angles):
        fig.update_layout(scene_camera_eye=dict(
            x=np.cos(angle) * 1.25, y=np.sin(angle) * 1.25, z=1.25))
        image_filename = os.path.join("frames", f"frame_{i:03d}.png")

        # note: this requires a downgrade of the engine kaleido from 0.2.1 to 0.1.0 - pathetic, I know
        fig.write_image(image_filename)

    # create GIF out of all the different angles of the principal components

    images = []

    for filename in os.listdir("frames"):
        if filename.endswith(".png"):
            images.append(imageio.imread(os.path.join("frames", filename)))

    imageio.mimsave(fn, images, duration=0.1)


def apply_isolation_forest(X, contamination=0.025):
    if "dataset" in X.columns:
        X = X.drop(columns=["dataset", "state"])
    clf = IsolationForest(n_estimators=100, max_samples='auto',
                          contamination=contamination, warm_start=True)
    clf.fit(X)  # fit 10 trees
    X["outlier"] = ["outlier" if x == -
                    1 else "no outlier" for x in clf.predict(X).tolist()]
    return X


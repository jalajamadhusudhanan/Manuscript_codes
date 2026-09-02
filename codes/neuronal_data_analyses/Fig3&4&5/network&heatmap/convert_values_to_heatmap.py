import pandas as pd
import matplotlib
matplotlib.use('TkAgg')
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.colors import TwoSlopeNorm

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.colors import TwoSlopeNorm
plt.rcParams['svg.fonttype'] = 'none'
def plot_colormap_from_csv(csv_path, column_name, colormap_name='PiYG_r'):
    # Load the CSV file into a pandas DataFrame
    df = pd.read_csv(csv_path)

    # Ensure the column exists in the DataFrame
    if column_name not in df.columns:
        print(f"Available columns: {df.columns}")
        raise ValueError(f"Column '{column_name}' does not exist in the DataFrame")

    # Drop rows with NaN values in the specified column
    df = df.dropna(subset=[column_name])

    # Extract the values from the specified column and ensure they are float
    values = df[column_name].astype(float).values

    # Ensure the colormap exists
    colormap = plt.get_cmap(colormap_name)  # Get colormap

    # Use TwoSlopeNorm to set the colormap scaling from -1 to 1, with 0 as the center
    norm = TwoSlopeNorm(vmin=-1, vcenter=0, vmax=1)

    # Normalize the values and apply colormap
    normalized_values = norm(values)
    rgba_values = colormap(normalized_values)

    # Print corresponding RGB values
    for i, rgba in enumerate(rgba_values):
        rgb = (rgba[:3] * 255).astype(int)  # Convert to RGB
        print(f"Value: {values[i]:.3f}, RGB: {rgb}")

    # Create a figure to plot the colormap
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(10, 4), gridspec_kw={'height_ratios': [1, 0.05]})

    # Plot the colormap
    ax1.imshow([rgba_values], aspect='auto')

    # Add the titles (conditions) from the index or another meaningful column if needed
    conditions = df.index.values
    ax1.set_xticks(np.arange(len(conditions)))
    ax1.set_xticklabels(conditions, rotation=45, ha='right', fontsize=10)

    # Hide the y-axis
    ax1.yaxis.set_visible(False)

    # Add title to the figure
    ax1.set_title(f'Colormap based on {column_name} with {colormap_name} colormap', fontsize=12)

    # Create a colorbar
    sm = plt.cm.ScalarMappable(cmap=colormap_name, norm=norm)
    sm.set_array([])

    # Add colorbar to the second subplot
    cbar = fig.colorbar(sm, cax=ax2, orientation='horizontal')
    cbar.set_label(column_name, fontsize=20)

    # Display the colormap
    plt.tight_layout()
    plt.show()
    plt.savefig(r"C:\Users\Jalaja Madhusudhanan\Desktop\colorbar.svg", format="svg")
# Example usage
csv_path = r"C:\Users\Jalaja Madhusudhanan\Desktop\server data\colormap_for_network.csv"
column_name = 'modulation_index'
colormap_name = 'PiYG_r'  # You can change this to any other diverging colormap
plot_colormap_from_csv(csv_path, column_name, colormap_name)

import pandas as pd
import matplotlib.pyplot as plt
import sys
import os


def plot_csv_data(csv_file):
    # Read the CSV data into a DataFrame
    df = pd.read_csv(csv_file, header=None, names=["Aggregate Count", "Computation"])

    # Sorting the DataFrame by 'Aggregate Count'
    df.sort_values(by="Aggregate Count", inplace=True)

    # Calculating a short-term moving average
    window_size = 50
    df["Moving Average"] = df["Computation"].rolling(window=window_size).mean()

    # Plotting the data
    plt.figure(figsize=(12, 8))
    plt.plot(
        df["Aggregate Count"],
        df["Computation"],
        linestyle="",
        marker="o",
        color="b",
        markersize=3,
        alpha=0.5,
    )
    plt.plot(
        df["Aggregate Count"],
        df["Moving Average"],
        linestyle="-",
        color="red",
        linewidth=2,
        label="Moving Average",
    )

    # Adding a line at y=max computation
    max_computation = df["Computation"].max()
    plt.axhline(
        y=max_computation,
        color="green",
        linestyle="--",
        label=f"Max Computation: {max_computation}",
    )

    plt.title(
        "Computation Used Per Batch (n=100) Insertion vs Aggregate Stored Instance Count"
    )
    plt.xlabel("Aggregate Stored Instance Count")
    plt.ylabel("Computation Used Per Batch (n=100)")
    plt.legend()
    plt.grid(True)

    # Save the plot as a PNG file
    output_filename = os.path.splitext(csv_file)[0] + ".png"
    plt.savefig(output_filename)
    print(f"Plot saved to {output_filename}")

    # plt.show()


# Check if the CSV file name is given as a command-line argument
if len(sys.argv) < 2:
    print("Usage: python plot_computation.py <csv_file>")
    sys.exit(1)

csv_file_path = sys.argv[1]
plot_csv_data(csv_file_path)

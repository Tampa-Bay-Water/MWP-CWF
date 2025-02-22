import os
import glob

def list_files_by_modification_date(directory="."):
    """Lists files in a directory sorted by modification date (oldest first).

    Args:
        directory (str, optional): The directory to list files from. Defaults to the current directory.
    """
    try:
        files = glob.glob(os.path.join(directory, "*"))
        files.sort(key=os.path.getmtime)
        return files
    except FileNotFoundError:
        print(f"Error: Directory '{directory}' not found.")
        return []
    except Exception as e:
        print(f"An error occurred: {e}")
        return []

# Example usage:
if __name__ == "__main__":
    files_sorted_by_date = list_files_by_modification_date()
    if files_sorted_by_date:
        print("Files sorted by modification date (oldest first):")
        for file_path in files_sorted_by_date:
            print(file_path)

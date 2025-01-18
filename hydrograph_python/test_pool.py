import multiprocessing

# Function with multiple arguments
def multiply_add(x, y, z):
    return x * y + z

if __name__ == "__main__":
    # Data as tuples for multiple arguments
    data = [(1, 2, 3), (4, 5, 6), (7, 8, 9), (10, 11, 12)]

    # Create a pool of workers
    with multiprocessing.Pool(processes=4) as pool:
        # Use starmap to unpack arguments from the tuples
        results = pool.starmap(multiply_add, data)

    print(f"Results: {results}")
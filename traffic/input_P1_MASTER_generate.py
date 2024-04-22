import random

# Entry parameters
SEED = 123  # Seed for random number generation
NUM_LINES = 1000  # Number of traffic lines to generate

def generate_traffic(seed, num_lines):
    random.seed(seed)
    traffic_lines = []
    for _ in range(num_lines):
        binary_traffic = ''.join(str(random.randint(0, 1)) for _ in range(32))
        traffic_lines.append(binary_traffic)
    return traffic_lines

def write_to_file(traffic_lines):
    with open("input_P1_MASTER_traffic.txt", "w") as f:
        for line in traffic_lines:
            f.write(line + '\n')

def main():
    traffic_lines = generate_traffic(SEED, NUM_LINES)
    write_to_file(traffic_lines)
    print(f"Traffic has been generated and written to 'input_P1_MASTER_traffic.txt'.")

if __name__ == "__main__":
    main()

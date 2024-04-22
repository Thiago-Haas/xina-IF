#signal header_dest_w : std_logic_vector(data_width_p downto 0) := "1" & "0000000000000000" & "0000000000000000";
#signal header_src_w : std_logic_vector(data_width_p downto 0)  := "0" & "0000000000000001" & "0000000000000000";
#signal header_interface_w : std_logic_vector(data_width_p downto 0) := "0" & "000000000000" & id_w & len_w & burst_w & status_w & opc_w & type_w;
#constant id_w: std_logic_vector(4 downto 0) := "00001";
#constant len_w: std_logic_vector(7 downto 0) := "00000001";
#constant burst_w: std_logic_vector(1 downto 0) := "01";
#constant status_w: std_logic_vector(2 downto 0) := "010";
#constant opc_w: std_logic := '1';
#constant type_w: std_logic := '1';
#signal payload1_w: std_logic_vector(data_width_p downto 0) := "0" & "1010101010101010" & "1010101010101010";
#signal trailer_w : std_logic_vector(data_width_p downto 0) := "1" & "1000100010001010" & "0000100100110010";
#signal address_w : std_logic_vector(data_width_p downto 0) := "0" & "1101110111011101" & "1101110111011101";
#signal data_out_w: std_logic_vector(data_width_p downto 0);
# Entry parameters
import random
SEED = 7572865  # Seed for random number generation
NUM_LINES = 1000  # Number of traffic lines to generate

def generate_traffic(seed, num_lines):
    random.seed(seed)
    traffic_lines = []
    for _ in range(num_lines):
        binary_traffic = ''.join(str(random.randint(0, 1)) for _ in range(32))
        traffic_lines.append(binary_traffic)
    return traffic_lines

def write_to_file(traffic_lines):
    with open("input_P3_MASTER_traffic.txt", "w") as f:
        for line in traffic_lines:
            #f.write("1"+"00000000000000000000000000000000" + '\n')#header_dest_w
            #f.write("0"+"00000000000000010000000000000000" + '\n')#header_src_w
            #f.write("0"+"000000000000"+"00001"+"00000001"+"01"+"010"+"1"+"1" + '\n')#header_interface_w "0" "000000000000" & id_w & len_w & burst_w & status_w & opc_w & type_w;
            #f.write("0"+ "1111111111111111" + "1111111111111111" + '\n')
            f.write("0" + line + '\n')#paload
            #f.write("1"+"00000000000000000000000000000000" + '\n')#trailer_w

def main():
    traffic_lines = generate_traffic(SEED, NUM_LINES)
    write_to_file(traffic_lines)
    print(f"Traffic has been generated and written to 'input_P3_MASTER_traffic.txt'.")

if __name__ == "__main__":
    main()

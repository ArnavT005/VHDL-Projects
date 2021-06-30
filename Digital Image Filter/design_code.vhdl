-- VHDL FILE (Assignment-3) --

-- VHDL Code (RAM) (Directly copied from appendix) --

library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity RAM_64Kx8 is
port (
    clock : in std_logic;
    read_enable, write_enable : in std_logic; -- signals that enable read/write operation
    address : in std_logic_vector(15 downto 0); -- 2^16 = 64K
    data_in : in std_logic_vector(7 downto 0);
    data_out : out std_logic_vector(7 downto 0)
);
end RAM_64Kx8;

architecture Artix of RAM_64Kx8 is
type Memory_type is array (0 to 65535) of std_logic_vector (7 downto 0);
signal Memory_array : Memory_type;
begin
    process (clock) begin
        if rising_edge (clock) then
            if (read_enable = '1') then -- the data read is available after the clock edge
                data_out <= Memory_array (to_integer (unsigned (address)));
            end if;
            if (write_enable = '1') then -- the data is written on the clock edge
                Memory_array (to_integer (unsigned(address))) <= data_in;
            end if;
        end if;
    end process;
end Artix;

-- End RAM --


-- VHDL Code (ROM) (directly copied from appendix) --

library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ROM_32x9 is
port (
    clock : in std_logic;
    read_enable : in std_logic; -- signal that enables read operation
    address : in std_logic_vector(4 downto 0); -- 2^5 = 32
    data_out : out std_logic_vector(8 downto 0)
);
end ROM_32x9;
    
architecture Artix of ROM_32x9 is
type Memory_type is array (0 to 31) of std_logic_vector (8 downto 0);
signal Memory_array : Memory_type;
begin
    process (clock) begin
        if rising_edge (clock) then
            if (read_enable = '1') then -- the data read is available after the clock edge
                data_out <= Memory_array (to_integer (unsigned (address)));
            end if;
        end if;
    end process;
end Artix;

-- End ROM --


-- VHDL Code (Multiplier-Accumulator) (directly copied from appendix) --

library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity MAC is
port (
    clock : in std_logic;
    control : in std_logic; -- ‘0’ for initializing the sum
    data_in1, data_in2 : in std_logic_vector(17 downto 0);
    data_out : out std_logic_vector(17 downto 0)
);
end MAC;

architecture Artix of MAC is
signal sum, product : signed (17 downto 0);
begin
    data_out <= std_logic_vector (sum);
    product <= signed (data_in1) * signed (data_in2);
    process (clock) begin
        if rising_edge (clock) then -- sum is available after clock edge
            if (control = '0') then -- initialize the sum with the first product
                sum <= (product);
            else -- add product to the previous sum
                sum <= (product + signed (sum));
            end if;
        end if;
    end process;
end Artix; 

-- End MAC --   


-- VHDL Code (Main Entity: Filter) (My circuit design) --

library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Entity Filter:

entity Filter is
port(
    clk: in std_logic; 
    -- input clock
    pb: in bit; 
    -- input push button signal. pb = '1' denotes start of filtering operation
    switch: in bit; 
    -- input switch signal. switch = '0' denotes smoothening and switch = '1' denotes sharpening
    reset: in bit; 
    -- reset input. reset = '1' sets state to idle (stop filtering operation)
    done: out bit 
    -- done output. done = '1' denotes that the filtering operation is complete
);
end Filter;


-- Architecture Image_Filter: (of Filter)

architecture Image_Filter of Filter is
-- QQVGA images are of dimension 120x160 (120 px height, 160 px wide)
-- so image X is a matrix of order 120 x 160, and filtered image Y is matrix of order 118 x 158
-- coeficient matrix, C, is of order 3 x 3  

-- Component Declaration begins --

-- RAM Component

component RAM_64Kx8
port (
    clock : in std_logic;
    read_enable, write_enable : in std_logic; -- signals that enable read/write operation
    address : in std_logic_vector(15 downto 0); -- 2^16 = 64K
    data_in : in std_logic_vector(7 downto 0);
    data_out : out std_logic_vector(7 downto 0)
);
end component;

-- ROM Component

component ROM_32x9
port (
    clock : in std_logic;
    read_enable : in std_logic; -- signal that enables read operation
    address : in std_logic_vector(4 downto 0); -- 2^5 = 32
    data_out : out std_logic_vector(8 downto 0)
);
end component;

-- Multiplier-Accumulator Component

component MAC
port (
    clock : in std_logic;
    control : in std_logic; -- ‘0’ for initializing the sum
    data_in1, data_in2 : in std_logic_vector(17 downto 0);
    data_out : out std_logic_vector(17 downto 0)
);
end component;

-- Component Declaration ends --

-- State type declaration (States actions can be seen in ASM chart) --
type state_type is (Idle, Smooth, Sharp, Smooth_Active, Sharp_Active, Smooth_Mult, Sharp_Mult, Smooth_Addr, Sharp_Addr, Read_M, Load_M, Mult, Write_M, wait_state);

-- Signal Declaration begins --

signal state: state_type := Idle;
-- state signal, initialised with Idle state (starting state)

signal I: unsigned(7 downto 0);
signal J: unsigned(7 downto 0);
-- matrix indices used in computation of filter image Y[I, J]; I is the row index and J is the column index; 1 <= I <= 118, 1 <= J <= 158

signal i: unsigned(7 downto 0);
signal j: unsigned(7 downto 0);
-- iterator indices used in carrying out sum of products, i.e. multiplying an image element with a coefficient element one-by-one, 0 <= i, j <= 2

signal cJ: bit;
-- this signals denotes the boolean condition "J = 159". cJ = 1 when J = 159, and is 0 otherwise

signal cI: bit;
-- this signal denotes the boolean condition "I = 118". cI = 1 when I = 118, and is 0 otherwise

signal cj: bit;
-- this signal denotes the boolean condition "j = 3". cj = 1 when j = 3 and is 0 otherwise

signal ci: bit;
-- this signal denotes the boolean condition "i = 2". ci = 1 when i = 2 and is 0 otherwise

signal addr_I: std_logic_vector(15 downto 0);
-- this signal denotes the memory address from which image element has to be read from RAM component used in the architecture

signal addr_C: std_logic_vector(4 downto 0);
-- this signal denotes the memory address from which coefficient element has to be read from the ROM component used in the architecture

signal Y: std_logic_vector(7 downto 0);
-- this signal denotes the filtered image element (used as 8 bit unsigned pixel) which is to be written into RAM component

signal X: std_logic_vector(7 downto 0);
-- this signal denotes the image element (used as 8 bit unsigned pixel) which is read from the RAM component

signal C: std_logic_vector(8 downto 0);
-- this signal denotes the coefficient element (used as 9 bit signed number) which is read from the ROM component

signal X_mult: std_logic_vector(17 downto 0);
-- this signal is the resized version of X (used as 18 bit signed)

signal C_mult: std_logic_vector(17 downto 0);
-- this signal is the resized version of C (used as 18 bit signed)

signal Y_mult: std_logic_vector(17 downto 0);
-- this signal is the accumulated output of the multiplier (used as 18 bit signed)

signal control: std_logic;
-- this signal is used to initialize the multiplier-accumulator (0 is used to initialize)

signal Load_I, Load_J, Load_j, Load_i, Load_c: std_logic;
-- these load signals are used to initialize or load the values of I, J, j, i and control respectively (values 1, 1, 0 and 0 respectively)

signal Read_X, Read_C: std_logic;
-- these signals denote if the image/coefficient is to be read from the RAM/ROM or not (basically read_enable input of RAM/ROM component)

signal Write_Y: std_logic;
-- this signal denotes if the filtered image is to be written into the RAM or not (basically write_enable input of RAM component)

signal Incr_I, Incr_J, Incr_i, Incr_j: std_logic;
-- these signals are used to increment the values of I, J, i and j by 1 respectively

signal Reset_done, Set_done: std_logic;
-- these signals are used to set (done <= 1) and reset (done <= 0) the done signal

signal Set_addrX, Set_addrC_smooth, Set_addrC_sharp: std_logic;
-- these signals are used to set the memory address from which the value of image/coefficient element has to be read from RAM/ROM

signal Set_addrY: std_logic;
-- this signal is used to set the memory address into which the filtered element value has to be written in RAM

signal Set_c: std_logic;
-- this signal is used to set the control value to '1' after it has initialized the multiplier-accumulator with the first product

signal Set_X_mult, Set_C_mult: std_logic;
-- these signals are used to load the values X and C (read from RAM and ROM) into signals X_mult and C_mult after proper resizing so that these can be passed onto MAC

signal Reset_X_mult, Reset_C_mult: std_logic;
-- these signals are used to set the values of X_mult and C_mult, so that no unnecessary accumulation takes place in the MAC when not desired (till next data is read)

signal Feed_Y: std_logic;
-- this signal is used to feed the final multiplier-accumulator output (Y_mult) into Y signal after proper resizing/adjustments, so that it can be written into RAM

-- Signal Declaration ends --

begin

    cJ <= '1' when J = "10011111" else '0';
    -- generating cJ signal from the condition "J = 159"

    cI <= '1' when I = "01110110" else '0';
    -- generating cI signal from the condition "I = 118"

    cj <= '1' when j = "00000011" else '0';
    -- generating cj signal from the condition "j = 3"

    ci <= '1' when i = "00000010" else '0';
    -- generating ci signal from the condition "i = 2"
    
    -- Component Instantiation: RAM
    -- appropriate signals have been used, as per the descriptions given above
    Read_Write_Image: RAM_64Kx8 port map(clock => clk, read_enable => Read_X, write_enable => Write_Y, address => addr_I, data_in => Y, data_out => X);
    
    -- Component Instantiation: ROM
    -- appropriate signals have been used, as per the description given above
    Read_Coefficients: ROM_32x9 port map(clock => clk, read_enable => Read_C, address => addr_C, data_out => C);
    
    -- Component Instantiation: Multiplier-Accumulator (MAC)
    -- appropriate signals have been used, as per the description given above. control = 0 is used to denote initialization of Y_mult with the product X_mult*C_mult
    Multiply: MAC port map(clock => clk, control => control, data_in1 => X_mult, data_in2 => C_mult, data_out => Y_mult);

    -- process sensitive to clock (and reset), it is used to trigger state transitions
    state_transition: process(clk, reset)
    begin
        -- if reset = 1, then change state to Idle (stop filtering)
        if(reset = '1') then state <= Idle;
        -- else, trigger on rising edge
        elsif(rising_edge(clk)) then
            -- change state appropriately (as in ASM chart)
            -- switch, pb, cJ, cI, cj and ci basically represent diamond boxes in the chart
            -- state change action is done according to their value in a single assignment
            case state is
                
                when Idle => 
                        if(switch = '0') then state <= Smooth;
                        else state <= Sharp;
                        end if;
                
                when Smooth =>
                        if(pb = '1') then 
                            state <= Smooth_Active;
                        else
                            state <= Smooth;    
                        end if; 
                
                when Smooth_Active => 
                        if(cJ = '1') then 
                            if(cI = '1') then
                                state <= wait_state;
                            else
                                state <= Smooth_Mult;
                            end if;
                        else
                            state <= Smooth_Mult;
                        end if;
                
                when Smooth_Mult =>
                        if(cj = '1') then
                            if(ci = '1') then
                                state <= Write_M;
                            else 
                                state <= Smooth_Addr;
                            end if;
                        else
                            state <= Smooth_Addr;        
                        end if;
                
                when Smooth_Addr =>
                        state <= Read_M;
                
                when Sharp => 
                        if(pb = '1') then 
                            state <= Sharp_Active;
                        else
                            state <= Sharp;    
                        end if;
                
                when Sharp_Active =>
                        if(cJ = '1') then
                            if(cI = '1') then
                                state <= wait_state;
                            else
                                state <= Sharp_Mult;
                            end if;
                        else
                            state <= Sharp_Mult;
                        end if;
                
                when Sharp_Mult =>
                        if(cj = '1') then
                            if(ci = '1') then
                                state <= Write_M;
                            else
                                state <= Sharp_Addr;    
                            end if;
                        else
                            state <= Sharp_Addr;    
                        end if;
                
                when Sharp_Addr =>
                        state <= Read_M;
                
                when Write_M =>
                        if(switch = '0') then state <= Smooth_Active;
                        else state <= Sharp_Active;
                        end if;
                
                when Read_M =>
                        state <= Load_M;
                      
                when Load_M =>
                        state <= Mult;
                 
                when Mult =>
                        if(switch = '0') then state <= Smooth_Mult;
                        else state <= Sharp_Mult;
                        end if;
                   
                when wait_state =>
                        if(pb = '1') then state <= wait_state;
                        else state <= Idle;
                        end if;

            end case;
            -- all state transitions complete
        end if; 
    end process;
    
    -- process sensitive to state, pb, cJ, cI, cj and ci. This is used to generate appropriate signals which are used in working around with the data
    -- This process acts like a controller (generates different data-control signals)
    control_path: process(state, pb, cJ, cI, cj, ci)
    begin
        -- initialize all the signals with 0 to begin with. They will be set to '1' based on the state and conditional signals (pb, cJ, cI, cj, ci)
        Load_I <= '0'; Load_J <= '0'; Load_j <= '0'; Load_i <= '0'; 
        Load_c <= '0'; Set_c <= '0'; Reset_done <= '0'; Set_done <= '0';
        Read_X <= '0'; Read_C <= '0'; Write_Y <= '0'; Feed_Y <= '0'; 
        Incr_I <= '0'; Incr_J <= '0'; Incr_i <= '0'; Incr_j <= '0'; 
        Set_X_mult <= '0'; Set_C_mult <= '0'; Reset_X_mult <= '1'; Reset_C_mult <= '1';
        Set_addrX <= '0'; Set_addrC_smooth <= '0'; Set_addrC_sharp <= '0'; Set_addrY <= '0';

        -- set the signals to '1' appropriately (based on ASM chart)
        case state is
            
            when Idle => 
                Reset_done <= '1';
            
            when Smooth =>
                if(pb = '1') then
                    Load_I <= '1';
                    Load_J <= '1';
                end if;
            
            when Smooth_Active =>
                if(cJ = '1') then
                    if(cI = '0') then 
                        Load_J <= '1';
                        Incr_I <= '1';
                        Load_c <= '1';
                        Load_i <= '1';
                        Load_j <= '1';   
                    end if;
                else
                    Load_c <= '1';
                    Load_i <= '1';
                    Load_j <= '1';
                end if;
            
            when Smooth_Mult =>
                if(cj = '1') then
                    if(ci = '1') then
                        Set_addrY <= '1';
                        Feed_Y <= '1';
                    else
                        Load_j <= '1';
                        Incr_i <= '1';
                    end if;                        
                end if;
            
            when Smooth_Addr =>
                Set_addrX <= '1';
                Set_addrC_smooth <= '1';
            
            when Sharp =>
                if(pb = '1') then
                    Load_I <= '1';
                    Load_J <= '1';
                end if;
            
            when Sharp_Active =>
                if(cJ = '1') then
                    if(cI = '0') then 
                        Load_J <= '1';
                        Incr_I <= '1';
                        Load_c <= '1';
                        Load_i <= '1';
                        Load_j <= '1';   
                    end if;
                else
                    Load_c <= '1';
                    Load_i <= '1';
                    Load_j <= '1';
                end if;
            
            when Sharp_Mult =>
                if(cj = '1') then
                    if(ci = '1') then
                        Set_addrY <= '1';
                        Feed_Y <= '1';
                    else
                        Load_j <= '1';
                        Incr_i <= '1';
                    end if;                       
                end if;  
            
            when Sharp_Addr =>
                Set_addrX <= '1';
                Set_addrC_sharp <= '1';

            when Read_M =>
                Read_X <= '1';
                Read_C <= '1';
            
            when Load_M =>
                Set_X_mult <= '1';
                Set_C_mult <= '1';
            
            when Write_M =>
                Write_Y <= '1';
                Incr_J <= '1';
            
            when Mult =>
                Reset_X_mult <= '1';
                Reset_C_mult <= '1';
                Set_c <= '1';
                Incr_j <= '1';
            
            when wait_state =>
                Set_done <= '1';

        end case;
        -- all control signal assignments complete
    end process;
 
    -- process sensitive to clock. This is used to manipulate/assign/use data as per the control signals every clock cycle
    data_path: process(clk)
    begin
        -- check for positive edge of clock
        if(rising_edge(clk)) then
            -- All changes done according to control signals which are in accordance with moore and mealey changes in the ASM chart

            -- setting value of 'done'
            if(Reset_done = '1') then done <= '0'; -- done = 0
            elsif(Set_done = '1') then done <= '1'; -- done = 1
            end if;
            
            -- setting value of 'I'
            if(Load_I = '1') then I <= "00000001"; -- I = 1
            elsif(Incr_I = '1') then I <= I + 1; -- increment by 1
            end if;

            -- setting value of 'J'
            if(Load_J = '1') then J <= "00000001"; -- J = 1
            elsif(Incr_J = '1') then J <= J + 1; -- increment by 1
            end if;

            -- setting value of 'j'
            if(Load_j = '1') then j <= "00000000"; -- j = 0
            elsif(Incr_j = '1') then j <= j + 1; -- increment by 1
            end if;

            -- setting value of 'i'
            if(Load_i = '1') then i <= "00000000"; -- i = 0
            elsif(Incr_i = '1') then i <= i + 1; -- increment by 1
            end if;

            -- setting value of 'control'
            if(Load_c = '1') then control <= '0'; -- control = 0
            elsif(Set_c = '1') then control <= '1'; -- control = 1
            end if;

            -- setting value of 'Y' which is to be written into RAM
            if(Feed_Y = '1') then
                -- if Y_mult is negative (sign bit = '1'), then store zero (as specified in the problem)
                if(Y_mult(17) = '1') then Y <= "00000000";
                -- else right-shift Y_mult (18 bit) by 7 bits and store it into 'Y' after appropriate resizing (8 bit) 
                -- cast it into std_logic_vector for compatibility
                else Y <= std_logic_vector(resize(unsigned(Y_mult(17 downto 7)), 8)); -- Y_mult(17 downto 7) slices the vector and discards the right-most 7 bits (hence, a right-shift)
                end if;
            end if;    
            
            -- setting address from which X is to be read, or where Y is to be written in RAM
            if(Set_addrX = '1') then addr_I <= std_logic_vector(resize(unsigned(I + i - 1) * 160, 16) + resize(unsigned(J + j - 1), 16));  -- unsigned arithmetic is performed to calculate memory address (row major, starting from 0)
            elsif(Set_addrY = '1') then addr_I <= std_logic_vector(x"8000" + resize(unsigned(I - 1) * 158, 16) + resize(unsigned(J - 1), 16)); -- unsigned arithmetic is performed to calculate memory address (row major, starting from 32768 (8000 in hexadecimal))
            end if;

            -- setting address from which C is to be read from ROM (depends on if we are reading sharpening filter or smoothening filter)
            if(Set_addrC_smooth = '1') then addr_C <= std_logic_vector(resize(unsigned(i) * 3, 5) + resize(j, 5)); -- smoothening coefficients are stored from 0 onwards (row major)
            elsif(Set_addrC_sharp = '1') then addr_C <= std_logic_vector("10000" + resize(unsigned(i) * 3, 5) + resize(j, 5)); -- sharpening coefficients are stored from 16 onwards ("10000" in binary)
            end if;
            
            -- setting value of X_mult after appropriate resizing (8 to 18 bit)
            if(Set_X_mult = '1') then X_mult <= std_logic_vector(resize(unsigned(X), 18)); -- X_mult will be used by multiplier-accumulator (X represents unsigned number, hence unsigned is used)
            elsif(Reset_X_mult = '1') then X_mult <= "000000000000000000"; -- X_mult is made zero so that the product (X_mult*C_mult) doesn't get accumulated into Y_mult when not required (till next cycle)
            end if;

            -- setting value of C_mult after appropriate resizing (9 bit to 18 bit)
            if(Set_C_mult = '1') then C_mult <= std_logic_vector(resize(signed(C), 18)); -- C_mult will be used by MAC (C represents a signed number, hence signed is used)
            elsif(Reset_C_mult = '1') then C_mult <= "000000000000000000"; -- C_mult is made zero so that the product (X_mult*C_mult) doesn't get accumulated into Y_mult when not required (till next cycle)
            end if;

        end if;
        -- all data assignments done
    end process; 
    -- process ends
    -- filtering is carried out, and done = '1' will denote completion
end Image_Filter;           
                                                  
-- Architecture ends--
-- End Filter --

-- VHDL Code ends --

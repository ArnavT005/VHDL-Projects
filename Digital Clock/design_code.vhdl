-- VHDL code begins


-- Component clock starts

-- using standard libraries for unsigned type and conflict resolution
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


-- main entity: The Digital Clock
entity clock is
port (
    clk: in bit;
    -- input clock 10 MHz
    pb1: in bit;
    -- next mode button
    pb2: in bit;
    -- previous mode button
    pb3: in bit;
    -- increment time (slow/fast)
    pb4: in bit;
    -- decrement time (slow/fast)
    anode: out unsigned(3 downto 0);
    -- anode(3) represents the leftmost display board and anode(0) represents the right most display board.
    cathode: out unsigned(6 downto 0)
    -- cathode(6) is for the A segment and cathode(0) is for G segment (the order is A(6), B(5), C(4), D(3), E(2), F(1) and G(0))
    );
end clock;  


-- architecture of the digital clock
architecture digitalClock of clock is


--component declaration begins

-- "stepDown" Component is defined later, and is used to produce 250 Hz clock from 10 MHz input clock
component stepDown
port (
    sysClock: in bit;
    downClock: out bit
    );
end component;

-- "convert" Component is defined later, and is used to produce the cathode signals (7 bit) of 7-segment display from the binary representation of the number/symbol (4 bit)
component convert
port (
    bin4: in unsigned(3 downto 0);
    bin7: out unsigned(6 downto 0)
    );
end component;    

-- component declaration ends


-- type declaration begins

type digitState is (d3, d2, d1, d0);
-- determines which 7-segment board is going be active out of 4 7-segment display boards (d3, d2, d1 and d0 represent boards from left to right in order)


type mode is (hourMin, minSec, hourSec, setH, setM, setS);
-- different display modes and time setting mode (HH:MM, MM:SS, HH:SS, Set:HH, Set:MM, Set:SS, in order)


type buttonPress is (off, On1, pressed, invalid);
-- different states of the push buttons
-- off and On1 have usual meaning corresponding to low and high signals respectively. "pressed" and "invalid" are explained below:
-- when a button is held on for 0.5 s, it goes in the "pressed" state. This state is only used for pb3 and pb4 which are responsible for incrementing/decrementing count.
-- pb1 and pb2 still remain in On1 state even if they are held on for 0.5 s.
-- when two or more buttons are pressed at a time, all buttons go to the "invalid" state, and no changes take place (mode change, increment/decrement etc.)

-- type declaration ends


-- signal declaration begins

signal digitDisplay: digitState := d0;
-- rightmost seven-segment board will be active initially


signal displayMode: mode := hourMin;
-- default display mode is hour:min (HH:MM)


signal button1: buttonPress := invalid;
signal button2: buttonPress := invalid;
signal button3: buttonPress := invalid;
signal button4: buttonPress := invalid;
-- these signals represent state of the buttons (pb1, pb2, pb3 and pb4)
-- all the button are in invalid state by default, so that a button press from before is not treated as a valid input.

-- msd stands for Most Significant Digit and lsd stands for Least Significant Digit in the comments below 

signal hour1: unsigned(3 downto 0) := "0000";
-- msd of hours, can be 0, 1 or 2 (initialised with a 0)

signal hour0: unsigned(3 downto 0) := "0000";
-- lsd of hours, can be 0, 1, 2, 3, 4, 5, 6, 7, 8 or 9 (initialised with a 0)

signal min1: unsigned(3 downto 0) := "0000";
-- msd of minutes, can be 0, 1, 2, 3, 4 or 5 (initialised with a 0)

signal min0: unsigned(3 downto 0) := "0000";
-- lsd of minutes, can be 0, 1, 2, 3, 4, 5, 6, 7, 8 or 9 (initialised with a 0)

signal sec1: unsigned(3 downto 0) := "0000";
-- msd of seconds, can be 0, 1, 2, 3, 4 or 5 (initialiased with a 0)

signal sec0: unsigned(3 downto 0) := "0000";
--lsd of seconds, can be 0, 1, 2, 3, 4, 5, 6, 7, 8 or 9 (initialiased with a 0)


signal digit3: unsigned(3 downto 0) := "0000";
signal digit2: unsigned(3 downto 0) := "0000";
signal digit1: unsigned(3 downto 0) := "0000";
signal digit0: unsigned(3 downto 0) := "0000";
-- the four symbols to be displayed on the 7-segment display board (from left to right) (initially they will be displaying the digit "0" which corresponds to binary code "0000")


signal c3: unsigned(6 downto 0) := "0000001";
signal c2: unsigned(6 downto 0) := "0000001";
signal c1: unsigned(6 downto 0) := "0000001";
signal c0: unsigned(6 downto 0) := "0000001";
-- corresponding cathode signal for the 4 symbols, from A to G respectively (0 means on and 1 means off) (initially all the boards will be displaying 0, so only G must be high)
-- a segment on the 7-segment is displayed only when the anode signal is high and the cathode signal is low (0, forward biased), and off when cathode signal is high (1, reverse biased)


signal masterClock: bit;
-- master clock (250 Hz) derived from 10 MHz clock (using component "stepDown")
-- 250 Hz is required for displaying symbols on the 4 7-segment display boards with a digit period of 4 ms (and refresh period of 16 ms)
-- i.e. anode/cathode signal is updated every 4 ms


signal counter1Hz: unsigned(7 downto 0) := "00000000";
-- modulo-250 up-counter to produce a frequency of 1 Hz from master clock (used to update time after every second)


signal counter5Hz: unsigned(5 downto 0) := "000000";
-- modulo-50 up-counter to produce a frequency of 5 Hz from master clock (used in fast increment/decrement, number is updated every 0.2 s)


signal counterPress: unsigned(6 downto 0) := "0000000";
-- saturating-125 up-counter ("button3" and "button4" change from "On1" to "pressed" after saturation (0.5 s or 500 ms))

-- signal declaration ends


-- architecture begins

begin

    
    -- create master clock of frequency 250 Hz from 10 MHz	
    master_clock_creation: stepDown port map(sysClock => clk, downClock => masterClock);
    

    -- convert the symbols (4 bit_vector) into their corresponding cathode signals (7 bit_vector)
    cathode_symbol0: convert port map(bin4 => digit0, bin7 => c0); -- conversion for digit0 done, and stored in c0
    cathode_symbol1: convert port map(bin4 => digit1, bin7 => c1); -- conversion for digit1 done, and stored in c1
    cathode_symbol2: convert port map(bin4 => digit2, bin7 => c2); -- conversion for digit2 done, and stored in c2
    cathode_symbol3: convert port map(bin4 => digit3, bin7 => c3); -- conversion for digit3 done, and stored in c3


    -- assign anode signals based on which board is going to be activated (1 represents active, 0 represents off)
    with digitDisplay select
    anode <= "0001" when d0,
    	     "0010" when d1,
             "0100" when d2,
             "1000" when d3;
  

    -- assign cathode signals based on which board is going to be activated (c3 is leftmost and c0 is the rightmost)   
    with digitDisplay select
    cathode <= c0 when d0,
    	       c1 when d1,
               c2 when d2,
               c3 when d3;


    -- process declaration (for switching display board @ 250 Hz, updating time @ 1 Hz, fast increment/decrement @ 5 Hz)
    process(masterClock) -- sensitivity list
    begin
        -- check for rising edge of the clock (synchronous)
    	if(rising_edge(masterClock)) then
            
            -- switch display board (done every clock cycle, i.e. 250 times a second)
            case digitDisplay is
            	when d0 => digitDisplay <= d1;
                when d1 => digitDisplay <= d2;
                when d2 => digitDisplay <= d3;
                when d3 => digitDisplay <= d0; -- cyclic fashion as described in the pdf
            end case;

            -- check buttons
            -- a single button press is detected when state of a button changes from "On1" to "off"
            -- an invariant that will be maintained over the cycles is that either all buttons are off, a single button is On1/pressed (rest off)
            -- or all buttons are "invalid" (this invariant is explained in more detail in the pdf)
            if(pb1 = '0' and pb2 = '0' and pb3 = '0' and pb4 = '0') then
                -- all the buttons are low in this clock cycle
                
                -- check if some button was On1 in previous clock cycle
                if(button1 = On1) then
                    -- move to next display mode and change button1 state, rest of the buttons will remain in their "off" state as before.
                    button1 <= off; -- button1 state changed
                    -- change displayMode state in a cyclic manner
                    case displayMode is
                    	when hourMin => displayMode <= minSec;
                        when minSec => displayMode <= hourSec;
                        when hourSec => displayMode <= setH;
                        when setH => displayMode <= setM;
                        when setM => displayMode <= setS;
                        when setS => displayMode <= hourMin;
                    end case;
                    -- button1 changes ends    
                
                elsif(button2 = On1) then
                    -- move to previous display mode and change button2 state, rest of the buttons will remain in their "off" state as before.
                    button2 <= off; -- button2 state changed
                    -- change display mode in a reverse cyclic manner
                    case displayMode is
                    	when hourMin => displayMode <= setS;
                        when minSec => displayMode <= hourMin;
                        when hourSec => displayMode <= minSec;
                        when setH => displayMode <= hourSec;
                        when setM => displayMode <= setH;
                        when setS => displayMode <= setM;
                    end case;
                    -- button2 changes ends
                
                -- button3 and button4 are for increment/decrement respectively, but these only occur in set states: setH, setM or setS
                -- otherwise no change    
                elsif(button3 = On1) then 
                    -- button3 /= pressed, so only a single press (increment by 1)
                    -- when in set display mode, increment time by 1
                    -- also change button3 state to "off", rest of the buttons will remain in their "off" state as before.
                    button3 <= off;
                    if(displayMode = setH) then
                        -- increment the hour count by 1
                        if(hour0 = "1001") then 
                            -- hour0 is already 9, so make it 0
                            hour0 <= "0000";
                            -- check if hour1 was 2, in that case make that 0 too, otherwise just increment it by 1
                            if(hour1 = "0010") then hour1 <= "0000";
                            else hour1 <= hour1 + 1;
                            end if;
                        elsif(hour0 ="0011" and hour1 = "0010") then
                            -- Since hour can vary from 00 to 23, increment it and make it 00
                            hour0 <= "0000"; -- hour0 = 0
                            hour1 <= "0000"; -- hour1 = 0
                        -- hour0 is not 9, and neither is hour = 23, so simply add 1 to hour0
                        else hour0 <= hour0 + 1;
                        end if;
                        -- hour count incremented by 1

                   	elsif(displayMode = setM) then 
                        -- increment minute count by 1
                        if(min0 = "1001") then
                            -- min0 is already 9, so make it 0
                            min0 <= "0000";
                            -- check if min1 was 5, in that case make it 0 too, otherwise just increment it by 1
                            if(min1 = "0101") then min1 <= "0000";
                            else min1 <= min1 + 1;
                            end if;
                        -- min0 was not 9, so simply add 1 to min0   
                        else min0 <= min0 + 1;
                        end if;
                        -- minute count incremented by 1

                    elsif(displayMode = setS) then
                        -- increment second count by 1
                        if(sec0 = "1001") then
                            -- sec0 is already 9, so make it 0
                            sec0 <= "0000";
                            -- check if sec1 was 5, in that case make it 0 too, otherwise just increment it by 1
                            if(sec1 = "0101") then sec1 <= "0000";
                            else sec1 <= sec1 + 1;
                            end if;
                        -- sec0 was not 9, so simply add 1 to sec0   
                        else sec0 <= sec0 + 1;
                        end if;
                        -- second count incremented by 1
                    
                    -- all set(static) display modes taken care of. There will be no change in any other display mode.    
                    end if;
                    
                elsif(button4 = On1) then
                 	-- button4 /= pressed, so only a single press (decrement by 1)
                    -- when in set display mode, decrement time by 1
                    -- also change button4 state to "off", rest of the buttons will remain in their "off" state as before.
                    button4 <= off;
                    if(displayMode = setH) then
                        -- decrement the hour count by 1
                        if(hour0 = "0000") then 
                            -- hour0 is already 0, so make it 9 only when hour1 is not 0, otherwise make it 3 (because hour ranges from 00 to 23)
                            -- check if hour1 was 0, in that case make it 2, otherwise just decrement it by 1
                            if(hour1 = "0000") then 
                                -- hour = 00, so make it 23
                                hour0 <= "0011"; -- hour0 = 3
                                hour1 <= "0010"; -- hour1 = 2
                            else 
                                -- hour1 is not 0, so simply decrement hour1 by 1 and make hour0 = 9
                                hour0 <= "1001"; -- hour0 = 9
                                hour1 <= hour1 - 1;
                            end if;
                        -- hour0 is not 0, so simply subtract 1 from hour0
                        else hour0 <= hour0 - 1;
                        end if;
                        -- hour count decremented by 1

                   	elsif(displayMode = setM) then 
                        -- decrement minute count by 1
                        if(min0 = "0000") then
                            -- min0 is already 0, so make it 9
                            min0 <= "1001";
                            -- check if min1 was 0, in that case make it 5, otherwise just decrement it by 1
                            if(min1 = "0000") then min1 <= "0101";
                            else min1 <= min1 - 1;
                            end if;
                        -- min0 was not 0, so simply subtract 1 from min0   
                        else min0 <= min0 - 1;
                        end if;
                        -- minute count decremented by 1

                    elsif(displayMode = setS) then
                        -- decrement second count by 1
                        if(sec0 = "0000") then
                            -- sec0 is already 0, so make it 9
                            sec0 <= "1001";
                            -- check if sec1 was 0, in that case make it 5, otherwise just decrement it by 1
                            if(sec1 = "0000") then sec1 <= "0101";
                            else sec1 <= sec1 - 1;
                            end if;
                        -- sec0 was not 0, so simply subtract 1 from sec0   
                        else sec0 <= sec0 - 1;
                        end if;
                        -- second count decremented by 1
                    
                    -- all set(static) display modes taken care of. There will be no change in any other display mode.    
                    end if;
                    
                else
                    -- in previous clock cycle, either all buttons were "off", or button3/button4 was "pressed", or all were "invalid"
                    -- in either case, no action is to be performed (because action due to "pressed" takes place till the button is pressed, unlike "On1" state)
                    -- also "invalid" to "off" transition does not produce any change.
                    -- since all inputs are '0', turn all buttons off 
                    button1 <= off;
                    button2 <= off;
                    button3 <= off;
                    button4 <= off;
                end if;
                
                -- reset saturating-125 up-counter counterPress to 0 (as no button is pressed)
                -- this counter counts up when pb3 or pb4 is high (1)
                counterPress <= "0000000";

            elsif(pb1 = '1' and pb2 = '0' and pb3 ='0' and pb4 ='0') then
                -- only pb1 signal is high
            	-- since time period of clock is 4 ms, it cannot be the case that a button was released and another button was pressed within 4 ms
                -- hence, it is safe to assume that in the previous clock cycle, either all buttons were off, or pb1 = '1' (others may or may not be 
                -- on)
                if(button1 = off) then
                    -- all buttons were off in the previous cycle, also all of them (apart from button 1) are off in this cycle as well
                    -- only change state of button1
                    -- as mode is changed when button1 changes from "On1" to "off".
                    button1 <= On1;

                -- else the state of button1 will not change, invalid => invalid (as pb1 is still 1) and On1 => On1 (no notion of "pressed" for button 1)
                end if;

                -- reset saturating-125 up-counter counterPress to 0 (as no button is pressed)
                -- this counter counts up when pb3 or pb4 is high (1)
                counterPress <= "0000000";

            elsif(pb1 = '0' and pb2 = '1' and pb3 ='0' and pb4 ='0') then
                -- only pb2 signal is high
            	-- since time period of clock is 4 ms, it cannot be the case that a button was released and another button was pressed within 4 ms
                -- hence, it is safe to assume that in the previous clock cycle, either all buttons were off, or pb2 = '1' (others may or may not be 
                -- on)
                if(button2 = off) then
                    -- all buttons were off in the previous cycle, also all of them (apart from button 2) are off in this cycle as well
                    -- only change state of button2
                    -- as mode is changed when button2 changes from "On1" to "off".
                    button2 <= On1;

                -- else the state of button2 will not change, invalid => invalid (as pb2 is still 1) and On1 => On1 (no notion of "pressed" for button 2)
                end if;  
                
                -- reset saturating-125 up-counter counterPress to 0 (as no button is pressed)
                -- this counter counts up when pb3 or pb4 is high (1)
                counterPress <= "0000000";

            elsif(pb1 = '0' and pb2 = '0' and pb3 ='1' and pb4 ='0') then
                -- only pb3 signal is high
                -- since time period of clock is 4 ms, it cannot be the case that a button was released and another button was pressed within 4 ms
                -- hence, it is safe to assume that in the previous clock cycle, either all buttons were off, or pb3 = '1' (others may or may not be 
                -- on)
                -- counterPress is activated and will count up until it saturates at 125 (it is initialised with 0, so overflow is not a problem)
                if(counterPress /= "1111101") then
                    counterPress <= counterPress + 1; -- counterPress is incremented by 1
                -- else saturate at 125
                end if;    
                -- Now, perform necessary state changes
                if(button3 = off) then
                    -- all the buttons were off in previous clock cycle, also all of them (apart from button 3) are off in this cycle as well
                    -- only change state of button3
                    -- as time is changed when button3 changes from "On1" to "off".
                    button3 <= On1;
                elsif(button3 = On1) then
                    -- check if saturation of counterPress has taken place
                    -- if saturated, change state to "pressed" (saturation takes place in 0.5 s)
                    -- else its state is unchanged, will remain in "On1" state.
                	if(counterPress = "1111101") then
                    	button3 <= pressed;
                    end if;
                -- else the state of button3 will not change, invalid => invalid (as pb3 is still 1) and pressed => pressed
                end if;

            elsif(pb1 = '0' and pb2 = '0' and pb3 ='0' and pb4 ='1') then
                -- only pb4 signal is high
            	-- since time period of clock is 4 ms, it cannot be the case that a button was released and another button was pressed within 4 ms
                -- hence, it is safe to assume that in the previous clock cycle, either all buttons were off, or pb4 = '1' (others may or may not be 
                -- on)
                -- counterPress is activated and will count up until it saturates at 125 (it is initialised to 0, so overflow is not a problem)
                if(counterPress /= "1111101") then
                    counterPress <= counterPress + 1; -- counterPress is incremented by 1
                -- else saturate at 125
                end if;  
                -- Now, perform necessary state changes  
                if(button4 = off) then
                    -- all the buttons were off in previous clock cycle, also all of them (apart from button 4) are off in this cycle as well
                    -- only change state of button4                    
                    -- as time is changed when button4 changes from "On1" to "off".
                    button4 <= On1;
                elsif(button4 = On1) then
                    -- check if saturation of counterPress has taken place
                    -- if saturated, change state to "pressed" (saturation takes place in 0.5 s)
                    -- else its state is unchanged, will remain in "On1" state.                    
                	if(counterPress = "1111101") then
                    	button4 <= pressed;
                    end if;
                -- else the state of button4 will not change, invalid => invalid (as pb4 is still 1) and pressed => pressed
                end if;
                
           	else
           		-- atleast two signals are high, so make all of the button states "invalid"
                button1 <= invalid;
                button2 <= invalid;
                button3 <= invalid;
                button4 <= invalid;
                -- also reset saturation-125 up-counter
                counterPress <= "0000000";
            end if; 
            
            -- button checking is done, now update clock every second if display mode is not equal to "setH", "setM" or "setS"
            -- if display mode is setH, setM or setS, then update time depending on whether button3/button4 is pressed
            -- I am not going to bother about button3/button4 being "On1", because a single press is registered only when "On1" to "off" transition takes place
            -- and that transition is already been taken care of in the "button-check" done above.

            if(displayMode = hourMin or displayMode = minSec or displayMode = hourSec) then
                -- counter1Hz is a modulo-250 counter, therefore has a frequency of 250 / 250 = 1 Hz
                -- increment time whenever counter1Hz = 0 (i.e. every second)
                -- first increment counter1Hz by 1 if it is not equal to 249, otherwise make it 0
                -- counter1Hz is initialised with 0, so overflow is not an issue
                if(counter1Hz = "11111001") then counter1Hz <= "00000000"; -- counter1Hz = 0
                else counter1Hz <= counter1Hz + 1; -- counter1Hz is incremented by 1
                end if;
                -- check if counter1Hz = 0
                if(counter1Hz = "00000000") then
                    -- update time
                	-- increment second count by 1
                    if(sec0 = "1001") then
                        -- sec0 = 9, so I need to make it 0 
                        sec0 <= "0000";
                        -- check sec1 
                        if(sec1 = "0101") then
                            -- sec1 = 5, so I need to make it 0
                            sec1 <= "0000";
                            -- Also increment minute count by 1
                            if(min0 = "1001") then
                                -- min0 = 9, so I need to make it 0
                                min0 <= "0000";
                                -- check min1
                                if(min1 = "0101") then
                                    -- min1 = 5, so I need to make it 0 
                                    min1 <= "0000";
                                    -- Also increment hour count by 1
                                    if(hour0 = "1001") then
                                        -- hour0 = 9, so I need to make it 0 
                                        hour0 <= "0000";
                                        -- check hour1. if hour1 = 2, then make it 0, otherwise just increment it by 1
                                        if(hour1 = "0010") then hour1 <= "0000"; -- hour1 = 0
                                        else hour1 <= hour1 + 1; -- hour1 is incremented by 1
                                        end if;
                                    elsif(hour0 = "0011" and hour1 = "0010") then
                                        -- hour count = 23, so make it 00 (because hour count varies from 00 to 23)
                                        hour0 <= "0000"; -- hour0 = 0
                                        hour1 <= "0000"; -- hour1 = 0
                                    -- hour0 is neither 9, nor hour = 23, so simply add 1 to hour0       
                                    else hour0 <= hour0 + 1;
                                    end if;
                                -- min1 is not 5, so simply add 1    
                                else min1 <= min1 + 1;
                                end if;
                            -- min0 is not 9, so simply add 1    
                           	else min0 <= min0 + 1;
                            end if;
                        -- sec1 is not 5, so simply add 1    
                        else sec1 <= sec1 + 1;
                        end if;
                    -- sec0 is not 9, so simply add 1    
                    else sec0 <= sec0 + 1;
                    end if;
                    -- time incremented by 1
                
                -- else, do not increase time by 1 (because it has not been 1 s)     
                end if;    
                -- also, reset counter5Hz when not in set modes
                counter5Hz <= "000000";

            else
                -- displayMode = setH or setM or setS
                -- counter5Hz is a modulo-50 up-counter, therefore its frequency is 250 / 50 = 5 Hz
                -- if button3/button4 is pressed, time is incremented/decremented whenever counter5Hz = 0, i.e. every 0.2 s.
                -- Increment counter5Hz by 1. 
                -- If it is equal to 49 then make it 0, otherwise just add 1
                -- counter5Hz is initialised with 0, so overflow is not an issue
                if(counter5Hz = "110001") then counter5Hz <= "000000"; -- counter5Hz = 0
                else counter5Hz <= counter5Hz + 1; -- add 1
                end if;

                -- only update time if button3/button4 is pressed and counter5Hz = "000000" (5 times per second)
                if(displayMode = setH) then
                    -- update hour count
                    if(counter5Hz = "000000") then
                        -- time will be updated
                        if(button3 = pressed) then
                            -- increment hour count by 1
                            if(hour0 = "1001") then
                                -- hour0 = 9, so make it 0
                                hour0 <= "0000";
                                -- check hour1, if it 2, then make it 0, otherwise simply add 1
                                if(hour1 = "0010") then hour1 <= "0000"; -- hour1 = 0
                                else hour1 <= hour1 + 1; -- add 1
                                end if;
                            elsif(hour0 = "0011" and hour1 = "0010") then
                                -- hour count = 23, so make it 00 (as hour ranges from 00 to 23)
                                hour0 <= "0000"; -- hour0 = 0
                                hour1 <= "0000"; -- hour1 = 0 
                            -- hour0 is neither 9, nor hour count = 23, so simply add 1 to hour0      
                            else hour0 <= hour0 + 1;
                            end if;

                        elsif(button4 = pressed) then
                            -- decrement hour count by 1
                            if(hour0 = "0000") then
                                -- hour0 is 0, so make it 9 or 3 depending on whether hour1 is 0 or not
                                if(hour1 = "0000") then 
                                    -- hour count = 00, so make it 23 (as hour varies between 00 and 23)
                                    hour0 <= "0011"; -- hour0 = 3
                                    hour1 <= "0010"; -- hour1 = 2
                                else 
                                    -- hour1 /= 0, so make hour0 = 9, and decrement hour1 by 1
                                    hour0 <= "1001"; -- hour0 = 9
                                    hour1 <= hour1 - 1; -- subtract 1
                                end if;
                            -- hour0 is not 0, so simply subtract 1 from hour0   
                            else hour0 <= hour0 - 1;
                            end if;
                        -- else no appropriate button is pressed, so do not update time    
                        end if;
                    -- counter5Hz /= 0, so do not update time, as it has not been 0.2 s    
                    end if;    
       
                elsif(displayMode = setM) then
                    -- update minute count
                    if(counter5Hz = "000000") then
                        -- time will be updated
                        if(button3 = pressed) then
                            -- increment minute count by 1
                            if(min0 = "1001") then
                                -- min0 = 9, so make it 0
                                min0 <= "0000";
                                -- check min1, if min1 = 5, then make it 0, otherwise simply add 1
                                if(min1 <= "0101") then min1 <= "0000"; -- min1 = 0
                                else min1 <= min1 + 1; -- add 1
                                end if;
                            -- min0 is not 9, so simply add 1 to min0   
                            else min0 <= min0 + 1;
                            end if;

                        elsif(button4 = pressed) then
                            -- decrement minute count by 1
                            if(min0 = "0000") then
                                -- min0 = 0, so make it 9
                                min0 <= "1001";
                                -- check min1, if min1 = 0, then make it 5, otherwise just subtract 1
                                if(min1 = "0000") then min1 <= "0101"; -- min1 = 5
                                else min1 <= min1 - 1; -- subtract 1
                                end if;
                            -- min0 is not 0, so simply subtract 1 from min0   
                            else min0 <= min0 - 1;
                            end if;
                        -- no appropriate button is pressed, so do not update time    
                        end if;
                    -- counter5Hz /= 0, so do not update time, as it has not been 0.2 s   
                    end if;    
                  
                elsif(displayMode = setS) then
                    -- update second count
                    if(counter5Hz = "000000") then
                        -- time will be updated
                        if(button3 = pressed) then
                            -- increment second count by 1
                            if(sec0 = "1001") then
                                -- sec0 = 9, so make it 0
                                sec0 <= "0000";
                                -- check sec1, if sec1 = 5, then make it 0, otherwise simply add 1
                                if(sec1 <= "0101") then sec1 <= "0000"; -- sec1 = 0
                                else sec1 <= sec1 + 1; -- add 1
                                end if;
                            -- sec0 is not 9, so simply add 1 to sec0   
                            else sec0 <= sec0 + 1;
                            end if;

                        elsif(button4 = pressed) then
                            -- decrement second count by 1
                            if(sec0 = "0000") then
                                -- sec0 = 0, so make it 9
                                sec0 <= "1001";
                                -- check sec1, if sec1 = 0, then make it 5, otherwise just subtract 1
                                if(sec1 = "0000") then sec1 <= "0101"; -- sec1 = 5
                                else sec1 <= sec1 - 1; -- subtract 1
                                end if;
                            -- sec0 is not 0, so simply subtract 1 from sec0   
                            else sec0 <= sec0 - 1;
                            end if;
                        -- no appropriate button is pressed, so do not update time    
                        end if;
                    -- counter5Hz /= 0, so do not update time, as it has not been 0.2 s   
                    end if;
                -- all display modes covered                        
                end if;    
            -- time updation done
            -- also reset counter1Hz when not in display mode
            counter1Hz <= "00000000";
            end if;
        -- all changes done (all required signals updated)    
        end if;    

        -- Digit changing done (7-segment), Mode changing done (button presses), Time updation done (either single press or 5 times a second or natural updation)
        -- only thing left is to assign outputs (to be displayed) according to the display mode set in this process
        -- That will be declared concurrently in the next process
    end process;

    -- process ends

    -- process declaration begins (for assigning digit0, digit1, digit2 and digit3 based on the display mode)
    process(displayMode, hour0, hour1, min0, min1, sec0, sec1) -- sensitivity list
    begin
        -- switch cases based on displayMode
        case displayMode is
            when hourMin =>
                    -- get HH:MM format
                    digit0 <= min0;
                    digit1 <= min1;
                    digit2 <= hour0;
                    digit3 <= hour1;
            when minSec =>
                    -- get MM:SS format
                    digit0 <= sec0;
                    digit1 <= sec1;
                    digit2 <= min0;
                    digit3 <= min1;
            when hourSec =>
                    -- get HH:SS format
                    digit0 <= sec0;
                    digit1 <= sec1;
                    digit2 <= hour0;
                    digit3 <= hour1;
            when setH =>
                    -- get big[H]:HH format
                    digit0 <= hour0;
                    digit1 <= hour1;
                    digit2 <= "1011"; 
                    digit3 <= "1010"; -- these are specific codes to display a big H, their corresponding cathode signals are given in the declaration of "convert"                      
            when setM =>
                    -- get big[M]:MM format
                    digit0 <= min0;
                    digit1 <= min1;
                    digit2 <= "1101";
                    digit3 <= "1100"; -- these are specific codes to display a big M, their corresponding cathode signals are given in the declaration of "convert"
            when setS =>
                    -- get big[S]:SS format
                    digit0 <= sec0;
                    digit1 <= sec1;
                    digit2 <= "1111";
                    digit3 <= "1110"; -- these are specific codes to display a big S, their corresponding cathode signals are given in the declaration of "convert"
        -- all cases covered
        end case;
    -- all digits are assigned, so end process
    -- conversion into cathode signals has already been done concurrently before
    end process;
    
    -- process ends
    
    -- state changes and display are taken care of, so end architecture
end digitalClock;

-- architecture ends

-- Component clock ends


-- Component convert starts

-- using standard libraries for unsigned type and conflict resolution
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- entity: convert
entity convert is
port (
    bin4: in unsigned(3 downto 0);
    -- the 4 bit representation of the symbol to be displayed
    bin7: out unsigned(6 downto 0)
    -- the 7 bit cathode signal that will diplay the symbol on the 7-segment display board
    );
end convert; 
--end entity

--architecture: cathode_convert
architecture cathode_convert of convert is
begin
    -- select bin7 on the basis of bin4
	with bin4 select
    bin7 <= "0000001" when "0000", -- displays 0
    		"1001111" when "0001", -- displays 1
            "0010010" when "0010", -- displays 2
            "0000110" when "0011", -- displays 3
            "1001100" when "0100", -- displays 4
            "0100100" when "0101", -- displays 5
            "0100000" when "0110", -- displays 6
            "0001111" when "0111", -- displays 7
            "0000000" when "1000", -- displays 8
            "0001000" when "1001", -- displays 9
            "1111000" when "1010", --
            "1001110" when "1011", -- these two together display a big H
            "0011001" when "1100", --
            "0001101" when "1101", -- these two together display a big M
            "0110100" when "1110", --
            "0100110" when others; -- these two together display a big S
    -- bin7 is assigned        
end cathode_convert;
-- end architecture

-- Component convert ends


-- Component stepDown starts

-- using standard libraries for unsigned type and conflict resolution                                  
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- entity: stepDown
entity stepDown is
port (
    sysClock: in bit;
    -- the input clock (for given BASYS3 it is of 10 MHz frequency)
    downClock: out bit
    -- output clock of reduced frequency (in this case, input clock is reduced down to 250 Hz)
    );
end stepDown;
-- end entity

-- architecture dclock
architecture dclock of stepDown is
-- signal declaration begins
-- counter is a modulo-40,000 up-counter, therefore, its frequency is 10,000,000 / 40,000 = 250 Hz    
signal counter: unsigned(15 downto 0);
-- signal declaration ends
begin
    
    -- process to update counter (every rising edge)
	process(sysClock)
    begin
        if(rising_edge(sysClock)) then
            -- check counter, if counter = 39,999 (9C3F in hexadecimal notation), then make it 0, otherwise add 1
            if(counter = x"9C3F") then counter <= x"0000"; -- x"" notation is used to indicate that the number in quotes is a hexadecimal number (each digit is a 4 bit number)
            else counter <= counter + 1; -- add 1          -- Since, counter is a 16 bit vector, I need to provide 4 values within quotes as 4 * 4 = 16   
            end if;
        -- do not update counter if it is not a rising edge    
        end if;
    -- counter updation done, so end process    
    end process;

    -- assign 0/1 to downClock based on counter value. downClock = 1 as long as counter < 20,000 (4E20 in hexadecimal) (first 20,000 counts) and 0 otherwise (next 20,000 counts)
    -- this way downClock will be 1 for half of the time period of counter and 0 for the other half. Hence, it will act as a clock of frequency 250 Hz (time period: 4 ms)
    downClock <= '1' when counter < x"4E20" else '0';
    -- assignment to downClock done, clock created
end dclock;        
--end architecture
          
-- Component stepDown ends                	
        

-- VHDL code ends

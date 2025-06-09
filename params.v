// global parameters for Viterbi Decoder

// simulation parameters
`define HALF  100 
`define FULL  200 
`define DPERIOD  (`FULL*128)

// decoder parameters
`define CONSTRAINT 	9	// K

`define N_ACS  		4 	// 4 ACSs
`define N_STATE		256 	// 

`define N_ITER		64 	// 
`define WD_STATE  	8 	//

`define WD_CODE 	2 	// width of Decoder Input

`define WD_FSM  	6 	// 256 (states) : 4 (ACSs) = 64 --> log2(64) = 6
`define WD_DEPTH  	6	// depth has to be at least 5*(K-1).
			
`define WD_DIST		2 	// Width of Calculated Distance

`define WD_METR  	8 	// width of metric.

// For survivor memory 
`define WD_RAM_DATA  	8 	// width of RAM Data Bus 
`define WD_RAM_ADDRESS	11	// width of RAM Address Bus
`define WD_TB_ADDRESS	5	// width of Address Bus 
				// between TB and MMU
				// --> `WD_RAM_ADDRESS - `WD_DEPTH
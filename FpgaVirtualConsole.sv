module FpgaVirtualConsole(
    // general signals
    input               clk,
    input               rst,
    input       [3:0]   buttons,
    // PS/2 receiver
    input               ps2Clk,
    input               ps2Data,
    // uart transceiver
    input               uartRx,
    output  reg         uartTx,
    // vga output
    output  VgaSignal_t vga,
    // sram read/write
    output  SramInterface_t sramInterface,
    inout   [`SRAM_DATA_WIDTH - 1:0]  sramData,
    // debug output
    output  reg [55:0]  segmentDisplays   // eight 7-segmented displays
    );


    // constants
    parameter CLOCK_FREQUNCY = 100000000;   // default clock frequency is 100 MHz
    parameter BAUD_RATE = 115200;           // default baud rate of UART
	parameter CONSOLE_LINES = 40;
	parameter CONSOLE_COLUMNS = 80;


    // 7-segmented displays
    logic     [3:0]   segmentDisplayHex[0:7]; // eight hex 	 

    always_ff @(posedge clk) begin

    end

    //LedDecoder decoder_1(.hex(segmentDisplayHex[7]), .segments(segmentDisplays[55:49]));
    //LedDecoder decoder_2(.hex(segmentDisplayHex[6]), .segments(segmentDisplays[48:42]));
    //LedDecoder decoder_3(.hex(segmentDisplayHex[5]), .segments(segmentDisplays[41:35]));
    //LedDecoder decoder_4(.hex(segmentDisplayHex[4]), .segments(segmentDisplays[34:28]));
    //LedDecoder decoder_5(.hex(segmentDisplayHex[3]), .segments(segmentDisplays[27:21]));
    //LedDecoder decoder_6(.hex(segmentDisplayHex[2]), .segments(segmentDisplays[20:14]));
    //LedDecoder decoder_7(.hex(segmentDisplayHex[1]), .segments(segmentDisplays[13:7]));
    //LedDecoder decoder_8(.hex(segmentDisplayHex[0]), .segments(segmentDisplays[6:0]));
	 
	 
	// keyboard test
	logic [7:0] scan_code, ascii_code;
	logic scan_code_ready;
	logic letter_case;
	
//	assign segmentDisplays[7:0] = ascii_code;
	
	// instantiate keyboard scan code circuit
	Ps2StateMachine kb_unit(
        .clk,
        .reset(~rst),
        .ps2d(ps2Data),
        .ps2c(ps2Clk),
        .scan_code,
        .scan_code_ready,
        .letter_case_out(letter_case)
    );
					
	// instantiate key-to-ascii code conversion circuit
	ScanCodeToAscii k2a_unit(
        .letter_case,
        .scan_code,
        .ascii_code
    );

    // UART module
    logic         uartReady;
    logic [7:0]   uartDataReceived;
    logic         uartStartSend;
    logic [7:0]   uartDataToSend;
    logic         uartBusy;

    always_ff @(posedge clk) begin
        uartStartSend <= scan_code_ready;
        uartDataToSend <= ascii_code;
    end

    async_transmitter #(
        .ClkFrequency(CLOCK_FREQUNCY),
        .Baud(BAUD_RATE)
    ) uartTransmitter(
        .clk, // input
        .TxD_start(uartStartSend), // input
		.TxD_data(uartDataToSend), // input
        .TxD(uartTx), // output
        .TxD_busy(uartBusy) // output
    );

    async_receiver #(
        .ClkFrequency(CLOCK_FREQUNCY),
        .Baud(BAUD_RATE)
    ) uartReceiver(
        .clk, // input
        .RxD(uartRx), // input
        .RxD_data_ready(uartReady), // output
        .RxD_data(uartDataReceived) // output
    );

//    assign segmentDisplays[15:8] = uartDataReceived;

	// VT100 parser module
	VT100Parser #(
		.CONSOLE_LINES(CONSOLE_LINES),
		.CONSOLE_COLUMNS(CONSOLE_COLUMNS)
	) vt100Parser(
		.clk(clk),
		.rst(rst),
		.dataReady(uartReady),
		.data(uartDataReceived),
//		.cursorPosition(???),
		.debug(segmentDisplays[55:14])
	);

    // Frequency Divider

    logic clk25M;

    FrequencyDivider #(
        .clockFrequency(CLOCK_FREQUNCY),
        .requiredFrequency(25000000)
    ) divider25M (
        .clk,
        .rst,
        .slowClock(clk25M)
    );

    // Text RAM module

    TextRamRequest_t textRamRequestParser, textRamRequestRenderer;
    TextRamResult_t textRamResultParser, textRamResultRenderer;

    TextRam ram(
        .aclr_a(rst),
        .aclr_b(rst),
        .address_a(textRamRequestParser.address),
        .address_b(textRamRequestRenderer.address),
        .clock_a(clk),
        .clock_b(clk25M),
        .data_a(textRamRequestParser.data),
        .data_b(textRamRequestRenderer.data),
        .wren_a(textRamRequestParser.wren),
        .wren_b(textRamRequestRenderer.wren),
        .q_a(textRamResultParser),
        .q_b(textRamResultRenderer)
    );

    // Sram controller module

    SramRequest_t vgaRequest, rendererRequest;
    SramResult_t vgaResult, rendererResult;
    
    SramController sramController(
        .clk(clk25M),
        .rst,
        .sramInterface,
        .sramData,
        .vgaRequest,
        .vgaResult,
        .rendererRequest,
        .rendererResult
    );


    // VGA module

    VgaDisplayAdapter display(
        .clk(clk25M),
        .rst,
        .ramRequest(vgaRequest),
        .ramResult(vgaResult),
        .vga,
        .paintDone(segmentDisplays[55])
    );


endmodule

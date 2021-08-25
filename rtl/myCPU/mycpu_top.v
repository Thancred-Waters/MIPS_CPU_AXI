`include "mycpu.h"

module mycpu_top(
    input  [5 :0] int          ,
    input         aclk         ,
    input         aresetn      ,
    //axi
    //ar
    output [3 :0] arid         ,
    output [31:0] araddr       ,
    output [7 :0] arlen        ,
    output [2 :0] arsize       ,
    output [1 :0] arburst      ,
    output [1 :0] arlock       ,
    output [3 :0] arcache      ,
    output [2 :0] arprot       ,
    output        arvalid      ,
    input         arready      ,
    //r           
    input  [3 :0] rid          ,
    input  [31:0] rdata        ,
    input  [1 :0] rresp        ,
    input         rlast        ,
    input         rvalid       ,
    output        rready       ,
    //aw          
    output [3 :0] awid         ,
    output [31:0] awaddr       ,
    output [7 :0] awlen        ,
    output [2 :0] awsize       ,
    output [1 :0] awburst      ,
    output [1 :0] awlock       ,
    output [3 :0] awcache      ,
    output [2 :0] awprot       ,
    output        awvalid      ,
    input         awready      ,
    //w          
    output [3 :0] wid          ,
    output [31:0] wdata        ,
    output [3 :0] wstrb        ,
    output        wlast        ,
    output        wvalid       ,
    input         wready       ,
    //b           
    input  [3 :0] bid          ,
    input  [1 :0] bresp        ,
    input         bvalid       ,
    output        bready       ,
    // trace debug interface
    output [31:0] debug_wb_pc,
    output [ 3:0] debug_wb_rf_wen,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata
);
reg         reset;
always @(posedge aclk) reset <= ~aresetn;

// inst sram interface
wire         inst_sram_req;
wire         inst_sram_wr;
wire [ 1:0]  inst_sram_size;
wire [31:0]  inst_sram_addr;
wire [ 3:0]  inst_sram_wstrb;
wire [31:0]  inst_sram_wdata;
wire         inst_sram_addr_ok;
wire         inst_sram_data_ok;
wire  [31:0] inst_sram_rdata;
// data sram interface
wire         data_sram_req;
wire         data_sram_wr;
wire [ 1:0]  data_sram_size;
wire [31:0]  data_sram_addr;
wire [ 3:0]  data_sram_wstrb;
wire [31:0]  data_sram_wdata;
wire         data_sram_addr_ok;
wire         data_sram_data_ok;
wire [31:0]  data_sram_rdata;   
//flow
wire         ds_allowin;
wire         es_allowin;
wire         ms_allowin;
wire         ws_allowin;
wire         fs_to_ds_valid;
wire         ds_to_es_valid;
wire         es_to_ms_valid;
wire         ms_to_ws_valid;
wire [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus;
wire [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus;
wire [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus;
wire [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus;
wire [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus;
wire [`FS_EX_BUS_WD    -1:0] fs_ex_bus;
wire [`DS_EX_BUS_WD    -1:0] ds_ex_bus;
wire [`ES_EX_BUS_WD    -1:0] es_ex_bus;
wire [`MS_EX_BUS_WD    -1:0] ms_ex_bus;
wire [4                  :0] ds_load_mem_bus;
wire [6                  :0] es_load_mem_bus;
wire [3                  :0] ds_save_mem_bus;
wire                         es_wait_mem;
wire [`BR_BUS_WD       -1:0] br_bus;//br_taken: 1 bit + br_target: 32 bit = 33 bit
//hazard
wire stallD;
wire stallE;
wire alu_stall;
wire [1:0] forward_rs;
wire [1:0] forward_rt;
wire ds_use_rs;
wire [4:0] rs_addr;
wire ds_use_rt;
wire [4:0] rt_addr;
wire       es_write_reg;
wire [4:0] es_reg_dest;
wire       ms_write_reg;
wire [4:0] ms_reg_dest;
wire       ws_write_reg;
wire [4:0] ws_reg_dest;
wire [35:0] ms_to_ds_bus;
wire es_read_mem;
wire [31:0] es_to_ds_bus;
wire [31:0] es_sram_rdata;
//cp0
wire  [ 8:0] c0_exception;
wire  [ 4:0] c0_addr;
wire  [31:0] c0_wdata;
wire         c0_wb_valid;
wire         c0_wb_bd;
wire  [31:0] c0_wb_pc;
wire         c0_valid;
wire  [31:0] c0_res;
wire  [31:0] eret_pc;
wire  [31:0] ws_badvaddr;
wire         eret_flush;
wire         ex_flush;
wire         flush;
wire         ms_mfc0_stall;
wire         es_mfc0_stall;
//exception
wire es_ex;
wire ms_ex;
wire ws_ex;

assign flush = eret_flush | ex_flush;

cpu_axi_interface u_cpu_axi_interface(
    .clk(aclk),
    .resetn(aresetn), 

    //inst sram-like 
    .inst_req(inst_sram_req)     ,
    .inst_wr(inst_sram_wr)      ,
    .inst_wstrb(inst_sram_wstrb),
    .inst_size(inst_sram_size)    ,
    .inst_addr(inst_sram_addr)    ,
    .inst_wdata(inst_sram_wdata)   ,
    .inst_rdata(inst_sram_rdata)   ,
    .inst_addr_ok(inst_sram_addr_ok) ,
    .inst_data_ok(inst_sram_data_ok) ,
    
    //data sram-like 
    .data_req(data_sram_req)     ,
    .data_wr(data_sram_wr)      ,
    .data_wstrb(data_sram_wstrb),
    .data_size(data_sram_size)    ,
    .data_addr(data_sram_addr)    ,
    .data_wdata(data_sram_wdata)   ,
    .data_rdata(data_sram_rdata)   ,
    .data_addr_ok(data_sram_addr_ok) ,
    .data_data_ok(data_sram_data_ok) ,

    //axi
    //ar
    .arid(arid)         ,
    .araddr(araddr)       ,
    .arlen(arlen)        ,
    .arsize(arsize)       ,
    .arburst(arburst)      ,
    .arlock(arlock)        ,
    .arcache(arcache)      ,
    .arprot(arprot)       ,
    .arvalid(arvalid)      ,
    .arready(arready)      ,
    //r           
    .rid(rid)          ,
    .rdata(rdata)        ,
    .rresp(rresp)        ,
    .rlast(rlast)        ,
    .rvalid(rvalid)       ,
    .rready(rready)       ,
    //aw          
    .awid(awid)         ,
    .awaddr(awaddr)       ,
    .awlen(awlen)        ,
    .awsize(awsize)       ,
    .awburst(awburst)      ,
    .awlock(awlock)       ,
    .awcache(awcache)      ,
    .awprot(awprot)       ,
    .awvalid(awvalid)      ,
    .awready(awready)     ,
    //w          
    .wid(wid)          ,
    .wdata(wdata)        ,
    .wstrb(wstrb)        ,
    .wlast(wlast)        ,
    .wvalid(wvalid)       ,
    .wready(wready)       ,
    //b           
    .bid(bid)          ,
    .bresp(bresp)        ,
    .bvalid(bvalid)       ,
    .bready(bready)       
);

// IF stage
if_stage if_stage(
    .clk            (aclk           ),
    .reset          (reset          ),
    //allowin
    .ds_allowin     (ds_allowin     ),
    //brbus
    .br_bus         (br_bus         ),
    //outputs
    .fs_to_ds_valid (fs_to_ds_valid ),
    .fs_to_ds_bus   (fs_to_ds_bus   ),
    .fs_ex_bus      (fs_ex_bus      ),
    //from cp0
    .ex_flush(ex_flush),
    .eret_flush(eret_flush),
    .eret_pc(eret_pc),
    // inst sram interface
    .inst_sram_req     (inst_sram_req    ),
    .inst_sram_wr      (inst_sram_wr     ),
    .inst_sram_size    (inst_sram_size   ),
    .inst_sram_addr    (inst_sram_addr   ),
    .inst_sram_wstrb   (inst_sram_wstrb  ),
    .inst_sram_wdata   (inst_sram_wdata  ),
    .inst_sram_addr_ok (inst_sram_addr_ok),
    .inst_sram_data_ok (inst_sram_data_ok),
    .inst_sram_rdata   (inst_sram_rdata  )
);
// ID stage
id_stage id_stage(
    .clk            (aclk           ),
    .reset          (reset          ),
    //stall
    .stallD         (stallD         ),
    .ds_use_rs      (ds_use_rs      ),
    .rs_addr        (rs_addr        ),
    .ds_use_rt      (ds_use_rt      ),
    .rt_addr        (rt_addr        ),
    //forward
    .forward_rs     (forward_rs     ),
    .forward_rt     (forward_rt     ),
    //allowin
    .es_allowin     (es_allowin     ),
    .ds_allowin     (ds_allowin     ),
    //from fs
    .fs_to_ds_valid (fs_to_ds_valid ),
    .fs_to_ds_bus   (fs_to_ds_bus   ),
    .fs_ex_bus      (fs_ex_bus      ),
    //to es
    .ds_to_es_valid (ds_to_es_valid ),
    .ds_to_es_bus   (ds_to_es_bus   ),
    .ds_load_mem_bus(ds_load_mem_bus),
    .ds_save_mem_bus(ds_save_mem_bus),
    .ds_ex_bus      (ds_ex_bus      ),
    //to fs
    .br_bus         (br_bus         ),
    //from cp0
    .flush          (flush          ),
    .es_ex          (es_ex          ),
    .ms_ex          (ms_ex          ),
    .ws_ex          (ws_ex          ),
    //to rf: for write back
    .ws_to_rf_bus   (ws_to_rf_bus   ),
    //from ms
    .ms_to_ds_bus   (ms_to_ds_bus   ),
    //from ds
    .es_to_ds_bus   (es_to_ds_bus   )
);
// EXE stage
exe_stage exe_stage(
    .clk            (aclk           ),
    .reset          (reset          ),
    //stall
    .es_write_reg   (es_write_reg   ),
    .es_reg_dest    (es_reg_dest    ),
    .alu_stall      (alu_stall      ),
    .es_mfc0_stall  (es_mfc0_stall  ),
    .stallE         (stallE         ),
    //forward
    .es_read_mem    (es_read_mem    ),
    .es_to_ds_bus   (es_to_ds_bus   ),
    //allowin
    .ms_allowin     (ms_allowin     ),
    .es_allowin     (es_allowin     ),
    //from ds
    .ds_to_es_valid (ds_to_es_valid ),
    .ds_to_es_bus   (ds_to_es_bus   ),
    .ds_load_mem_bus(ds_load_mem_bus),
    .ds_save_mem_bus(ds_save_mem_bus),
    .ds_ex_bus      (ds_ex_bus      ),
    //to ms
    .es_to_ms_valid (es_to_ms_valid ),
    .es_to_ms_bus   (es_to_ms_bus   ),
    .es_load_mem_bus(es_load_mem_bus),
    .es_ex_bus      (es_ex_bus      ),
    .es_sram_rdata  (es_sram_rdata  ),
    //from cp0
    .flush          (flush          ),
    //exception
    .es_ex          (es_ex          ),
    .ms_ex          (ms_ex          ),
    .ws_ex          (ws_ex          ),
    // data sram interface
    .data_sram_req     (data_sram_req    ),
    .data_sram_wr      (data_sram_wr     ),
    .data_sram_size    (data_sram_size   ),
    .data_sram_addr    (data_sram_addr   ),
    .data_sram_wstrb   (data_sram_wstrb  ),
    .data_sram_wdata   (data_sram_wdata  ),
    .data_sram_addr_ok (data_sram_addr_ok),
    .data_sram_rdata   (data_sram_rdata  ),
    .data_sram_data_ok (data_sram_data_ok)
);
// MEM stage
mem_stage mem_stage(
    .clk            (aclk           ),
    .reset          (reset          ),
    //stall
    .ms_write_reg   (ms_write_reg   ),
    .ms_reg_dest    (ms_reg_dest    ),
    .ms_mfc0_stall  (ms_mfc0_stall  ),
    //allowin
    .ws_allowin     (ws_allowin     ),
    .ms_allowin     (ms_allowin     ),
    //from es
    .es_to_ms_valid (es_to_ms_valid ),
    .es_to_ms_bus   (es_to_ms_bus   ),
    .es_load_mem_bus(es_load_mem_bus),
    .es_ex_bus      (es_ex_bus      ),
    .data_sram_rdata(es_sram_rdata  ),
    //to ws
    .ms_to_ws_valid (ms_to_ws_valid ),
    .ms_to_ws_bus   (ms_to_ws_bus   ),
    .ms_ex_bus      (ms_ex_bus      ),
    //from cp0
    .flush          (flush          ),
    //to ds
    .ms_to_ds_bus   (ms_to_ds_bus   ),
    //to es
    .ms_ex          (ms_ex          )
);
// WB stage
wb_stage wb_stage(
    .clk            (aclk           ),
    .reset          (reset          ),
    //stall
    .ws_write_reg   (ws_write_reg   ),
    .ws_reg_dest    (ws_reg_dest    ),
    //allowin
    .ws_allowin     (ws_allowin     ),
    //from ms
    .ms_to_ws_valid (ms_to_ws_valid ),
    .ms_to_ws_bus   (ms_to_ws_bus   ),
    .ms_ex_bus      (ms_ex_bus      ),
    //to rf: for write back
    .ws_to_rf_bus   (ws_to_rf_bus   ),
    //to cp0
    .c0_exception   (c0_exception   ),
    .c0_addr        (c0_addr        ),
    .c0_wdata       (c0_wdata       ),
    .c0_wb_valid    (c0_wb_valid    ),
    .c0_wb_bd       (c0_wb_bd       ),
    .c0_wb_pc       (c0_wb_pc       ),
    .ws_badvaddr    (ws_badvaddr    ),
    //from cp0
    .c0_valid(c0_valid),
    .c0_res(c0_res),
    .flush(flush),
    //to es
    .ws_ex          (ws_ex          ),
    //trace debug interface
    .debug_wb_pc      (debug_wb_pc      ),
    .debug_wb_rf_wen  (debug_wb_rf_wen  ),
    .debug_wb_rf_wnum (debug_wb_rf_wnum ),
    .debug_wb_rf_wdata(debug_wb_rf_wdata)
);

cp0_reg cp0(
//input
    .clk         (aclk),
    .reset       (reset),
    .exception   (c0_exception),
    .c0_addr     (c0_addr),
    .c0_wdata    (c0_wdata),
    .wb_valid    (c0_wb_valid),
    .wb_bd       (c0_wb_bd),
    .wb_pc       (c0_wb_pc),
    .wb_badvaddr (ws_badvaddr),
    .ext_int_in  (int),
//output
    .c0_valid    (c0_valid),
    .c0_res      (c0_res),
    .eret_pc     (eret_pc),
    .eret_flush  (eret_flush),
    .ex_flush    (ex_flush)
);

hazard hazard(
    .ds_use_rs(ds_use_rs),
    .rs_addr(rs_addr),
    .ds_use_rt(ds_use_rt),
    .rt_addr(rt_addr),
    .es_write_reg(es_write_reg),
    .es_reg_dest(es_reg_dest),
    .es_read_mem(es_read_mem),
    .es_mfc0(es_mfc0_stall),
    .alu_stall(alu_stall),
    .ms_write_reg(ms_write_reg),
    .ms_reg_dest(ms_reg_dest),
    .ms_mfc0(ms_mfc0_stall),
    .ws_write_reg(ws_write_reg),
    .ws_reg_dest(ws_reg_dest),
    //exception
    .es_ex(es_ex),
    .ms_ex(ms_ex),
    .ws_ex(ws_ex),
    //stall
    .stallD(stallD),
    .stallE(stallE),
    //forward
    .forward_rs(forward_rs),
    .forward_rt(forward_rt)
);
endmodule

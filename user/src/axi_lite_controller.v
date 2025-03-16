//AXI-Lite Slave Controller
/*
1. 在 AXI-Lite Controller 中，会设置一些寄存器，AXI 总线能设置这些寄存器，控制器能把这些寄存器的值输出到下端的 IP 中。
2. 当 valid && ready 为 1 时，代表握手成功。
3. 我们在这里写的是从机的 AXI 总线，只能被写入和被读出。
*/
module axi_lite_controller
#(
        parameter AXI_ADDRESS_WIDTH = 5
)
(
        //clock and reset
        input                                           aclk            ,
        input                                           aresetn         ,

        //AXI-Lite bus
        //Write Address Channel
        input           [AXI_ADDRESS_WIDTH - 1:0]       saxi_awaddr     ,
        input                                           saxi_awvalid    ,
        output                                          saxi_awready    ,

        //Read Address Channel
        input           [AXI_ADDRESS_WIDTH - 1:0]       saxi_araddr     ,
        output                                          saxi_arready    ,
        input                                           saxi_arvalid    ,

        //Write Data Channel
        input           [31:0]                          saxi_wdata      ,
        input                                           saxi_wvalid     ,
        output                                          saxi_wready     ,

        //Read Data Channel
        output   reg    [31:0]                          saxi_rdata      ,
        output                                          saxi_rvalid     ,
        input                                           saxi_rready     ,

        //Write Response Channel
        output                                          saxi_bvalid     ,
        input                                           saxi_bready     ,

        //Registers definitions
        output          [31:0]                          reg1            ,
        output          [31:0]                          reg2
);

//Registers table
//Registers table 中登记了每个寄存器的名称、地址和它的功能
/*
| Register Name | ADDRESS | FUNCTION |
| REG1          | 0x000   |          |
| REG2          | 0x004   |          |
*/

//Registers definitions
reg [31:0] r_reg1;
reg [31:0] r_reg2;

//寄存器输出
assign reg1 = r_reg1;
assign reg2 = r_reg2;

//AXI write address channel
//saxi_awready
//主机的 valid 信号拉高后，从机的 ready 信号拉高
reg r_saxi_awready;
assign saxi_awready = r_saxi_awready;
always @(posedge aclk or negedge aresetn)
        if (!aresetn)
                r_saxi_awready <= 1'b0;
        else
                if (saxi_awvalid)
                        r_saxi_awready <= 1'b1;
                else
                        r_saxi_awready <= 1'b0;

//如果主机先把地址告诉从机，再把数据告诉从机，则从机需要一个寄存器缓存地址
reg [AXI_ADDRESS_WIDTH - 1:0] axi_awaddr_buffer;

//在握手成功时将地址缓存到寄存器中
always @(posedge aclk or negedge aresetn)
        if (!aresetn)
                axi_awaddr_buffer <= 'b0;
        else
                if (saxi_awvalid && saxi_awready) //握手成功
                        axi_awaddr_buffer <= saxi_awaddr;
                else
                        axi_awaddr_buffer <= axi_awaddr_buffer;

//AXI write data channel
//saxi_wready
reg r_saxi_wready;
assign saxi_wready = r_saxi_wready;
always @(posedge aclk or negedge aresetn)
        if (!aresetn)
                r_saxi_wready <= 1'b0;
        else
                if (saxi_wvalid)
                        r_saxi_wready <= 1'b1;
                else
                        r_saxi_wready <= 1'b0;

//Response request
reg axi_need_resp; //当有一个写请求出现时，将该寄存器拉高，代表此时需要产生写回馈
always @(posedge aclk or negedge aresetn)
        if (!aresetn)
                axi_need_resp <= 1'b0;
        else
                if (saxi_awvalid && saxi_awready) //握手成功，代表有一个写请求
                        axi_need_resp <= 1'b1;
                else
                        axi_need_resp <= 1'b0;

//写回馈是由从机发往主机的，但是主机并不会时刻监听写回馈，所以需要一个寄存器保存写回馈，等待主机来读取

//地址可以与数据同时到达，也可以先于数据到达，对于先于数据到达的情况，我们使用 axi_awaddr_buffer 来缓存地址，但是还有同时到达的情况，因此需要对地址进行选择
//Address selection
wire [AXI_ADDRESS_WIDTH - 1:0] axi_awaddr; //真正的地址
//如果地址和数据同时到达，此时地址在总线 saxi_awaddr 上，直接使用该地址，否则地址就会被我们缓存，使用缓存的地址
assign axi_awaddr = (saxi_awvalid && saxi_wvalid && saxi_wready && saxi_wvalid) ? saxi_awaddr : axi_awaddr_buffer;

//AXI write response channel
//saxi_bvalid
reg r_saxi_bvalid;
assign saxi_bvalid = r_saxi_bvalid;
always @(posedge aclk or negedge aresetn)
        if (!aresetn)
                r_saxi_bvalid <= 1'b0;
        else
                begin
                        if (axi_need_resp) //axi_need_resp 拉高时，代表需要写回馈，此时将 saxi_bvalid 拉高
                                r_saxi_bvalid <= 1'b1;
                        
                        if (saxi_bvalid && saxi_bready) //握手成功，代表写回馈已经被主机接收成功，此时需要拉低 saxi_bvalid
                                r_saxi_bvalid <= 1'b0;
                end

//AXI read address channel
//saxi_arready
reg r_saxi_arready;
assign saxi_arready = r_saxi_arready;
always @(posedge aclk or negedge aresetn)
        if (!aresetn)
                r_saxi_arready <= 1'b0;
        else
                if (saxi_arvalid)
                        r_saxi_arready <= 1'b1;
                else
                        r_saxi_arready <= 1'b0;

//读地址一定先于读数据到达，因此不需要进行区分
reg [AXI_ADDRESS_WIDTH - 1:0]   axi_araddr      ;
reg                             axi_need_read   ; //读取数据时，我们是把地址发下来就要求读取数据了，所以我们需要一个 need_read 字段来保存 "现在有一个读操作"

always @(posedge aclk or negedge aresetn)
        if (!aresetn)
                begin
                        axi_araddr <= 'b0;
                        axi_need_read <= 1'b0;
                end
        else
                begin
                        if (saxi_rvalid && saxi_rready) //握手成功，代表需要进行读操作
                                begin
                                        axi_araddr <= saxi_araddr;
                                        axi_need_read <= 1'b1;
                                end
                        else
                                begin
                                        axi_araddr <= axi_araddr;
                                        axi_need_read <= 1'b0;
                                end
                end

//AXI read data channel
//saxi_rvalid
reg axi_wait_for_read; //读等待模式，等到主机的 ready 信号拉高后，再把数据发给主机
reg [31:0] axi_data_to_read; //用于寄存读取的数据
reg r_saxi_rvalid;
assign saxi_rvalid = r_saxi_rvalid;
always @(posedge aclk or negedge aresetn)
        if (!aresetn)
                begin
                        r_saxi_rvalid <= 1'b0;
                        saxi_rdata <= 32'b0;
                        
                        axi_wait_for_read <= 1'b0;
                end
        else
                begin
                        if (axi_wait_for_read) //进入读等待模式，等待主机的 ready 信号拉高
                                if (saxi_rready) //主机的 ready 信号拉高后，将数据发给主机
                                        begin
                                                r_saxi_rvalid <= 1'b1;
                                                saxi_rdata <= axi_data_to_read; //将数据发给主机

                                                axi_wait_for_read <= 1'b0; //退出读等待模式
                                        end
                        else //进入读正常模式
                                if (axi_need_read && saxi_rready) //axi_need_read 拉高时，代表需要读取数据，此时 ready 信号拉高，代表主机可以读取数据，此时将数据发给主机
                                        begin
                                                saxi_rdata <= axi_data_to_read; //将数据发给主机
                                                r_saxi_rvalid <= 1'b1; //拉高 valid 信号，代表数据有效
                                        end
                                else if (axi_need_read) //axi_need_read 拉高时，代表需要读取数据，但是此时主机的 ready 信号拉低，代表主机还没有准备好，此时进入读等待模式
                                        begin
                                                axi_wait_for_read <= 1'b1; //进入读等待模式
                                                r_saxi_rvalid <= 1'b0; //拉低 valid 信号，代表数据无效
                                        end
                                else
                                        r_saxi_rvalid <= 1'b0;
                end

//AXI Registers write
always @(posedge aclk or negedge aresetn)
        if (!aresetn) //寄存器复位
                begin
                        r_reg1 <= 32'b0;
                        r_reg2 <= 32'b0;
                end
        else
                begin
                        if (saxi_wvalid && saxi_wready) //写数据通道握手成功
                                case (axi_awaddr) //axi_waddr 是真实的要写入的地址，根据地址来写入数据
                                        'h00: 
                                                r_reg1 <= saxi_wdata;
                                        'h04: 
                                                r_reg2 <= saxi_wdata;
                                        default: 
                                                begin end //do nothing
                                endcase
                        else
                                begin
                                        r_reg1 <= r_reg1;
                                        r_reg2 <= r_reg2;
                                end
                end

//AXI Registers read
//使用选择器，根据地址来选择读取哪个寄存器的数据
//axi_data_to_read 是一个输出缓存，它的值是根据地址来选择的，所以我们需要一个选择器来选择读取哪个寄存器的数据
always @(*)
        case (axi_araddr)
                'h00: 
                        axi_data_to_read = r_reg1;
                'h04: 
                        axi_data_to_read = r_reg2;
                default: 
                        axi_data_to_read = 32'b0;
        endcase

/*
1. 如果从机的寄存器是只读的，则要在AXI Registers write删除对应的写操作
2. 如果从机的寄存器在写完后就立刻清零，则只需要将 AXI Registers write 的 else 语句中的保持改为清零即可
*/

endmodule
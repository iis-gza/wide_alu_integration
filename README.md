# Instructions
In this exercise you will integrate a new hardware "accelerator" into pulpissimo
using reggen. For this purpose we prepared a dummy hw accelerator that performs
arithmetic operations on very long data words (256-bits) simultaneously. The
module has a non standard interface and must first be wrapped and connected to a
register file so we can control it through normal loads and stores from the
core. For that purpose we already prepared register file description file in
hjson format usable by reggen. This will allow us to simultaneously generate the
register file for our IP wrapper as well a generating documentation and C header
files for the hardware abstraction layer (HAL). After wrapping the IP with a
pulp compatible interface (we will use an APB plug and some protocol converter
from some PULP IP library) we attach it to APB crossbar in pulp_soc and add the
appropriate address rules for our peripheral.

Finally, after integating the IP into PULPissimo/pulp_soc we will proceed with
writing into the sdk a small driver to interact with the IP using the RISC-V core
in PULPissimo.

This exercise is quite complex to solve but it will guide you through all the
necessary steps to integrate arbitrary IPs into pulp_soc. Although this
particular IP will only contain a register slave port for communication, using the
knowledge from the previous exercise (memory layout modification) it should not
be hard to adapt the flow for IPs that also require master ports to the shared
memory.

## IP Integration

### Part 1: generate the IP

1. Familiarize yourself with the module we are going to integrate. Go through
   the toplevel signals and try to get a rough idea what the wide alu module
   does. As mentioned before, its taks is to accept two 256-bit operands and
   apply a user configurable operation (multiply, add, or etc.) on the operand
   and provide a 512-bit result. In addition to that, the wide-alu also allows
   to program a deacceleartion factor which is just a fancy name for a user
   configurable delay, how many clock cycles later the result should be availble
   (I know... a pretty useless "feature" :smile:).
2. Go through the register file descripion `wide_alu.hjson`. Consult the
   [documention](https://docs.opentitan.org/doc/rm/register_tool/ ) on the
   opentitan website on the specifics of the reggen hjson format. It is not
   important to uderstand every detail but debugging will be easier if you have
   a rough idea what registers are used to map to the different signals of the
   `wide_alu` module.
   > Of course, if you were wrapping your own IP you would have to write this hjson file
   yourself.
3. Create a new github repository with the files of this directory and add a
   `Bender.yml` description file.
   > We do not have any dependencies to other IPs yet but this will change as soon as we add the wrapper to our IP.
   Add the wide_alu dependency to the pulp_soc you are working on.
   From the pulpissimo folder do `./bender clone pulp_soc`. This will create the folder
   `working_dir/pulp_soc` and generate the Bender.lock which will tell bender to fetch pulp_soc
   from the new directory instead than github.  Modify the pulp_soc's Bender.yml. From the pulpissimo folder:
   ```
   make checkout
   make scripts
   make build
   ```
   These three steps will alwasy be needed when modifying the Bender.yml of one of the
   repositories in the `working_dir`.  
4. We are now going to write a wrapper for our wide_alu ip: In the directory of
   your new wide_alu repository, create a new SV module called `wide_alu_top`.
   The module should have the following portlist:
   - clk_i, rst_ni, test_mode_i
   - A single register slave port (use the `reg_req_t` and `reg_rsp_t` SystemVerilog struct).
     This interface is part of the register_interface IP so you can already add it as a
     dependency to your `Bender.yml` (make sure to use the same version as
     pulp_soc in order to avoid version conflicts).
     ```
       register_interface:     { git: "https://github.com/pulp-platform/register_interface.git", version: 0.3.1 }
     ```
    and the following parameters:
    ```
      #(
       parameter type reg_req_t = logic,
       parameter type reg_rsp_t = logic
       )
    ```
5. Generate the register file using the reggen tool. This exercise directory
   contains a link to the python tool that was patched by ETH for usage of the
   "Generic Register Interface Protocol" a much simpler alternative to the
   TileLink Protocol the lowRISC normally uses for their IPs.
   ```
   git submodule --init --recursive
   ./register_interface/vendor/lowrisc_opentitan/util/regtool.py -r -t wide_alu.hjson
   ```
   Have a look at the generated SystemVerilog package and the portlist of the
   generated register file. Include them in the Bender.yml of your wide_alu IP.

6. Declare wiring signals that will connect the register file with the actual wide_alu ip with the following snippet:
   ```
   wide_alu_reg2hw_t reg_file_to_ip;
   wide_alu_hw2reg_t ip_to_reg_file;
   ```
   
   These are once again structs. But this time, they are autogenerated by
   reggen. Regardless, you have to import the struct from the autogenerated
   SystemVerilog Package at the beginning of your module (*Please not at the
   beginning of the file. Remember what I said about imports into the
   compilation unit scope!*)
   
7. Instantiate the wide_alu IP. The two wiring signal structs we just created
    contain subfields for each register in our hjson and with each of those
    register fields, they contain fiels for the individual bitfields of our
    registers. Our last task for the wrapper is to connect those bitfields from
    the register file to the corresponding ports of our `wide_alu` ip. We
    provide you with the first part of the instantiation:
    
    ```
    wide_alu i_wide_alu(
      .clk_i,
      .rst_ni,
      .trigger_i(reg_file_to_ip.ctrl1.trigger.q & reg_file_to_ip.ctrl1.trigger.qe),
      .clear_err_i(reg_file_to_ip.ctrl1.clear_err.q & reg_file_to_ip.ctrl1.clear_err.qe),
      .op_a_i(reg_file_to_ip.op_a),
      .op_b_i(reg_file_to_ip.op_b),
      .result_o(ip_to_reg_file.result),
      .deaccel_factor_we_i(reg_file_to_ip.ctrl2.delay.qe),
      .deaccel_factor_i(reg_file_to_ip.ctrl2.delay.q),
      .deaccel_factor_o(ip_to_reg_file.ctrl2.delay.d),
      .op_sel_we_i(reg_file_to_ip.ctrl2.opsel.qe),
      .op_sel_i(wide_alu_pkg::optype_e'(reg_file_to_ip.ctrl2.opsel.q)),
      ...
    ```
    
    The last two port connections are missing. Try to figure out yourself how you can connect those to the register file. 
    
    > You might notice that for some signals we use only the `q` and `d` signal,
    > while we additionally use the `qe` signal for others. Have a look at the
    > OpenTitan documentaion on the register tool about the difference between
    > `hwext: True` registers and regular registers to figure out why.

### Part2 : instantiate the IP into pulp_soc

8. Commit your changes and add your wide_alu repo as a dependency of `pulp_soc`. In the case you'll find a bug
   while integrating your wide_alu_top, you'll be able to work on it with the `./bender clone wide_alu` command
   from the pulpissimo repository. As usual, to update your `work` library for questasim you'll need to do:
   ```
   make checkout
   make scripts
   make build
   ```

9. Since we want to plug the IP to the APB crossbar with the same register interface
   we will need a protocol converter from APB to the "generic register interface". Luckily such a
   protocol converter is already availble in the register_interface repository
   on github. Have a look at the corresponding  [module](https://github.com/pulp-platform/register_interface/blob/master/src/apb_to_reg.sv).
   We will use this module when inserting the `wide_alu_top` in the `pulp_soc/rtl/soc_peripherals.sv`

10. Let's add an APB_SLAVE. Go to `rtl/includes/periph_bus_defines.sv` in pulpissimo and add a slave increasing NB_MASTER from 11 to 12.
    Then, add it as in the following address space:
    ```
    `define WIDE_ALU_START_ADDR      32'h1A12_0000
    `define WIDE_ALU_END_ADDR        32'h1A12_0FFF
    ```
    in `rtl/pulp_soc/periph_bus_wrap.sv` we have the APB crossbar. Let's plug the slave and expose the additional
    APB_BUS.Master wide_alu_master interface to the top.
    ```
    `APB_ASSIGN_MASTER(s_masters[11], wide_alu_master);
    assign s_start_addr[11] = `WIDE_ALU_START_ADDR;
    assign s_end_addr[11]   = `WIDE_ALU_END_ADDR;
    ```
    
11. In the ` rtl/pulp_soc/soc_peripherals.sv` we will instantiate the `wide_alu_top` and the `apb_to_register` converter.
    Unfortunately, the autogenerated register_file does not contain a neat wrapper the converts form SystemVerilog Interface to structs.
    We thus have to do this step ourself; Use the following snippet to do the conversion:
   
   ```
   //Convert the REG_BUS interface to the struct signals used by the autogenerated interface
    localparam RegAw  = 6;
    localparam RegDw  = 32; 
    typedef logic [RegAw-1:0]   reg_addr_t;
    typedef logic [RegDw-1:0]   reg_data_t;
    typedef logic [RegDw/8-1:0] reg_strb_t;   
    `REG_BUS_TYPEDEF_REQ(reg_req_t, reg_addr_t, reg_data_t, reg_strb_t)
    `REG_BUS_TYPEDEF_RSP(reg_rsp_t, reg_data_t)   
    reg_req_t   reg_req;
    reg_rsp_t   reg_rsp;
    `REG_BUS_ASSIGN_TO_REQ(reg_req,wide_alu_reg_bus)
    `REG_BUS_ASSIGN_FROM_RSP(wide_alu_reg_bus,reg_rsp)   

    apb_to_reg i_apb_to_wide_alu
    (
     .clk_i     ( clk_i              ),
     .rst_ni    ( rst_ni             ),
    
     .penable_i ( s_wide_alu.penable ),
     .pwrite_i  ( s_wide_alu.pwrite  ),
     .paddr_i   ( s_wide_alu.paddr   ),
     .psel_i    ( s_wide_alu.psel    ),
     .pwdata_i  ( s_wide_alu.pwdata  ),
     .prdata_o  ( s_wide_alu.prdata  ),
     .pready_o  ( s_wide_alu.pready  ),
     .pslverr_o ( s_wide_alu.pslverr ),
    
     .reg_o     ( wide_alu_reg_bus   )
    );
   ```
   
   This is some macro magic that declares the structs for the "generic register
   interface protocol" with the correct bitwidth, declares signals of that
   struct type and assigns the signals of the interface to the struct signals
   and vice-versa.
   *You will have to add the following includes to the top of your wrapper file for this to work:*
   ```
   `include "register_interface/typedef.svh"
   `include "register_interface/assign.svh"
   ```
   *Don't forget to register the corresponding include directory in your `src_files.yml`*.

12. Instantiate your wide alu wrapper `wide_alu_top` in the same file.

13. Commit your changes to pulp_soc to a new fork (or branch if you already have a fork) of `pulp_soc` and modify the version in `Bender.yml` of pulpissimo. 

14. That's all. The ip is now integrated. Update all ips, regenerate the TCL
    scripts and try to build pulpissimo with the integrated IP. Check the log
    to make sure it actually fetches the ips_list.yml of your `wide_alu`
    repository. Get rid of all remaining errors during compilation and makes
    sure pulpissimo builds without any errors (some warnings are ok).

### Part 3: write the driver and test the RTL

Now that we are done integrating the IP into the HW, lets write a small driver
to actually use it without hardcoding register addresses ourselves.

You are given an unfinished driver. You need to integrate it into pulp-runtime
and complete the implementation. If you do everything correctly, running the
given example program (`main.c`) should return the 15 (the multiplication of 3
and 5 being done in the accelerator)

You are given the following files
- `wide_alu_driver.c`: contains partial implementation of the wide_alu driver
- `wide_alu_driver.h`: contains the header file for the partial implementaiton
  of the wide_alu driver


Follow these steps

1. Integrate the given put the driver into pulp-runtime by
   - Moving the header file in `pulp-runtime/include`
   - Moving the implementation file into `pulp-runtime/driver`
   - Patching up `pulpissimo.mk` and `include/pulp.h`

2. Use `wide_alu.hjson` with `regtool.py`to generate the c header
file and integrate it into pulp-runtime

2. Finish the driver implementation and get the `main.c` program to print the
   correct result. In order to do that you are required to implement the
   following functions.
   - `void set_op(uint8_t operation)`
   - `void trigger_op(void)`
   - `int wide_multiply(uint32_t a[32], uint32_t b[32], uint32_t result[64])`
   Before you start, study `main.c`, the already given driver files and your
   auto-generated header file.

   When you run `main.c` it should print `15` to stdout.

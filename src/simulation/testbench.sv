`include "uvm_macros.svh"
import uvm_pkg::*;

// Sequence Item
class ps2_item extends uvm_sequence_item;

	rand bit key_data;
	bit key_clock;
	bit [15:0] out;
	
	`uvm_object_utils_begin(ps2_item)
		`uvm_field_int(key_data, UVM_DEFAULT)
		`uvm_field_int(key_clock, UVM_DEFAULT)
		`uvm_field_int(out, UVM_DEFAULT)
	`uvm_object_utils_end
	
	function new(string name = "ps2_item");
		super.new(name);
	endfunction
	
	virtual function string my_print();
		return $sformatf(
			"key_data = %1b key_clock = %1b out = %16b",
			key_data, key_clock, out
		);
	endfunction

endclass

// Sequence
class generator extends uvm_sequence;

	`uvm_object_utils(generator)
	
	function new(string name = "generator");
		super.new(name);
	endfunction
	
	int num = 440;
	
	virtual task body();
		for (int i = 0; i < num; i++) begin
			ps2_item item = ps2_item::type_id::create("item");
			start_item(item);
			item.randomize();
			if (i % 11 == 0) begin
				item.key_data = 1'b0;
			end
			if (i % 11 == 10) begin
				item.key_data = 1'b1;
			end
			`uvm_info("Generator", $sformatf("Item %0d/%0d created, %s", i + 1, num, item.my_print()), UVM_LOW)
			item.print();
			finish_item(item);
		end
	endtask
	
endclass

// Driver
class driver extends uvm_driver #(ps2_item);
	
	`uvm_component_utils(driver)
	
	function new(string name = "driver", uvm_component parent = null);
		super.new(name, parent);
	endfunction
	
	virtual ps2_if vif;
	
	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		if (!uvm_config_db#(virtual ps2_if)::get(this, "", "ps2_vif", vif))
			`uvm_fatal("Driver", "No interface.")
	endfunction
	
	virtual task run_phase(uvm_phase phase);
		super.run_phase(phase);
		@(posedge vif.clk);
		forever begin
			ps2_item item;
			seq_item_port.get_next_item(item);
			`uvm_info("Driver", $sformatf("%s", item.my_print()), UVM_LOW)
			vif.key_data <= item.key_data;
			//vif.key_clock <= item.key_clock;
			@(negedge vif.key_clock);
			seq_item_port.item_done();
		end
	endtask
	
endclass

// Monitor

class monitor extends uvm_monitor;
	
	`uvm_component_utils(monitor)
	
	function new(string name = "monitor", uvm_component parent = null);
		super.new(name, parent);
	endfunction
	
	virtual ps2_if vif;
	uvm_analysis_port #(ps2_item) mon_analysis_port;
	
	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		if (!uvm_config_db#(virtual ps2_if)::get(this, "", "ps2_vif", vif))
			`uvm_fatal("Monitor", "No interface.")
		mon_analysis_port = new("mon_analysis_port", this);
	endfunction
	
	virtual task run_phase(uvm_phase phase);	
		super.run_phase(phase);
		@(posedge vif.clk);
		forever begin
			ps2_item item = ps2_item::type_id::create("item");
			@(negedge vif.key_clock);
			// item.key_clock = vif.key_clock;
			item.key_data = vif.key_data;
			item.out = vif.out;
			`uvm_info("Monitor", $sformatf("%s", item.my_print()), UVM_LOW)
			mon_analysis_port.write(item);
		end
	endtask
	
endclass

// Agent
class agent extends uvm_agent;
	
	`uvm_component_utils(agent)
	
	function new(string name = "agent", uvm_component parent = null);
		super.new(name, parent);
	endfunction
	
	driver d0;
	monitor m0;
	uvm_sequencer #(ps2_item) s0;
	
	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		d0 = driver::type_id::create("d0", this);
		m0 = monitor::type_id::create("m0", this);
		s0 = uvm_sequencer#(ps2_item)::type_id::create("s0", this);
	endfunction
	
	virtual function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		d0.seq_item_port.connect(s0.seq_item_export);
	endfunction
	
endclass

// Scoreboard
class scoreboard extends uvm_scoreboard;
	
	`uvm_component_utils(scoreboard)
	
	function new(string name = "scoreboard", uvm_component parent = null);
		super.new(name, parent);
	endfunction
	
	uvm_analysis_imp #(ps2_item, scoreboard) mon_analysis_imp;
	
	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		mon_analysis_imp = new("mon_analysis_imp", this);
	endfunction


	bit [10:0] data_buffer = 11'h000; //random code
	integer index = 0;
	
	virtual function write(ps2_item item);
		//`uvm_info("Scoreboard buffer", $sformatf("Buffer = %11b", data_buffer), UVM_LOW)
		data_buffer[index++] = item.key_data;
		if (index == 11) begin
			if (^data_buffer[8:1] == data_buffer[9]) begin // parity check not valid
				data_buffer[8:1] = 8'hFF;
			end
			if (data_buffer[8:1] == item.out[7:0] && data_buffer[0] == 1'b0 && data_buffer[10] == 1'b1)
				`uvm_info("Scoreboard", $sformatf("PASS!"), UVM_LOW)
			else
				`uvm_error("Scoreboard", $sformatf("FAIL! expected = %8b, got = %8b", item.out[7:0], data_buffer[8:1]))
			index = 0;
			data_buffer = 11'h000;
		end

	endfunction
	
endclass

// Environment
class env extends uvm_env;
	
	`uvm_component_utils(env)
	
	function new(string name = "env", uvm_component parent = null);
		super.new(name, parent);
	endfunction
	
	agent a0;
	scoreboard sb0;
	
	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		a0 = agent::type_id::create("a0", this);
		sb0 = scoreboard::type_id::create("sb0", this);
	endfunction
	
	virtual function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		a0.m0.mon_analysis_port.connect(sb0.mon_analysis_imp);
	endfunction
	
endclass

// Test
class test extends uvm_test;

	`uvm_component_utils(test)
	
	function new(string name = "test", uvm_component parent = null);
		super.new(name, parent);
	endfunction
	
	virtual ps2_if vif;

	env e0;
	generator g0;
	
	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		if (!uvm_config_db#(virtual ps2_if)::get(this, "", "ps2_vif", vif))
			`uvm_fatal("Test", "No interface.")
		e0 = env::type_id::create("e0", this);
		g0 = generator::type_id::create("g0");
	endfunction
	
	virtual function void end_of_elaboration_phase(uvm_phase phase);
		uvm_top.print_topology();
	endfunction
	
	virtual task run_phase(uvm_phase phase);
		phase.raise_objection(this);
		
		vif.rst_n <= 0;
		#20 vif.rst_n <= 1;
		
		g0.start(e0.a0.s0);
		phase.drop_objection(this);
	endtask

endclass

// Interface
interface ps2_if (
	input bit clk,
	input bit key_clock
);

	logic rst_n;
	logic key_data;
    logic [15:0] out;

endinterface

// Testbench
module testbench;

	reg clk;
	reg key_clock;
	
	ps2_if dut_if (
		.clk(clk),
		.key_clock(key_clock)
	);
	
	ps2 dut (
		.clk(clk),
		.rst_n(dut_if.rst_n),
		.key_clock(key_clock),
		.key_data(dut_if.key_data),
		.out(dut_if.out)
	);

	initial begin
		clk = 0;
		forever begin
			#10 clk = ~clk;
		end
	end

	initial begin
		key_clock = 0;
		forever begin
			#15 key_clock = ~key_clock;
		end
	end

	initial begin
		uvm_config_db#(virtual ps2_if)::set(null, "*", "ps2_vif", dut_if);
		run_test("test");
	end

endmodule

# Sources

The sources availabe in this repository should match with the cores in the example implementation project found in the top level Aqueduct README. The original project should be able to be recreated based on the diagram and description.

## Gigabit Transceiver

The `gt` directory contains setup instructions for the Xilinx Transceiver Wizard. No sources are included for legal reasons.

## HLS

The `hls` directory contains HLS sources. HLS sources must be synthesized and exported using Vivado HLS.

## Verilog

The `verilog` directory contains Verilog sources. Verilog sources must be imported and exported as IP in Vivado using the IP Integrator.

## Putting it together

The sources should be imported into one or more Vivado projects and connected as described in the top level README either manually or using the Block Diagram flow.

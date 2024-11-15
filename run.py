from pathlib import Path
from vunit import VUnit

VU = VUnit.from_argv(compile_builtins=False)
VU.add_vhdl_builtins()
VU.add_osvvm()
VU.add_verification_components()
VU.enable_location_preprocessing()
VU.add_com()

SRC_PATH = Path(__file__).parent

src_library = VU.add_library("src")
tb_library = VU.add_library("tb")

src_library.add_source_files(SRC_PATH / "main_file.vhd")

src_library.add_source_files(SRC_PATH / "bus" / "*.vhd")
tb_library.add_source_files(SRC_PATH / "bus" / "test" / "*.vhd")

tb_library.add_source_files(SRC_PATH / "complete_system"/ "test" / "*.vhd")

src_library.add_source_files(SRC_PATH / "triple_23lc1024_controller" / "*.vhd")
tb_library.add_source_files(SRC_PATH / "triple_23lc1024_controller"/ "test" / "*.vhd")

src_library.add_source_files(SRC_PATH / "common" / "*.vhd")
tb_library.add_source_files(SRC_PATH / "common" / "test" / "*.vhd")

src_library.add_source_files(SRC_PATH / "uart_bus_master" / "*.vhd")
tb_library.add_source_files(SRC_PATH / "uart_bus_master" / "test" / "*.vhd")

src_library.add_source_files(SRC_PATH / "uart_bus_slave" / "*.vhd")
tb_library.add_source_files(SRC_PATH / "uart_bus_slave" / "test" / "*.vhd")

src_library.add_source_files(SRC_PATH / "static_soc_info" / "*.vhd")
tb_library.add_source_files(SRC_PATH / "static_soc_info" / "test" / "*.vhd")

src_library.add_source_files(SRC_PATH / "gpio_controller" / "*.vhd")
tb_library.add_source_files(SRC_PATH / "gpio_controller" / "test" / "*.vhd")

src_library.add_source_files(SRC_PATH / "spi_master_device" / "*.vhd")
tb_library.add_source_files(SRC_PATH / "spi_master_device" / "test" / "*.vhd")

src_library.add_source_files(SRC_PATH / "riscv32_processor" / "*.vhd")
tb_library.add_source_files(SRC_PATH / "riscv32_processor" / "test" / "*.vhd")

src_library.add_source_files(SRC_PATH / "riscv32_processor" / "utils" / "*.vhd")
tb_library.add_source_files(SRC_PATH / "riscv32_processor" / "utils" / "test" / "*.vhd")

src_library.add_source_files(SRC_PATH / "riscv32_processor" / "pipeline" / "*.vhd")
tb_library.add_source_files(SRC_PATH / "riscv32_processor" / "pipeline" / "test" / "*.vhd")

src_library.add_source_files(SRC_PATH / "riscv32_processor" / "write_back_dcache" / "*.vhd")
tb_library.add_source_files(SRC_PATH / "riscv32_processor" / "write_back_dcache" / "test" / "*.vhd")

src_library.add_source_files(SRC_PATH / "riscv32_processor" / "memToBus" / "*.vhd")
tb_library.add_source_files(SRC_PATH / "riscv32_processor" / "memToBus" / "test" / "*.vhd")

src_library.add_source_files(SRC_PATH / "riscv32_processor" / "icache" / "*.vhd")
tb_library.add_source_files(SRC_PATH / "riscv32_processor" / "icache" / "test" / "*.vhd")

VU.set_sim_option("ghdl.gtkwave_script.gui", "gtkwave/setup.tcl")
VU.set_sim_option("disable_ieee_warnings", True)

VU.main()

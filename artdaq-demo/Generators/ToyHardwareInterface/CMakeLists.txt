cet_make_library(
	SOURCE
	ToyHardwareInterface.cc
	LIBRARIES
	artdaq::DAQdata
	artdaq_core::artdaq-core_Data
	artdaq_core_demo::artdaq-core-demo_Overlays
)

install_headers()
install_source()

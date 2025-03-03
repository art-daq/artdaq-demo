

include(artdaq::commandableGenerator)
cet_build_plugin(ToySimulator artdaq::commandableGenerator LIBRARIES REG artdaq-core-demo::Overlays artdaq-demo::Generators_ToyHardwareInterface )
cet_build_plugin(AsciiSimulator artdaq::commandableGenerator LIBRARIES REG artdaq-core-demo::Overlays )
cet_build_plugin(UDPReceiver artdaq::commandableGenerator LIBRARIES REG artdaq-core-demo::Overlays canvas::canvas)

add_subdirectory(ToyHardwareInterface)

install_headers()
install_source()

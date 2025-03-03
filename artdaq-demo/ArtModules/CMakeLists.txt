include(BuildPlugins) # Art Module

cet_build_plugin(ArtdaqDemoBuildInfo art::module
  LIBRARIES REG
  TRACE::MF
  artdaq-demo::BuildInfo
  artdaq-core::BuildInfo
  artdaq-core-demo::BuildInfo
  artdaq-utilities::BuildInfo
  artdaq::BuildInfo)

cet_build_plugin(NthEvent art::module)

cet_build_plugin(ToyDump art::module LIBRARIES REG artdaq-core-demo::Overlays)

cet_build_plugin(ASCIIDump art::module LIBRARIES REG artdaq-core-demo::Overlays)

cet_build_plugin(RootApplication art::module LIBRARIES REG ROOT::Gui )

cet_build_plugin(WFViewer art::module LIBRARIES REG artdaq-core-demo::Overlays ROOT::Core ROOT::Gui)

cet_build_plugin(DemoViewer art::module LIBRARIES REG artdaq-core-demo::Overlays ROOT::Core ROOT::Gui)

cet_build_plugin(CheckIntegrity art::module LIBRARIES REG artdaq-core-demo::Overlays)

cet_build_plugin(EventReporterOutput art::module LIBRARIES REG artdaq::DAQdata ROOT::Core artdaq-core::Data_ParentageMap)

install_headers(SUBDIRS detail)
install_source(SUBDIRS detail)
install_fhicl(SUBDIRS fcl)

////////////////////////////////////////////////////////////////////////
// Class:       DemoDataDumper
// Module Type: analyzer
// File:        DemoDataDumper_module.cc
// Description: Prints out information about each DemoDataProduct.
////////////////////////////////////////////////////////////////////////

#include "art/Framework/Core/EDAnalyzer.h"
#include "art/Framework/Core/ModuleMacros.h"
#include "art/Framework/Principal/Event.h"
#include "art/Framework/Principal/Handle.h"
#include "art/Framework/Principal/Run.h"
#include "art/Framework/Principal/SubRun.h"
#include "canvas/Utilities/Exception.h"

#include "artdaq-core-demo/Data/DemoDataProduct.hh"

#include "TRACE/tracemf.h"  // TLOG
#define TRACE_NAME "DemoDataDumper"

#include <vector>

namespace demo {
class DemoDataDumper;
}  // namespace demo

/**
 * \brief Demonstration art::EDAnalyzer which checks that all ToyFragment ADC counts are in the defined range
 */
class demo::DemoDataDumper : public art::EDAnalyzer
{
public:
	explicit DemoDataDumper(fhicl::ParameterSet const& pset);

	~DemoDataDumper() override = default;

	void analyze(art::Event const& evt) override;
	void endSubRun(art::SubRun const& sr) override;
	void endRun(art::Run const& r) override;

private:
	DemoDataDumper(DemoDataDumper const&) = delete;
	DemoDataDumper(DemoDataDumper&&) = delete;
	DemoDataDumper& operator=(DemoDataDumper const&) = delete;
	DemoDataDumper& operator=(DemoDataDumper&&) = delete;
};

demo::DemoDataDumper::DemoDataDumper(fhicl::ParameterSet const& pset)
    : EDAnalyzer(pset)
{}

TraceStreamer& operator<<(TraceStreamer& l, std::vector<int> const& r) {
	l << "{";

    size_t count = r.size() - 1;
	if (r.size() > 4) count = 4;
    for (size_t ii = 0; ii < count; ++ii) {
		l << r[ii] << ", ";
    }

    if (r.size() > 4) {
		l << "...";
	}
    else {
		l << r[r.size() - 1];
    }

    l << "}";
    return l;
}

void demo::DemoDataDumper::analyze(art::Event const& evt)
{
	std::vector<art::Handle<demo::DemoDataProduct>> productHandles;
	productHandles = evt.getMany<demo::DemoDataProduct>();

	size_t count = 0;
	for (const auto& handle : productHandles)
	{
		if (!handle.isValid() )
		{
			continue;
		}

		TLOG(TLVL_INFO) << "DemoDataProduct " << handle->instance_name << ", data: " << handle->data;
		count++;
	}

	TLOG(TLVL_INFO) << "Run " << evt.run() << ", subrun " << evt.subRun() << ", event " << evt.event() << " has "
	                 << count << " DemoDataProducts";
}

void demo::DemoDataDumper::endSubRun(art::SubRun const& sr)
{
	std::vector<art::Handle<std::vector<demo::DemoDataProduct>>> productHandles;
	productHandles = sr.getMany<std::vector<demo::DemoDataProduct>>();

	size_t count = 0;
	size_t countcount = 0;
	for (const auto& handle : productHandles)
	{
		if (!handle.isValid() || handle->empty())
		{
			continue;
		}

		TLOG(TLVL_INFO) << "DemoDataProduct vector size: " << handle->size();
		for (auto& prod : *handle)
		{
			TLOG(TLVL_INFO) << "    " << "DemoDataProduct " << prod.instance_name << ", data: " << prod.data;
			countcount++;
		}
		count++;
	}

	TLOG(TLVL_INFO) << "Run " << sr.run() << ", subrun " << sr.subRun() << " has "
	                 << count << " DemoDataProduct vectors, with a total of " << countcount << " DemoDataProduct instances";
}

void demo::DemoDataDumper::endRun(art::Run const& r)
{
	std::vector<art::Handle<std::vector<demo::DemoDataProduct>>> productHandles;
	productHandles = r.getMany<std::vector<demo::DemoDataProduct>>();

	size_t count = 0;
	size_t countcount = 0;
	for (const auto& handle : productHandles)
	{
		if (!handle.isValid() || handle->empty())
		{
			continue;
		}

		TLOG(TLVL_INFO) << "DemoDataProduct vector size: " << handle->size();
		for (auto& prod : *handle)
		{
			TLOG(TLVL_INFO) << "    " << "DemoDataProduct " << prod.instance_name << ", data: " << prod.data;
			countcount++;
		}
		count++;
	}

	TLOG(TLVL_INFO) << "Run " << r.run() << " has "
	                 << count << " DemoDataProduct vectors, with a total of " << countcount << " DemoDataProduct instances";
}

DEFINE_ART_MODULE(demo::DemoDataDumper)  // NOLINT(performance-unnecessary-value-param)

// Collect lumi stream information and write it out at lower frequency in subruns (and potentially
// events)

#include "art/Framework/Core/EDProducer.h"
#include "art/Framework/Principal/Event.h"
#include "art/Framework/Principal/Handle.h"
#include "art/Framework/Principal/Run.h"
#include "art/Framework/Principal/SubRun.h"
#include "art/Framework/Services/Registry/ServiceHandle.h"
#include "fhiclcpp/ParameterSet.h"
#include "fhiclcpp/types/Atom.h"
#include "fhiclcpp/types/OptionalAtom.h"

#include "artdaq-core-demo/Data/DemoDataProduct.hh"
#include "artdaq/DAQdata/Globals.hh"

#include <algorithm>
#include <iostream>
#include <string>

#include "trace.h"
#define TRACE_NAME "DemoDataProducer"

namespace demo {

class DemoDataProducer : public art::EDProducer
{
public:
	struct Config
	{
		fhicl::Atom<bool> produce_events{fhicl::Name("produce_events"), fhicl::Comment("Make DemoDataProducts per-event"), false};
		fhicl::Atom<bool> produce_subruns{fhicl::Name("produce_subruns"), fhicl::Comment("Make DemoDataProducts per-SubRun"), true};
		fhicl::Atom<bool> produce_runs{fhicl::Name("produce_runs"), fhicl::Comment("Make DemoDataProducts per-Run"), false};
		fhicl::Atom<int> data_array_size{fhicl::Name("data_array_size"), fhicl::Comment("Number of integers in each DemoDataProduct data array"), 2};
	};

	explicit DemoDataProducer(const art::EDProducer::Table<Config>& config);
	virtual void produce(art::Event& event) override;
	virtual void endSubRun(art::SubRun& sr) override;
	virtual void endRun(art::Run& r) override;

private:
	bool produces_events_;
	bool produces_subruns_;
	bool produces_runs_;
	size_t data_array_size_;
	std::unique_ptr<std::vector<DemoDataProduct>> subrun_demo_datas_{nullptr};
	std::unique_ptr<std::vector<DemoDataProduct>> run_demo_datas_{nullptr};
	std::string instance_name_;
};

DemoDataProducer::DemoDataProducer(const art::EDProducer::Table<Config>& config)
    : art::EDProducer{config}
    , produces_events_(config().produce_events())
    , produces_subruns_(config().produce_subruns())
    , produces_runs_(config().produce_runs())
    , data_array_size_(config().data_array_size())
    , instance_name_(app_name)
{
	TLOG(TLVL_INFO) << "DemoDataProducer CONSTRUCTOR BEGIN";
	std::replace(instance_name_.begin(), instance_name_.end(), '_', 'U');  // protect against forbidden branch name characters
	std::replace(instance_name_.begin(), instance_name_.end(), '-', 'D');

	if (produces_events_)
	{
		produces<demo::DemoDataProduct>();
	}
	if (produces_subruns_)
	{
		produces<std::vector<demo::DemoDataProduct>, art::InSubRun>(instance_name_);
	}
	if (produces_runs_)
	{
		produces<std::vector<demo::DemoDataProduct>, art::InRun>(instance_name_);
	}
	TLOG(TLVL_INFO) << "DemoDataProducer CONSTRUCTOR END";
}

void DemoDataProducer::endSubRun(art::SubRun& sr)
{
	if (produces_subruns_ && subrun_demo_datas_ != nullptr)
	{
		art::SubRunNumber_t subrunNumber = sr.subRun();
		art::RunNumber_t runNumber = sr.run();
		TLOG(TLVL_DEBUG + 35) << "DemoDataProducer::" << __func__ << ": Run:SubRun " << runNumber << ":" << subrunNumber << " app_name = " << app_name 
            << ": Writing out " << subrun_demo_datas_->size() << " DemoDataProducts";

        sr.put(std::move(subrun_demo_datas_), instance_name_, art::fullSubRun());

        subrun_demo_datas_.reset(nullptr);
	}
}

void DemoDataProducer::endRun(art::Run& r)
{
	if (produces_runs_ && run_demo_datas_ != nullptr)
	{
		art::RunNumber_t runNumber = r.run();
		TLOG(TLVL_DEBUG + 35) << "DemoDataProducer::" << __func__ << ": Run " << runNumber << " app_name = " << app_name
		                      << ": Writing out " << run_demo_datas_->size() << " DemoDataProducts";

		r.put(std::move(run_demo_datas_), instance_name_, art::fullRun());

		run_demo_datas_.reset(nullptr);
	}
}

void DemoDataProducer::produce(art::Event& event)
{
	// for printout use
	const art::EventNumber_t eventNumber = event.event();
	const art::SubRunNumber_t subrunNumber = event.subRun();
	const art::RunNumber_t runNumber = event.run();

    TLOG(TLVL_DEBUG + 36) << "Producing DemoDataProduct for Run:Subrun:Event " << runNumber << ":" << subrunNumber << ":" << eventNumber;

    std::vector<int> arr;
    for (size_t ii = 0; ii < data_array_size_; ++ii) {
		arr.push_back(eventNumber + ii);
    }
	auto prod_event = std::make_unique<DemoDataProduct>("event-" + std::to_string(eventNumber), arr);
	DemoDataProduct prod_subrun("event-" + std::to_string(eventNumber), arr);
	DemoDataProduct prod_run("event-" + std::to_string(eventNumber), arr);

    if (produces_events_) {
		event.put(std::move(prod_event));
    }
    if (produces_subruns_) {
		if (subrun_demo_datas_ == nullptr)
		{
			subrun_demo_datas_.reset(new std::vector<demo::DemoDataProduct>());
        }
		subrun_demo_datas_->push_back(prod_subrun);
    }
	if (produces_runs_)
	{
		if (run_demo_datas_ == nullptr)
		{
			run_demo_datas_.reset(new std::vector<demo::DemoDataProduct>());
		}
		run_demo_datas_->push_back(prod_run);
    }

}  // produce

}  // namespace demo

DEFINE_ART_MODULE(demo::DemoDataProducer)

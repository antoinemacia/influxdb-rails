require "spec_helper"

RSpec.describe InfluxDB::Rails::Middleware::RenderSubscriber do
  let(:config) { InfluxDB::Rails::Configuration.new }
  let(:logger) { double(:logger) }

  before do
    allow(config).to receive(:application_name).and_return("my-rails-app")
    allow(config).to receive(:ignored_environments).and_return([])
    allow(config).to receive(:time_precision).and_return("ms")
  end

  describe ".call" do
    let(:start_time)   { Time.at(1_517_567_368) }
    let(:finish_time)  { Time.at(1_517_567_370) }
    let(:series_name) { "series_name" }
    let(:payload) { { identifier: "index.html", count: 43, cache_hits: 42 } }
    let(:result) {
      {
        values:
        {
          value: 2000
        },
        tags:
        {
          filename: "index.html",
          count: 43,
          cache_hits: 42
        },
        timestamp: 1_517_567_370_000
      }
    }

    subject { described_class.new(config, series_name) }

    context 'successfully' do
      it "writes to InfluxDB" do
        expect_any_instance_of(InfluxDB::Client).to receive(:write_point).with(
          series_name, result
        )
        subject.call("name", start_time, finish_time, "id", payload)
      end

      context "with empty tags" do
        before do
          payload[:count] = nil
          result[:tags].delete(:count)
        end

        it "does not write empty tags" do
          expect_any_instance_of(InfluxDB::Client).to receive(:write_point).with(
            series_name, result
          )
          subject.call("name", start_time, finish_time, "id", payload)
        end
      end
    end

    context "unsuccessfully" do
      before do
        allow(config).to receive(:logger).and_return(logger)
        InfluxDB::Rails.configuration = config
      end

      it "does log exceptions" do
        allow_any_instance_of(InfluxDB::Client).to receive(:write_point).and_raise("boom")
        expect(logger).to receive(:error).with(/boom/)
        subject.call("name", start_time, finish_time, "id", payload)
      end
    end
  end
end
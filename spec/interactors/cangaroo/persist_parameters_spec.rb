require 'rails_helper'

class JobC < Cangaroo::BaseJob
  connection :job_c_connection
end
class JobD < Cangaroo::BaseJob; end
class JobE < Cangaroo::BaseJob
  connection :job_e_connection
end

describe Cangaroo::PersistParameters do
  let!(:connection) { create(:cangaroo_connection, name: JobC.connection.to_s) }
  let(:flow) { JobC.new(source_connection: nil, type: 'orders', payload: {}) }
  let(:parameters) { Hash.new }
  subject do
    described_class.new(
      flow: flow,
      parameters: parameters
    )
  end

  describe 'integration with other interactors' do
    let(:json_body) { JSON.parse(load_fixture('json_payload_parameters.json')) }
    before(:each) do
      job_d = double(:job_d, perform?: true, enqueue: true)
      allow(JobD).to receive(:new).and_return(job_d)
    end
    context 'connection with parameters' do
      before(:each) { expect(connection.parameters).to_not be_empty }
      it "persists the new parameters" do
        expect{
          Cangaroo::PerformFlow.call(
            flow: flow,
            json_body: json_body,
            jobs: [JobD],
            source_connection: connection
          )
        }.to change{
          connection.reload.parameters
        }.to(json_body["parameters"])
      end
    end
    context 'connection without parameters' do
      let!(:connection) { create(:store, name: JobC.connection.to_s) }
      before(:each) { expect(connection.parameters).to_not be_present }
      it "doesn't persist params for a connection without them" do
        expect{
          Cangaroo::PerformFlow.call(
            flow: flow,
            json_body: json_body,
            jobs: [JobD],
            source_connection: connection
          )
        }.to_not change{
          connection.reload.parameters
        }.from({})
      end

    end
  end

  describe '#call' do
    context "new parameters" do
      let(:parameters) { { connection.parameters.keys.first => "new value" } }
      it 'persists the new parameters' do
        old_params = connection.parameters
        new_params = connection.parameters.with_indifferent_access.merge(parameters)
        expect{
          subject.call
        }.to change{
          connection.reload.parameters
        }.from(old_params).to(new_params)
      end
      it 'fails if updates cannot be persisted' do
        allow_any_instance_of(Cangaroo::Connection).to receive(:update) { false }
        context = described_class.call(flow: flow, parameters: parameters)
        expect(context).to_not be_success
        expect(context).to be_failure
      end
    end
    context 'different request parameters' do
      let(:parameters) { { "different" => "param" } }
      it 'does not update the DB' do
        expect(connection.parameters.keys).to_not include(parameters.keys.first)
        expect{ subject.call }.to_not change{ connection.reload.parameters.with_indifferent_access }
      end
    end
    it 'does not update the DB if there are no request params' do
      expect(parameters).to be_empty
      expect{ subject.call }.to_not change{ connection.reload.parameters }
    end
  end

  describe '#connection' do
    it "is the flow's connection" do
      expect(subject.send(:connection)).to eq connection
    end
  end

  describe '#request_params' do
    context 'nil params' do
      let(:parameters) { nil }
      it "does not throw an error" do
        expect(subject.send(:request_params)).to eq({})
      end
    end
    it "handles empty params" do
      expect(parameters).to be_empty
      expect(subject.send(:request_params)).to eq({})
    end
    context "empty param values" do
      let(:parameters) { {"a" => nil, "b" => 3, "c" => ""} }
      it "removes them" do
        expect(subject.send(:request_params)).to eq({"b" => 3})
      end
    end
  end

  describe "#new_params" do
    let(:new_params) { subject.send(:new_params) }
    context "empty request params" do
      before(:each) { expect(parameters).to be_empty }
      it "returns the persisted params" do
        persisted_params = connection.parameters
        persisted_params.each do |key, value|
          expect(new_params.fetch(key)).to eq(persisted_params.fetch(key))
        end
      end
    end
    context "extra request params" do
      let(:parameters) { connection.parameters.merge("a" => 1) }
      it "removes them" do
        expect(new_params).to_not have_key("a")
      end
    end
    context "missing request params" do
      let(:param_key)  { connection.parameters.keys.first }
      let(:parameters) { { param_key => "new value" } }
      it "ignores them" do
        old_params = connection.parameters
        missing_keys = old_params.keys - [param_key]
        missing_keys.each do |missing_key|
          expect(new_params[missing_key]).to eq(old_params[missing_key])
        end
      end
      it "sets the present key" do
        expect(new_params[param_key]).to eq(parameters[param_key])
      end
    end
    context "symbol request params" do
      let(:param_key)  { connection.parameters.keys.first }
      let(:parameters) { { param_key.to_sym => "new value" } }
      before(:each) do
        connection.update(parameters: connection.parameters.stringify_keys)
      end
      it "still matches them with their string counterparts" do
        expect(new_params[param_key]).to eq(parameters[param_key.to_sym])
      end
    end
  end
end

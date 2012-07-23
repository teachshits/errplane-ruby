require 'spec_helper'

describe Errplane do
  before do
    FakeWeb.last_request = nil
    FakeWeb.clean_registry

    @request_path = "/api/v1/applications/#{Errplane.configuration.application_id}/exceptions/test?api_key=f123-e456-d789c012"
    @request_url = "http://api.errplane.com#{@request_path}"
  end

  describe ".ignorable_exception?" do
    it "should be true for exception types specified in the configuration" do
      class DummyException < Exception; end
      exception = DummyException.new

      Errplane.configure do |config|
        config.ignored_exceptions << 'DummyException'
      end

      Errplane.ignorable_exception?(exception).should be_true
    end

    it "should be true for exception types specified in the configuration" do
      exception = ActionController::RoutingError.new("foo")
      Errplane.ignorable_exception?(exception).should be_true
    end

    it "should be false for valid exceptions" do
      exception = ZeroDivisionError.new
      Errplane.ignorable_exception?(exception).should be_false
    end
  end

  describe 'rescue' do
    it "should transmit an exception when passed" do
      Errplane.configure { |config| config.ignored_environments = [] }

      FakeWeb.register_uri(:post, @request_url, :body => "", :status => ["200", "OK"])

      Errplane.rescue do
        raise ArgumentError.new('wrong')
      end

      FakeWeb.last_request.should_not be_nil
      FakeWeb.last_request.method.should == "POST"
      FakeWeb.last_request.path.should == @request_path
    end

    it "should also raise the exception when in an ignored environment" do
      Errplane.configure { |config| config.ignored_environments = %w{development test} }

      expect {
        Errplane.rescue do
          raise ArgumentError.new('wrong')
        end
      }.to raise_error(ArgumentError)
    end
  end

  describe "rescue_and_reraise" do
    before do
      Errplane.configure { |config| config.ignored_environments = [] }
    end

    it "should transmit an exception when passed" do
      FakeWeb.register_uri(:post, @request_url, :body => "", :status => ["200", "OK"])

      expect {
        Errplane.rescue_and_reraise { raise ArgumentError.new('wrong') }
      }.to raise_error(ArgumentError)

      FakeWeb.last_request.should_not be_nil
      FakeWeb.last_request.method.should == "POST"
      FakeWeb.last_request.path.should == @request_path
    end
  end
end

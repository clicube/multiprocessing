require 'minitest/spec'
require 'minitest/autorun'
require_relative '../process'

describe MultiProcessing::Process do

  it "can be created with block" do
    MultiProcessing::Process.new{:nop}.must_be_instance_of MultiProcessing::Process
  end

  it "cannot be created without block" do
    proc{ MultiProcessing::Process.new }.must_raise MultiProcessing::ProcessError
  end

  it "returns pid" do
    MultiProcessing::Process.new{ :nop }.pid.must_be_kind_of Fixnum
  end

  it "joins process" do
    p = MultiProcessing::Process.new { :nop }
    p.join.must_be :!=, nil
  end

  it "joins process with timeout" do
    p = MultiProcessing::Process.new { :nop }
    p.join(1).must_be :!=, nil
    p = MultiProcessing::Process.new { sleep 1 }
    p.join(0).must_be_nil
  end

  it "returns value" do
    p = MultiProcessing::Process.new { :nop }
    p.value.must_be_instance_of ::Process::Status
    p = MultiProcessing::Process.new { :nop }
    p.value.success?.must_be :==, true
    p = MultiProcessing::Process.new { exit 1 }
    p.value.success?.must_be :==, false
  end

  it "returns nil when process does not exist" do
    p = MultiProcessing::Process.new { :nop }
    p.join
    p.value.must_be_nil
  end

  it "can be kill" do
    p = MultiProcessing::Process.new { sleep 1 }
    p.kill :TERM
    p.join(0).must_be_nil
  end

end

